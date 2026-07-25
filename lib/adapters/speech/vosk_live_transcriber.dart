import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
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
/// Defensive like the rest of the pipeline: if the model isn't sideloaded, or
/// Vosk fails to load, it simply stays dark and the session is unchanged. The
/// caption is best-effort; it never feeds the report and never breaks the run.
class VoskLiveTranscriber {
  VoskLiveTranscriber._();
  static final VoskLiveTranscriber instance = VoskLiveTranscriber._();

  /// Unzipped model directory, sideloaded to the app's external files dir
  /// (adb push), exactly like the Gemma and Whisper models.
  static const _modelDir = 'vosk-model-small-es-0.42';

  Model? _model;
  Recognizer? _recognizer;
  bool _triedLoad = false;

  final _partials = StreamController<String>.broadcast();

  /// Running partial text ("" until the first words land).
  Stream<String> get partials => _partials.stream;

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
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final path = '${dir.path}/$_modelDir';
      if (!Directory(path).existsSync()) return; // not sideloaded → stays dark

      final plugin = VoskFlutterPlugin.instance();
      _model = await plugin.createModel(path);
      _recognizer = await plugin.createRecognizer(
        model: _model!,
        sampleRate: sampleRate,
      );
    } catch (_) {
      _recognizer = null;
    }
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
        await rec.acceptWaveformBytes(chunk);
        final partial = _extractPartial(await rec.getPartialResult());
        if (!_partials.isClosed) _partials.add(partial);
      }
    } catch (_) {
      // Cosmetic path — swallow and keep the session alive.
    } finally {
      _draining = false;
    }
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

  /// Frees Vosk BEFORE the report's Whisper pass. Call at "¡Terminé!".
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
