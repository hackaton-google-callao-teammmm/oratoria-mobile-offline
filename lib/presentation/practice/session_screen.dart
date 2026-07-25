import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:oratoria_core/oratoria_core.dart';
import 'package:record/record.dart';

import '../../app/config/feature_flags.dart';
import '../../adapters/audio/pause_detector.dart';
import '../../adapters/body/mlkit_body_analyzer.dart';
import '../../adapters/coach/audience_question.dart';
import '../../adapters/coach/gemma_coach.dart';
import '../../adapters/coach/gemma_service.dart';
import '../../adapters/speech/mock_transcriber.dart';
import '../../adapters/speech/sherpa_transcriber.dart';
import '../../adapters/speech/transcript_hygiene.dart';
import '../../adapters/speech/vosk_live_transcriber.dart';
import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/brand/eq_waveform.dart';
import '../../shared/characters/la_banca.dart';
import '../../shared/characters/vox.dart';
import '../../shared/ui/eyebrow.dart';
import '../../shared/ui/pill_button.dart';
import '../report/report_screen.dart';
import 'widgets/live_caption.dart';

/// The practice session — the heart of the flow (§Flujo 2 of the user flow):
/// countdown → EXPONIENDO (the audience reacts to the child's real voice) →
/// Vox thinks → report.
///
/// What is REAL here: the microphone, the live amplitude driving La Banca, the
/// speaking duration, the countdown, Vox's "thinking" beat, and the report via
/// the deterministic coach. What is still a placeholder: the transcript
/// (mocked until sherpa-onnx STT lands), so filler/WPM come from the sample
/// text for now — the LIVE audience reaction is genuine.
class SessionScreen extends StatefulWidget {
  final Exercise exercise;
  final Profile profile;
  final LocalStore store;

  const SessionScreen({
    super.key,
    required this.exercise,
    required this.profile,
    required this.store,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

enum _Phase { countdown, speaking, thinking, question }

class _SessionScreenState extends State<SessionScreen> {
  final _recorder = AudioRecorder();

  _Phase _phase = _Phase.countdown;
  int _count = 3;
  double _energy = 0; // 0..1, drives La Banca
  Duration _elapsed = Duration.zero;

  Timer? _countTimer;
  Timer? _clock;
  StreamSubscription<Uint8List>? _pcmSub;
  final BytesBuilder _pcm = BytesBuilder(copy: false); // raw PCM16 for the STT
  DateTime? _startedAt;

  // Optional second modality — front-camera body language. Best-effort: if it
  // never initialises, the session is exactly the same, audio-only.
  MlKitBodyLanguageAnalyzer? _body;
  bool _bodyOn = false;

  // Produced during the "thinking" beat, shown in the "question" phase.
  PracticeResult? _result;
  AskedQuestion? _question;

  // Live caption (behind FeatureFlags.liveCaption). Cosmetic: never feeds the
  // report, which stays on the final Whisper pass.
  String _caption = '';
  StreamSubscription<String>? _captionSub;

  @override
  void initState() {
    super.initState();
    // Start the camera during the countdown so its one-time face-model load
    // (~1-2 s of frame skips) happens behind the 3·2·1, not when the child
    // starts speaking. Best-effort — audio-only if it fails.
    final body = MlKitBodyLanguageAnalyzer();
    body.start().then((ok) {
      if (!mounted) return;
      if (ok) {
        setState(() {
          _body = body;
          _bodyOn = true;
        });
      }
    });
    _runCountdown();
  }

  @override
  void dispose() {
    _countTimer?.cancel();
    _clock?.cancel();
    _pcmSub?.cancel();
    _captionSub?.cancel();
    if (FeatureFlags.liveCaption) VoskLiveTranscriber.instance.stop();
    _recorder.dispose();
    _body?.stop();
    super.dispose();
  }

  void _runCountdown() {
    _countTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_count <= 1) {
        timer.cancel();
        _startSpeaking();
      } else {
        setState(() => _count--);
      }
    });
  }

