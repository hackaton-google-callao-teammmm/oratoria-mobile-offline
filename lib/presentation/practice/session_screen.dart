import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../shared/characters/audience_mood.dart';
import '../../shared/characters/la_banca.dart';
import '../../shared/characters/vox.dart';
import '../../shared/ui/eyebrow.dart';
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

enum _Phase { countdown, speaking, thinking }

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

  String? _aiProfile;
  String? _dynamicChallengePrompt;
  bool _isLoadingChallenge = true;

  @override
  void initState() {
    super.initState();
    _aiProfile = widget.store.getAiProfile(widget.profile.id);

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
    _loadInitialChallenge();
  }

  Future<void> _loadInitialChallenge() async {
    final coach = FeatureFlags.gemmaFeedback
        ? GemmaCoach.gemma()
        : const RuleBasedCoach();
    final prompt = await coach.generateInitialChallenge(_aiProfile);
    if (!mounted) return;
    setState(() {
      _dynamicChallengePrompt = prompt;
      _isLoadingChallenge = false;
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
      // Trim only the leading/trailing silence before Whisper — that empty edge
      // is exactly what it hallucinates speech over. Anti-empty guard inside:
      // a near-silent clip is returned unchanged. The pause VAD and the WPM
      // denominator still use the ORIGINAL buffer; this touches only the STT.
      final speech = const PauseDetector().trimSilenceEdges(bytes);
      final int16 = speech.buffer.asInt16List(0, speech.lengthInBytes ~/ 2);
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
      aiProfile: _aiProfile,
    );

    if (result.updatedAiProfile != null) {
      await widget.store.saveAiProfile(
        widget.profile.id,
        result.updatedAiProfile!,
      );
    }

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
    _result = result;
    _question = question;
    // No blocking "audience asks" screen: it gated the payoff behind an extra
    // tap. The audience's follow-up (the Agentes beat) now rides ON the report
    // as a card, so the child lands straight on their results.
    _goToReport();
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
          audienceQuestion: _question?.text,
          profile: widget.profile,
          store: widget.store,
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

  // Toggles ONLY the self-view preview. The ML Kit body analyzer keeps running
  // (100% offline), so body metrics are still collected at _finish.
  void _toggleSelfView() => setState(() => _bodyOn = !_bodyOn);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: switch (_phase) {
          _Phase.countdown => _isLoadingChallenge
              ? _LoadingChallenge(tokens: t)
              : _Countdown(
                  count: _count,
                  exercise: widget.exercise,
                  promptText: _dynamicChallengePrompt ?? widget.exercise.prompt,
                ),
          _Phase.speaking => _Speaking(
              energy: _energy,
              elapsed: _elapsed,
              target: widget.exercise.targetDuration,
              onFinish: _finish,
              tokens: t,
              camera: _bodyOn ? _body?.controller : null,
              caption: _caption,
              title: widget.exercise.title,
              prompt: widget.exercise.prompt,
              profileName: widget.profile.name,
              avatarEmoji: widget.profile.avatarKey,
              onToggleCamera: _body?.controller != null ? _toggleSelfView : null,
            ),
          _Phase.thinking => _Thinking(tokens: t),
        },
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final int count;
  final Exercise exercise;
  final String promptText;

  const _Countdown({
    required this.count,
    required this.exercise,
    required this.promptText,
  });

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
              promptText,
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

/// The sole off-palette color in the app: the universal "end / hang-up"
/// affordance the video-call layout demands. AppTokens has no red by design
/// (improve is amber, "never red"), so it lives here and is used only for the
/// finish button.
const Color _kEndRed = Color(0xFFE5484D);

/// EXPONIENDO — the speaking phase, framed as an on-device "video call":
/// the child is the main tile, La Banca is the reacting audience, and Vox is
/// the live "tracker". Every bit of motion is driven by the REAL mic [energy];
/// nothing here is faked. A12-safe: solid / pre-baked translucent surfaces
/// only, no live BackdropFilter.
class _Speaking extends StatelessWidget {
  final double energy;
  final Duration elapsed;
  final Duration target;
  final VoidCallback onFinish;
  final AppTokens tokens;
  final CameraController? camera;

  /// Live partial transcript (empty when the feature is off or silent).
  final String caption;

  /// Header identity — the exercise being practised.
  final String title;
  final String prompt;

  /// Name-pill identity for the child's own tile.
  final String profileName;
  final String avatarEmoji;

  /// Shows / hides the child's own self-view. Null when no camera is available,
  /// in which case the control renders dimmed and inert (honest: it would do
  /// nothing). The ML Kit analyzer keeps running either way — this only toggles
  /// the on-screen preview.
  final VoidCallback? onToggleCamera;

  const _Speaking({
    required this.energy,
    required this.elapsed,
    required this.target,
    required this.onFinish,
    required this.tokens,
    required this.title,
    required this.prompt,
    required this.profileName,
    this.camera,
    this.caption = '',
    this.avatarEmoji = '',
    this.onToggleCamera,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = tokens;
    final cameraOn = camera != null && camera!.value.isInitialized;
    final secs = elapsed.inSeconds;
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');

    return Stack(
      children: [
        // ---- CONTENT (full-bleed; the camera tile flexes to absorb slack) ----
        Positioned.fill(
          child: Column(
            children: [
              // (1) HEADER — exercise title + prompt, with an honest "En vivo"
              // recording pill in place of the reference's "+".
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge?.copyWith(
                              color: t.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prompt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(color: t.inkFaint),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _LivePill(tokens: t),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // (2) MAIN TILE — the child's own camera, or an honest placeholder.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _CameraTile(
                    camera: camera,
                    cameraOn: cameraOn,
                    tokens: t,
                    profileName: profileName,
                    avatarEmoji: avatarEmoji,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // (3) AUDIENCE — La Banca as three reacting tiles.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AudienceRow(energy: energy, tokens: t),
              ),
              const SizedBox(height: 10),
              Center(child: Eyebrow('Tu público te escucha', color: t.inkFaint)),
              const SizedBox(height: 12),
              // (4) VOX "TRACKER" — status + timer + waveform + live caption.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TrackerCard(
                  energy: energy,
                  mm: mm,
                  ss: ss,
                  caption: caption,
                  tokens: t,
                ),
              ),
              // Clears the floating control bar below.
              const SizedBox(height: 96),
            ],
          ),
        ),
        // ---- (5) FLOATING CONTROL BAR — camera, mic level, red finish ----
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: _ControlBar(
              cameraOn: cameraOn,
              energy: energy,
              onToggleCamera: onToggleCamera,
              onFinish: onFinish,
            ),
          ),
        ),
      ],
    );
  }
}

