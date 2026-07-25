import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// On-device speech-to-text via sherpa-onnx (multilingual Whisper, Spanish).
/// Closes the last mock: instead of a canned transcript, the paraverbal analysis
/// now runs on what the child actually said, so filler counts and pace are real.
///
/// Picks the best model the phone can hold from a ladder (small → base → tiny),
/// gated by free RAM — a roomy phone gets `small` (best accuracy), a cramped one
/// steps down cleanly instead of OOM-killing.
///
/// Fully offline: the ONNX runtime is bundled in the APK; the model files are
/// sideloaded like Gemma. Defensive like everything else — if no model is
/// present or loading fails, [transcribe] returns null and the caller falls
/// back, so the session never breaks (golden rule).
class SherpaTranscriber {
  SherpaTranscriber._();
  static final SherpaTranscriber instance = SherpaTranscriber._();

  /// Whisper processes at most the first 30 s of a clip and discards the rest
  /// ("Only waves less than 30 seconds are supported"). Callers use this to cap
  /// the per-minute rate denominator so a longer run's pace isn't computed from
  /// words the model never transcribed.
  static const maxAudioWindow = Duration(seconds: 30);

  // Whisper models, sideloaded to the app's external files dir. All are the
  // MULTILINGUAL variants (never `.en`, which would be worse for Spanish).
  static const _prefSmall = 'small';
  static const _prefBase = 'base';
  static const _prefTiny = 'tiny';

  /// Model ladder, best → safest. Each entry is (file prefix, minimum free RAM
  /// in MB to even attempt loading it). Whisper's runtime peak (ONNX sessions +
  /// weights + activation + KV cache, alongside a resident Gemma) is far above
  /// its file size, and a hard OOM-kill (LMKD → SIGKILL) is NOT a catchable Dart
  /// error — so the gate converts "would OOM" into a clean step down instead of
  /// a crash. It is not a guarantee (TOCTOU); the try/catch below stays and the
  /// device is the final arbiter. `tiny`'s gate is 0: the last-resort fallback
  /// must always be allowed to try. Tune the gates on the real presentation
  /// phone, and read the log to see which model actually won.
  static const _ladder = <(String, int)>[
    (_prefSmall, 1400), // ~460 MB files — best accuracy, needs a roomy phone
    (_prefBase, 750), //   ~160 MB files — a big step over tiny
    (_prefTiny, 0), //     ~100 MB files — always-safe fallback
  ];

  /// Extra tail padding (samples @16 kHz) fed to Whisper — a modest amount can
  /// curb end-of-clip hallucination. A/B on device; set to -1 (sherpa default)
  /// if it doesn't help.
  static const _tailPaddings = 3200;

  sherpa.OfflineRecognizer? _recognizer;
  String _active = 'none';
  bool _triedLoad = false;
  bool _initialised = false;

  bool get isAvailable => _recognizer != null;

  /// Which model is actually loaded ('small' / 'base' / 'tiny' / 'none') —
  /// surfaced for the log so we can confirm the best one won.
  String get activeModel => _active;

  Future<void> _ensureLoaded() async {
    if (_recognizer != null || (_triedLoad && _recognizer == null)) return;
    _triedLoad = true;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final path = dir.path;
      final ramMb = _availableRamMb();

      // Descend the ladder: load the best model that is BOTH present AND fits
      // RAM. Record why each better one was skipped so the log tells the whole
      // story ("whisper: base (skipped small: missing)").
      final skipped = <String>[];
      for (final (prefix, gateMb) in _ladder) {
        if (!_modelPresent(path, prefix)) {
          skipped.add('$prefix: missing');
          continue;
        }
        if (ramMb < gateMb) {
          skipped.add('$prefix: RAM gate ($ramMb MB < $gateMb)');
          continue;
        }
        final rec = _tryCreate(path, prefix);
        if (rec == null) {
          skipped.add('$prefix: init failed');
          continue;
        }
        _recognizer = rec;
        _active = prefix;
        _log(skipped.isEmpty
            ? 'whisper: $prefix'
            : 'whisper: $prefix (skipped ${skipped.join('; ')})');
        return;
      }
      // Nothing loaded — no model sideloaded (or all init-failed). The caller
      // falls back to the sample transcript and the session survives.
      _log('whisper: none (${skipped.join('; ')})');
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