  Future<void> _startSpeaking() async {
    // Stream raw PCM16 at 16 kHz mono — the same audio drives La Banca (via
    // RMS) AND feeds the on-device STT at the end. Recording to a stream, not
    // a file: nothing is ever written to disk (privacy).
    try {
      if (await _recorder.hasPermission()) {
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );
        _pcmSub = stream.listen(_onPcmChunk);

        // Live caption: start the streaming Vosk recognizer and mirror its
        // partial words. Best-effort — if the model isn't sideloaded it stays
        // dark and nothing changes. It never feeds the report.
        if (FeatureFlags.liveCaption) {
          _captionSub = VoskLiveTranscriber.instance.partials.listen((partial) {
            if (mounted) setState(() => _caption = partial);
          });
          await VoskLiveTranscriber.instance.start(sampleRate: 16000);
        }
      }
    } catch (_) {
      // No mic / denied: the session still runs (golden rule). La Banca stays
      // calm and the report uses the sample transcript.
    }

    _startedAt = DateTime.now();
    _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
    setState(() => _phase = _Phase.speaking);
  }

  void _onPcmChunk(Uint8List bytes) {
    _pcm.add(bytes); // keep for the STT at the end
    // Feed the live caption recognizer (no-op when the flag is off or the model
    // isn't loaded). The full buffer above is what the report's Whisper uses.
    if (FeatureFlags.liveCaption) VoskLiveTranscriber.instance.feed(bytes);
    // Live RMS → La Banca energy. Read PCM16 (little-endian) by byte pairs —
    // asInt16List can't be used because stream chunks may start at an odd
    // offset (RangeError: offset must be a multiple of 2).
    final n = bytes.lengthInBytes ~/ 2;
    if (n == 0) return;
    var sumSq = 0.0;
    for (var i = 0; i + 1 < bytes.lengthInBytes; i += 2) {
      var v = (bytes[i + 1] << 8) | bytes[i];
      if (v >= 0x8000) v -= 0x10000; // to signed
      final f = v / 32768.0;
      sumSq += f * f;
    }
    final rms = math.sqrt(sumSq / n);
    // Map RMS (~0..0.3 for speech) to 0..1 with a little headroom.
    final norm = (rms * 3.2).clamp(0.0, 1.0);
    if (mounted) setState(() => _energy = norm);
  }

  /// Real on-device transcription of the captured audio. Falls back to the
  /// sample transcript when the STT model isn't installed or fails, so the
  /// report always has something to analyse (golden rule).
  ///
  /// [trusted] is true only when the words came from the real STT — the report
  /// then judges pace and fillers; otherwise those metrics are hidden rather
  /// than derived from placeholder text.
  Future<({String text, bool trusted})> _transcribe(Uint8List bytes) async {
    if (bytes.lengthInBytes >= 2) {
      final int16 = bytes.buffer.asInt16List(0, bytes.lengthInBytes ~/ 2);
      final samples = Float32List(int16.length);
      for (var i = 0; i < int16.length; i++) {
        samples[i] = int16[i] / 32768.0;
      }
      final text = await SherpaTranscriber.instance.transcribe(samples);
      if (text != null) {
        // Whisper hallucinates non-speech tags and stock phrases over silence;
        // scrub them so a "[Música]" never becomes a fabricated "Ritmo".
        final clean = cleanTranscript(text);
        if (clean.isNotEmpty) return (text: clean, trusted: true);
      }
    }
    // No STT / empty / hallucinated result → keep the demo alive with the
    // sample text, but flag it untrusted so no word-derived metric is presented
    // as real.
    return (text: await MockTranscriber().stop(), trusted: false);
  }

  Future<void> _finish() async {
    _clock?.cancel();
    await _pcmSub?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}

    // Free the live-caption recognizer BEFORE the report's Whisper pass, so two
    // ASR models are never resident at once on the A12.
    if (FeatureFlags.liveCaption) {
      await _captionSub?.cancel();
      await VoskLiveTranscriber.instance.stop();
    }

    // Stop the camera and collect the body aggregate (BodyMetrics.none if it
    // never ran or saw no face — the report then simply omits body language).
    final body = _body == null ? BodyMetrics.none : await _body!.stop();
    _body = null;

    setState(() => _phase = _Phase.thinking);

    // Vox "thinks" — this beat masks the on-device work. Everything here is
    // guarded so the session never breaks, and only honestly measured signals
    // reach the report: the STT transcribes what the child actually said, a
    // cheap energy VAD finds the real long pauses, the deterministic report is
    // computed, and Gemma writes the audience's follow-up question (the wow).
    final pcm = _pcm.toBytes();
    final transcript = await _transcribe(pcm);
    // O(n) pause scan, before Gemma so it never competes for RAM/time.
    final pauseScan = const PauseDetector().detect(pcm);
    // The rule-based coach always owns the verdict. When the flag is on, Gemma
    // rephrases the two prose bodies (never the decision), falling back to the
    // exact rule-based text on any failure/timeout.
    final evaluate = EvaluatePractice(
      coach: FeatureFlags.gemmaFeedback
          ? GemmaCoach.gemma()
          : const RuleBasedCoach(),
    );
    final result = await evaluate(
      transcript: transcript.text,
      speakingDuration: _elapsed.inSeconds < 3
          ? const Duration(seconds: 12) // too short to analyse → sample length
          : _elapsed,
      pauses: pauseScan.pauses,
      body: body,
      exercise: widget.exercise,
      transcriptTrusted: transcript.trusted,
      pausesTrusted: pauseScan.trusted,
      // Whisper only transcribes the first 30 s, so cap the rate denominator to
      // that window when the words came from it. Null for the sample fallback,
      // whose word metrics are hidden anyway.
      transcriptionWindow:
          transcript.trusted ? SherpaTranscriber.maxAudioWindow : null,
    );

    // Persist the result for "Mi progreso" (fire-and-forget; never blocks the
    // beat). Timestamp comes from timestamp() since Date.now is unavailable.
    await widget.store.saveResult(
      widget.profile.id,
      SavedResult(
        exerciseId: widget.exercise.id,
        score: result.score,
        stars: result.stars,
        atMillis: DateTime.timestamp().millisecondsSinceEpoch,
      ),
    );

    final question = await AudienceQuestion(gemma: GemmaService.instance)
        .forExercise(widget.exercise);

    if (!mounted) return;
    setState(() {
      _result = result;
      _question = question;
      _phase = _Phase.question;
    });
  }

  void _goToReport() {
    final result = _result;
    if (result == null) return;
    // Capture the NavigatorState BEFORE the replace: the session's own context
    // is defunct once the report takes its place, so the new "start next reto"
    // callback must not rely on it. (onPracticeAgain is left EXACTLY as-is — it
    // works in the frozen build and is not refactored the night before.)
    final nav = Navigator.of(context);
    nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReportScreen(
          result: result,
          onPracticeAgain: () => Navigator.of(context).pop(),
          onStartExercise: (exercise) => nav.pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => SessionScreen(
                exercise: exercise,
                profile: widget.profile,
                store: widget.store,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: switch (_phase) {
          _Phase.countdown => _Countdown(count: _count, exercise: widget.exercise),
          _Phase.speaking => _Speaking(
              energy: _energy,
              elapsed: _elapsed,
              target: widget.exercise.targetDuration,
              onFinish: _finish,
              tokens: t,
              camera: _bodyOn ? _body?.controller : null,
              caption: _caption,
            ),
          _Phase.thinking => _Thinking(tokens: t),
          _Phase.question => _AudienceAsks(
              question: _question!,
              onContinue: _goToReport,
            ),
        },
      ),
    );
  }
}

