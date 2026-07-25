import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// On-device speech-to-text via sherpa-onnx (Whisper tiny, Spanish). Closes the
/// last mock: instead of a canned transcript, the paraverbal analysis now runs
/// on what the child actually said, so filler counts and pace are real.
///
/// Fully offline: the ONNX runtime is bundled in the APK; the model is
/// sideloaded (adb push) like Gemma. Defensive like everything else — if the
/// model is missing or loading fails, [transcribe] returns null and the caller
/// falls back, so the session never breaks (golden rule).
class SherpaTranscriber {
  SherpaTranscriber._();
  static final SherpaTranscriber instance = SherpaTranscriber._();

  /// Whisper processes at most the first 30 s of a clip and discards the rest
  /// ("Only waves less than 30 seconds are supported"). Callers use this to cap
  /// the per-minute rate denominator so a longer run's pace isn't computed from
  /// words the model never transcribed.
  static const maxAudioWindow = Duration(seconds: 30);

  // sherpa-onnx-whisper-tiny sideloaded to the app's external files dir.
  static const _encoder = 'tiny-encoder.int8.onnx';
  static const _decoder = 'tiny-decoder.int8.onnx';
  static const _tokens = 'tiny-tokens.txt';

  sherpa.OfflineRecognizer? _recognizer;
  bool _triedLoad = false;
  bool _initialised = false;

  bool get isAvailable => _recognizer != null;

  Future<void> _ensureLoaded() async {
    if (_recognizer != null || (_triedLoad && _recognizer == null)) return;
    _triedLoad = true;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final enc = '${dir.path}/$_encoder';
      final dec = '${dir.path}/$_decoder';
      final tok = '${dir.path}/$_tokens';
      if (!File(enc).existsSync() ||
          !File(dec).existsSync() ||
          !File(tok).existsSync()) {
        return; // model not sideloaded → stays unavailable
      }

      if (!_initialised) {
        sherpa.initBindings();
        _initialised = true;
      }

      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: enc,
            decoder: dec,
            language: 'es', // force Spanish — no auto-detect wobble
            task: 'transcribe',
          ),
          tokens: tok,
          modelType: 'whisper',
          numThreads: 2,
        ),
      );
      _recognizer = sherpa.OfflineRecognizer(config);
    } catch (_) {
      _recognizer = null;
    }
  }

  /// Transcribe 16 kHz mono float samples. Returns null on any failure so the
  /// caller can fall back to the sample transcript.
  ///
  /// The recognizer is FREED after each call: keeping Whisper (~100 MB) loaded
  /// alongside a resident Gemma pushed the A12's free RAM to ~260 MB and woke
  /// the low-memory killer. Loading per-session costs ~1-2 s but keeps the
  /// steady-state footprint to just Gemma, which is far safer on a 3.6 GB phone.
  Future<String?> transcribe(Float32List samples, {int sampleRate = 16000}) async {
    if (samples.isEmpty) return null;
    await _ensureLoaded();
    final rec = _recognizer;
    if (rec == null) return null;
    sherpa.OfflineStream? stream;
    try {
      stream = rec.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      rec.decode(stream);
      final text = rec.getResult(stream).text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      stream?.free();
      _free();
    }
  }

  void _free() {
    try {
      _recognizer?.free();
    } catch (_) {}
    _recognizer = null;
    _triedLoad = false; // allow a reload next session
  }
}