/// Honest "live recording" indicator that fills the reference's top-right "+"
/// slot — the session IS live, so there is nothing to fake.
class _LivePill extends StatelessWidget {
  final AppTokens tokens;

  const _LivePill({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record_rounded, size: 8, color: tokens.accent),
          const SizedBox(width: 6),
          Eyebrow('En vivo', color: tokens.inkSoft),
        ],
      ),
    );
  }
}

/// The big "main speaker" tile: the child's own mirrored front camera, or an
/// honest branded placeholder when the camera is off. A translucent name pill
/// sits top-left, mirroring the reference.
class _CameraTile extends StatelessWidget {
  final CameraController? camera;
  final bool cameraOn;
  final AppTokens tokens;
  final String profileName;
  final String avatarEmoji;

  const _CameraTile({
    required this.camera,
    required this.cameraOn,
    required this.tokens,
    required this.profileName,
    required this.avatarEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cameraOn)
            // Mirrored self-preview — the child sees themselves present. No
            // corrective overlay: the audience is the live feedback.
            Transform.flip(
              flipX: true,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: camera!.value.previewSize?.height ?? 720,
                  height: camera!.value.previewSize?.width ?? 1280,
                  child: CameraPreview(camera!),
                ),
              ),
            )
          else
            // Honest branded placeholder when the camera is off — never a fake
            // feed.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Vox(mood: VoxMood.idle, size: 72),
                  const SizedBox(height: 12),
                  Text(
                    'Cámara apagada',
                    style: text.bodyMedium?.copyWith(color: tokens.inkSoft),
                  ),
                ],
              ),
            ),
          Positioned(
            top: 10,
            left: 10,
            child: _NamePill(name: profileName, emoji: avatarEmoji),
          ),
        ],
      ),
    );
  }
}

/// Translucent name pill for a video tile. Uses fixed dark chrome (the const
/// [AppTokens.dark] palette) so it stays legible over unpredictable live video
/// in BOTH themes — a pre-baked translucent surface, A12-safe (no blur).
class _NamePill extends StatelessWidget {
  final String name;
  final String emoji;