/// Step 7 — a member of La Banca asks a follow-up question, written on-device
/// by Gemma (or the topic bank if Gemma was slow/unavailable). This is the
/// wow: an AI that listened and wants to hear more, with no internet.
/// The audience question beat — the wow. Shows Gemma's follow-up in the mouth
/// of La Banca. There is intentionally NO "reply" action: replying isn't built
/// yet, so a button promising it would be a dishonest micro-flow. The presenter
/// answers the room out loud to show the loop; the app just poses the question.
/// A single "Continuar" keeps the moment in the speaker's hands, with a
/// generous auto-advance as a safety net so it never dead-ends.
class _AudienceAsks extends StatefulWidget {
  final AskedQuestion question;
  final VoidCallback onContinue;

  const _AudienceAsks({required this.question, required this.onContinue});

  @override
  State<_AudienceAsks> createState() => _AudienceAsksState();
}

class _AudienceAsksState extends State<_AudienceAsks> {
  Timer? _autoAdvance;

  @override
  void initState() {
    super.initState();
    // Safety net only — generous so the presenter controls the pace.
    _autoAdvance = Timer(const Duration(seconds: 9), _go);
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    super.dispose();
  }

  void _go() {
    _autoAdvance?.cancel();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 24),
        // The excited audience — they're engaged and curious now.
        const LaBanca(energy: 0.9, height: 150),
        const SizedBox(height: 24),
        Text('Tu público quiere saber más', style: text.titleMedium),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            widget.question.text,
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(fontSize: 30),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: PillButton(
            label: 'Continuar',
            icon: Icons.arrow_forward_rounded,
            onPressed: _go,
          ),
        ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  final int count;
  final Exercise exercise;

