import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vosk_flutter_2/vosk_flutter_2.dart';

/// Streaming, word-level Spanish STT for the LIVE caption only — Vosk runs
/// during EXPONIENDO and emits partial words as the child speaks.
///
/// It is deliberately separate from [SherpaTranscriber]: Whisper stays the
/// engine for the FINAL report (accurate, batch), and this feeds only the
/// cosmetic caption. Both never run at once — [stop] frees Vosk at "¡Terminé!"
/// before the Whisper pass, so two ASR models are never resident together on
/// the A12.
///
/// The model ships bundled in the APK (see [_modelAsset]/pubspec.yaml), so it
/// works out of the box on a fresh install — no adb push. Defensive like the
/// rest of the pipeline: if extraction or Vosk fails to load for any reason,
/// it simply stays dark and the session is unchanged. The caption is
/// best-effort; it never feeds the report and never breaks the run.
class VoskLiveTranscriber {
  VoskLiveTranscriber._();
  static final VoskLiveTranscriber instance = VoskLiveTranscriber._();

  /// Zipped model, bundled as a Flutter asset (see pubspec.yaml) so a fresh
  /// install works without any adb push. Unzipped lazily on first use by
  /// [ModelLoader] (from vosk_flutter_2) into app storage; cached there for
  /// every later launch.
  static const _modelAsset = 'assets/models/vosk-model-small-es-0.42.zip';

  Model? _model;
  Recognizer? _recognizer;
  bool _triedLoad = false;

  final _partials = StreamController<String>.broadcast();

  /// Running partial text ("" until the first words land).
  Stream<String> get partials => _partials.stream;

  /// Every finalized phrase, accumulated across the whole session. This is what
  /// now feeds the REPORT (the [partials] stream stays the live on-screen
  /// caption). Reset on [start], flushed by [finalize].
  final StringBuffer _full = StringBuffer();

  /// The complete transcript recognized so far (all finalized phrases), tidy.
  String get transcript => _full.toString().replaceAll(RegExp(r'\s+'), ' ').trim();

  bool get isReady => _recognizer != null;

  // Single-flight drain of incoming PCM so the recognizer is never called
  // re-entrantly, without dropping audio (the caption stays coherent).
  final BytesBuilder _pending = BytesBuilder(copy: false);
  bool _draining = false;

  /// Loads the model and recognizer. Safe to call once per session; a missing
  /// model just leaves [isReady] false.
  Future<void> start({int sampleRate = 16000}) async {
    if (_recognizer != null || _triedLoad) return;
    _triedLoad = true;
    _full.clear(); // fresh transcript for this session
    try {
      // Extracts the bundled asset to app storage on first call and reuses
      // it after (ModelLoader checks the target dir before unzipping again).
      final path = await ModelLoader().loadFromAssets(_modelAsset);
      final plugin = VoskFlutterPlugin.instance();
      _model = await plugin.createModel(path);
      _recognizer = await plugin.createRecognizer(
        model: _model!,
        sampleRate: sampleRate,
      );
      _log('vosk: loaded');
    } catch (e) {
      _log('vosk: none (exception: $e)');
      _recognizer = null;
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[STT] $msg');
  }

  /// Feed one PCM16 (mono, 16 kHz) chunk. Non-blocking: chunks are queued and
  /// drained one at a time. No-op until [start] has loaded a model.
  void feed(Uint8List bytes) {
    if (_recognizer == null) return;
    _pending.add(bytes);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    final rec = _recognizer;
    if (rec == null) {
      _pending.clear();
      return;
    }
    _draining = true;
    try {
      while (_pending.length > 0 && _recognizer != null) {
        final chunk = _pending.takeBytes(); // returns + clears
        final endOfPhrase = await rec.acceptWaveformBytes(chunk);
        if (endOfPhrase) {
          // A phrase completed (silence boundary) → bank its final text and
          // reset the live caption for the next phrase.
          _appendFinal(_extractText(await rec.getResult()));
          if (!_partials.isClosed) _partials.add('');
        } else {
          final partial = _extractPartial(await rec.getPartialResult());
          if (!_partials.isClosed) _partials.add(partial);
        }
      }
    } catch (_) {
      // Cosmetic path — swallow and keep the session alive.
    } finally {
      _draining = false;
    }
  }

  void _appendFinal(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    if (_full.isNotEmpty) _full.write(' ');
    _full.write(t);
  }

  String _extractPartial(String resultJson) {
    try {
      final decoded = jsonDecode(resultJson);
      final partial = decoded is Map ? decoded['partial'] : null;
      return partial is String ? partial : '';
    } catch (_) {
      return '';
    }
  }

  String _extractText(String resultJson) {
    try {
      final decoded = jsonDecode(resultJson);
      final text = decoded is Map ? decoded['text'] : null;
      return text is String ? text : '';
    } catch (_) {
      return '';
    }
  }

  /// Flush the last in-flight phrase and return the FULL session transcript.
  /// Call at "¡Terminé!" BEFORE [stop] — this is what the report analyses.
  Future<String> finalize() async {
    final rec = _recognizer;
    if (rec != null) {
      try {
        _appendFinal(_extractText(await rec.getFinalResult()));
      } catch (_) {}
    }
    return transcript;
  }

  /// Frees Vosk after the transcript has been read. Call at "¡Terminé!".
  Future<void> stop() async {
    _pending.clear();
    try {
      await _recognizer?.dispose();
    } catch (_) {}
    _recognizer = null;
    _model = null;
    _triedLoad = false;
  }
}
