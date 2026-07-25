import 'dart:async';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

/// Loads and runs the on-device Gemma model, defensively.
///
/// This is the single most fragile part of the app on a 3.6 GB / ~1.4 GB-free
/// Exynos 850, so every entry point is guarded: if the model file is missing,
/// if loading throws (OOM), or if a generation hangs, the service reports
/// itself unavailable and callers fall back — the session never breaks
/// (golden rule). The model is a process-wide singleton: loaded once, reused,
/// pre-warmed at startup so the first real answer during a session is not the
/// slow cold one.
class GemmaService {
  GemmaService._();
  static final GemmaService instance = GemmaService._();

  /// The int4 model pushed to the app's external files dir via adb before the
  /// event. q4 (~550 MB) is the only variant that fits the A12's RAM.
  static const modelFileName = 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';

  InferenceModel? _model;
  bool _triedLoad = false;
  bool _available = false;
  Completer<void>? _loading;

  /// True once the model has loaded successfully at least once.
  bool get isAvailable => _available;

  /// Absolute path where the benchmark screen and the runbook expect the model.
  Future<String?> _modelPath() async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return null;
    final path = '${dir.path}/$modelFileName';
    return File(path).existsSync() ? path : null;
  }

  /// Load the model once. Safe to call repeatedly and concurrently. Never
  /// throws — on any failure it leaves the service unavailable.
  Future<void> ensureLoaded() async {
    if (_available) return;
    if (_loading != null) return _loading!.future;
    if (_triedLoad && !_available) return; // already failed; don't retry-storm

    _triedLoad = true;
    final loading = _loading = Completer<void>();
    try {
      final path = await _modelPath();
      if (path == null) {
        // No model on device → stays unavailable, callers use the fallback.
        _available = false;
      } else {
        // 0.16.5 requires this once before any plugin use. No token needed —
        // the model is sideloaded, not downloaded.
        await FlutterGemma.initialize();
        final plugin = FlutterGemmaPlugin.instance;
        // The 1.x builder API (installModel().fromFile()) needs Dart 3.12,
        // which this toolchain lacks; setModelPath is the working 0.16.5 path.
        // ignore: deprecated_member_use
        await plugin.modelManager.setModelPath(path);
        _model = await plugin.createModel(
          modelType: ModelType.gemmaIt,
          maxTokens: 256,
          preferredBackend: PreferredBackend.gpu,
        );
        _available = true;
      }
    } catch (_) {
      // OOM, missing OpenCL, corrupt file — all end here. Session still runs.
      _available = false;
      _model = null;
    } finally {
      loading.complete();
      _loading = null;
    }
  }

  /// Fire a dummy inference so the first real answer isn't the slow cold one.
  /// Called from the splash. Fully swallowed — pre-warm never blocks the UI.
  Future<void> warmUp() async {
    try {
      await ensureLoaded();
      if (!_available) return;
      await ask('Hola', maxTokens: 8, timeout: const Duration(seconds: 20));
    } catch (_) {/* pre-warm is best-effort */}
  }

  /// Generate a response. Returns null on any failure or timeout, so the
  /// caller can fall back. [timeout] is a hard ceiling — a hung generation
  /// must never freeze the child's session.
  Future<String?> ask(
    String prompt, {
    int maxTokens = 64,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await ensureLoaded();
    final model = _model;
    if (!_available || model == null) return null;

    InferenceModelSession? session;
    try {
      return await () async {
        session = await model.createSession(temperature: 0.8, randomSeed: 1);
        await session!.addQueryChunk(Message.text(text: prompt, isUser: true));
        // Stream the tokens (getResponseAsync) instead of getResponse(): the
        // sync path calls MediaPipe's nativePredictSync ON THE MAIN/UI THREAD,
        // freezing it for the whole inference → an ANR that Android kills as a
        // "crash" (confirmed on-device in the `_finish` beat). The async path
        // runs generation off the UI thread and yields tokens, so the session
        // never freezes.
        final buffer = StringBuffer();
        await for (final token in session!.getResponseAsync()) {
          buffer.write(token);
        }
        return buffer.toString().trim();
      }()
          .timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      try {
        await session?.close();
      } catch (_) {}
    }
  }
}