  const _Countdown({required this.count, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Vox(mood: VoxMood.greeting, size: 88),
          const SizedBox(height: 16),
          Text(exercise.title, style: text.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              exercise.prompt,
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ),
          const SizedBox(height: 40),
          TweenAnimationBuilder<double>(
            key: ValueKey(count),
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, s, _) => Transform.scale(
              scale: s,
              child: Text(
                '$count',
                style: text.displaySmall?.copyWith(fontSize: 96),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Speaking extends StatelessWidget {
  final double energy;
  final Duration elapsed;
  final Duration target;
  final VoidCallback onFinish;
  final AppTokens tokens;
  final CameraController? camera;

  /// Live partial transcript (empty when the feature is off or silent).
  final String caption;

  const _Speaking({
    required this.energy,
    required this.elapsed,
    required this.target,
    required this.onFinish,
    required this.tokens,
    this.camera,
    this.caption = '',
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final secs = elapsed.inSeconds;
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        const SizedBox(height: 16),
        // Small self-preview when the camera is on — the child sees themselves
        // present, but there is no corrective overlay (the audience is the live
        // feedback). Mirrored like a selfie.
        if (camera != null && camera!.value.isInitialized)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: SizedBox(
              width: 120,
              height: 160,
              child: Transform.flip(
                flipX: true,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: camera!.value.previewSize?.height ?? 120,
                    height: camera!.value.previewSize?.width ?? 160,
                    child: CameraPreview(camera!),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        // Timer — the only "HUD". Tabular mono so its width doesn't jitter each
        // tick. No corrective text while speaking: the audience IS the live
        // feedback.
        Text('$mm:$ss', style: monoFigure(color: tokens.ink, size: 40)),
        const SizedBox(height: 12),
        // Live voice waveform — the brand eq-motif, driven by the child's mic.
        EqWaveform(energy: energy, height: 40, barWidth: 7, color: tokens.accent),
        const Spacer(),
        // The audience reacting to the child's real voice — the wow.
        LaBanca(energy: energy, height: 150),
        const SizedBox(height: 8),
        Text('Tu público te escucha', style: text.bodyMedium),
        const Spacer(),
        // Live caption (behind the liveCaption flag) — a subtle mirror of the
        // child's words. Empty string collapses to nothing, so this is inert
        // when the feature is off.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LiveCaption(text: caption),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: PillButton(
            label: '¡Terminé!',
            icon: Icons.check_rounded,
            onPressed: onFinish,
          ),
        ),
      ],
    );
  }
}

class _Thinking extends StatelessWidget {
  final AppTokens tokens;

  const _Thinking({required this.tokens});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Vox(mood: VoxMood.thinking, size: 96),
          const SizedBox(height: 28),
          Text('Vox está pensando…', style: text.titleMedium),
          const SizedBox(height: 20),
          // The brand eq-motif doubles as the loading pulse.
          EqWaveform(height: 28, barWidth: 5, color: tokens.accent),
        ],
      ),
    );
  }
}

