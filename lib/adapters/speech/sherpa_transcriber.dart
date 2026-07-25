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

  // Two Whisper models, sideloaded (adb push) to the app's external files dir.
  // Prefer `base` (much better than `tiny` for a child's accented Spanish); fall
  // back to `tiny` when base isn't present or won't fit in RAM. Use the
  // MULTILINGUAL base, never `base.en` (English-only would be worse for Spanish).
  static const _prefBase = 'base';
  static const _prefTiny = 'tiny';

  /// Skip loading `base` when free RAM is under this — its runtime peak (ONNX
  /// session + weights + activation buffers, alongside a resident Gemma) is far
  /// above its ~150 MB file, and a hard OOM-kill (LMKD → SIGKILL) is NOT a
  /// catchable Dart error. The gate lowers that probability; it is not a
  /// guarantee (TOCTOU), so the try/catch below stays and the device is the
  /// final arbiter. Tune on the A12: too low → OOM, too high → silently stuck
  /// on tiny. Confirm the log says `whisper: base` before trusting base.
  static const _ramGateMb = 750;

  /// Extra tail padding (samples @16 kHz) fed to Whisper — a modest amount can
  /// curb end-of-clip hallucination. A/B on device; set to -1 (sherpa default)
  /// if it doesn't help.
  static const _tailPaddings = 3200;

  sherpa.OfflineRecognizer? _recognizer;
  String _active = 'none';
  bool _triedLoad = false;
  bool _initialised = false;

  bool get isAvailable => _recognizer != null;

  /// Which model is actually loaded ('base' / 'tiny' / 'none') — for the log.
  String get activeModel => _active;

  Future<void> _ensureLoaded() async {
    if (_recognizer != null || (_triedLoad && _recognizer == null)) return;
    _triedLoad = true;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final path = dir.path;

      final baseReady = _modelPresent(path, _prefBase);
      final tinyReady = _modelPresent(path, _prefTiny);
      final ramOk = _availableRamMb() >= _ramGateMb;

      String reason;
      if (baseReady && ramOk) {
        _recognizer = _tryCreate(path, _prefBase);
        if (_recognizer != null) {
          _active = 'base';
          _log('whisper: base');
          return;
        }
        reason = 'base init failed';
      } else if (baseReady && !ramOk) {
        reason = 'RAM gate';
      } else {
        reason = 'base missing';
      }

      // Fall back to tiny — already sideloaded, lighter, keeps the session alive.
      if (tinyReady) {
        _recognizer = _tryCreate(path, _prefTiny);
        if (_recognizer != null) {
          _active = 'tiny';
          _log('whisper: tiny ($reason)');
        }
      }
    } catch (_) {
      _recognizer = null;
    }
  }

  bool _modelPresent(String dir, String prefix) =>
      File('$dir/$prefix-encoder.int8.onnx').existsSync() &&
      File('$dir/$prefix-decoder.int8.onnx').existsSync() &&
      File('$dir/$prefix-tokens.txt').existsSync();

  sherpa.OfflineRecognizer? _tryCreate(String dir, String prefix) {
    try {
      if (!_initialised) {
        sherpa.initBindings();
        _initialised = true;
      }
      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: '$dir/$prefix-encoder.int8.onnx',
            decoder: '$dir/$prefix-decoder.int8.onnx',
            language: 'es', // force Spanish — no auto-detect wobble
            task: 'transcribe',
            tailPaddings: _tailPaddings,
          ),
          tokens: '$dir/$prefix-tokens.txt',
          modelType: 'whisper',
          numThreads: 2,
        ),
      );
      return sherpa.OfflineRecognizer(config); // may OOM-kill (uncatchable)
    } catch (_) {
      return null; // clean init failure — the fallback handles it
    }
  }

  /// Free RAM in MB, read from Android's world-readable `/proc/meminfo` in pure
  /// Dart (no native code, no package, no permission). On any failure, report
  /// "plenty" so a read error never wrongly blocks base — the try/catch and the
  /// device remain the real safeguards.
  int _availableRamMb() {
    try {
      for (final line in File('/proc/meminfo').readAsLinesSync()) {
        if (line.startsWith('MemAvailable:')) {
          final kb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
          if (kb != null) return kb ~/ 1024;
        }
      }
    } catch (_) {}
    return 1 << 20; // unknown → assume plenty
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[STT] $msg');
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
    _active = 'none';
    _triedLoad = false; // allow a reload next session
  }
}