  const _NamePill({required this.name, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      constraints: const BoxConstraints(maxWidth: 180),
      decoration: BoxDecoration(
        color: AppTokens.dark.surface.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppTokens.dark.lineStrong.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTokens.dark.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference's "row of 3 participant tiles" — La Banca as three audience
/// faces, each reacting to the one real mic [energy].
class _AudienceRow extends StatelessWidget {
  final double energy;
  final AppTokens tokens;

  const _AudienceRow({required this.energy, required this.tokens});

  @override
  Widget build(BuildContext context) {
    // Three distinct dispositions, warm on the LEFT so a timid child wins one
    // clearly-engaged face early. Same live energy, different reactions.
    return SizedBox(
      height: 84,
      child: Row(
        children: [
          Expanded(
            child: _AudienceTile(
              energy: energy,
              tokens: tokens,
              personality: AudiencePersonality.warm,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AudienceTile(
              energy: energy,
              tokens: tokens,
              personality: AudiencePersonality.neutral,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AudienceTile(
              energy: energy,
              tokens: tokens,
              personality: AudiencePersonality.tough,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single audience "participant" tile: one La Banca face + a mic glyph that
/// brightens with the live mic level. No fake human name — La Banca stays a
/// stylized, unnamed audience.
class _AudienceTile extends StatelessWidget {
  final double energy;
  final AppTokens tokens;
  final AudiencePersonality personality;

  const _AudienceTile({
    required this.energy,
    required this.tokens,
    required this.personality,
  });

  @override
  Widget build(BuildContext context) {
    final live = energy > 0.15;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: tokens.line),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: LaBanca(
              energy: energy,
              faceCount: 1,
              height: 84,
              personality: personality,
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTokens.dark.surface.withValues(alpha: 0.62),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                size: 12,
                color: live ? tokens.accent : AppTokens.dark.inkFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "AI Tracker Notes" card, rebranded as our coach Vox: avatar + live
/// status, the big monospace timer, the brand EqWaveform driven by [energy],
/// and (behind the flag) the peeking live caption.
class _TrackerCard extends StatelessWidget {
  final double energy;
  final String mm;
  final String ss;
  final String caption;
  final AppTokens tokens;

  const _TrackerCard({
    required this.energy,
    required this.mm,
    required this.ss,
    required this.caption,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasCaption = caption.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.28 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Vox(mood: VoxMood.speaking, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vox',
                      style: text.titleSmall?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Escuchando…',
                      style: text.bodySmall?.copyWith(color: tokens.inkSoft),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.fiber_manual_record_rounded,
                size: 16,
                color: tokens.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('$mm:$ss', style: monoFigure(color: tokens.ink, size: 40)),
          ),
          const SizedBox(height: 12),
          Center(
            child: EqWaveform(
              energy: energy,
              height: 40,
              barWidth: 7,
              color: tokens.accent,
            ),
          ),
          if (hasCaption) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: LiveCaption(text: caption),
            ),
          ],
        ],
      ),
    );
  }
}

/// The floating dark control pill. Only honest controls: a camera / self-view
/// toggle, a mic LEVEL indicator (never a mute — that would kill the session
/// audio), and the prominent red finish button. Uses fixed dark chrome (const
/// [AppTokens.dark]) so it reads like the reference in both themes. A12-safe:
/// translucent solids + a static shadow, no BackdropFilter.
class _ControlBar extends StatelessWidget {
  final bool cameraOn;
  final double energy;
  final VoidCallback? onToggleCamera;
  final VoidCallback onFinish;

  const _ControlBar({
    required this.cameraOn,
    required this.energy,
    required this.onToggleCamera,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final micLive = energy > 0.12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.dark.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppTokens.dark.lineStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleControl(
            icon: cameraOn
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            active: cameraOn,
            onTap: onToggleCamera == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onToggleCamera!();
                  },
          ),
          const SizedBox(width: 12),
          // Mic LEVEL indicator (non-interactive): brightens with the real
          // amplitude. Honest — there is no mute.
          _CircleControl(
            icon: Icons.mic_rounded,
            active: micLive,
            onTap: null,
          ),
          const SizedBox(width: 12),
          _EndButton(onFinish: onFinish),
        ],
      ),
    );
  }
}

/// A 52px round control on the floating bar. Interactive when [onTap] is set,
/// otherwise a pure status glyph (dimmed when neither active nor tappable).
class _CircleControl extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _CircleControl({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = active
        ? AppTokens.dark.accent
        : (onTap == null ? AppTokens.dark.inkFaint : AppTokens.dark.ink);
    final circle = Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? AppTokens.dark.accent.withValues(alpha: 0.20)
            : AppTokens.dark.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.dark.lineStrong),
      ),
      child: Icon(icon, size: 22, color: iconColor),
    );
    if (onTap == null) return circle;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: circle,
    );
  }
}

/// The prominent RED finish button — the reference's hang-up. Press-scale +
/// medium haptic, calls [onFinish] (the existing `_finish`, untouched).
class _EndButton extends StatefulWidget {
  final VoidCallback onFinish;

  const _EndButton({required this.onFinish});

  @override
  State<_EndButton> createState() => _EndButtonState();
}

class _EndButtonState extends State<_EndButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Terminar',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onFinish();
        },
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 110),
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kEndRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kEndRed.withValues(alpha: 0.5),
                  blurRadius: 22,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
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

class _LoadingChallenge extends StatelessWidget {
  final AppTokens tokens;

  const _LoadingChallenge({required this.tokens});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Vox(mood: VoxMood.thinking, size: 96),
          const SizedBox(height: 28),
          Text('Preparando tu reto personalizado…', style: text.titleMedium),
          const SizedBox(height: 20),
          EqWaveform(height: 28, barWidth: 5, color: tokens.accent),
        ],
      ),
    );
  }
}

