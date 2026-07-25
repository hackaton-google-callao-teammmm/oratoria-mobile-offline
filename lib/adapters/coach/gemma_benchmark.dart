import 'package:flutter_gemma/flutter_gemma.dart';

/// One measured generation.
class BenchmarkRun {
  final String label;
  final String prompt;
  final String response;

  /// Time from sending the prompt to the last token.
  final Duration elapsed;

  /// Tokens in the response, as counted by the model's own tokenizer.
  final int responseTokens;

  const BenchmarkRun({
    required this.label,
    required this.prompt,
    required this.response,
    required this.elapsed,
    required this.responseTokens,
  });

  double get tokensPerSecond =>
      elapsed.inMilliseconds == 0 ? 0 : responseTokens / (elapsed.inMilliseconds / 1000);

  /// The number that decides the demo. Under ~6 s a "thinking" animation
  /// covers it; over ~12 s the audience notices the app hung.
  bool get demoViable => elapsed.inSeconds <= 6;

  @override
  String toString() => '$label: ${elapsed.inMilliseconds}ms · '
      '$responseTokens tok · ${tokensPerSecond.toStringAsFixed(1)} tok/s '
      '${demoViable ? "OK" : "TOO SLOW"}';
}

/// Measures on-device Gemma latency on the machine that will run the demo.
///
/// This exists because the GPU delegate is the whole game: the same model
/// answers in well under a second on GPU and takes roughly ten seconds on a
/// mid-range CPU. That number cannot be guessed, assumed from a datasheet, or
/// read off an emulator — it has to be measured on the actual demo device.
///
/// Written against flutter_gemma **0.16.5**, which is what resolves on Dart
/// 3.10.x. The 1.x API (`FlutterGemma.installModel(...).fromNetwork(...)`,
/// `getActiveModel`) is different and will not compile here.
class GemmaBenchmark {
  /// Prompts sized like the real ones the demo uses, so the timings transfer.
  static const followUpPrompt =
      'Eres un niño curioso del público. El expositor habló sobre: los '
      'volcanes. Hazle UNA pregunta corta y amable en español para que siga '
      'hablando. Máximo 12 palabras. Solo la pregunta.';

  static const coachPrompt =
      'Eres Vox, un coach amable para niños. Datos de la práctica: '
      'ritmo=165 ppm, muletillas=6, energía=alta. '
      'Escribe: (1) una FORTALEZA y (2) una MEJORA, en español simple y '
      'cariñoso, una frase cada una. Nunca regañes.';

  final ModelType modelType;
  final PreferredBackend backend;
  final int maxTokens;

  const GemmaBenchmark({
    this.modelType = ModelType.gemmaIt,
    this.backend = PreferredBackend.gpu,
    this.maxTokens = 512,
  });

  /// Runs both demo prompts and returns the measurements.
  ///
  /// Assumes the model is already installed via
  /// `FlutterGemmaPlugin.instance.modelManager`. Installation is a separate,
  /// one-off step and is deliberately not timed here — the demo never pays
  /// that cost.
  Future<List<BenchmarkRun>> run() async {
    final plugin = FlutterGemmaPlugin.instance;

    final model = await plugin.createModel(
      modelType: modelType,
      maxTokens: maxTokens,
      preferredBackend: backend,
    );

    try {
      final runs = <BenchmarkRun>[];

      // The first generation after load includes warm-up and is not
      // representative — the real app pre-warms at startup. Measure it anyway
      // so we know how long that pre-warm has to be.
      runs.add(await _measure(model, 'warm-up (repregunta)', followUpPrompt));
      runs.add(await _measure(model, 'repregunta', followUpPrompt));
      runs.add(await _measure(model, 'feedback del coach', coachPrompt));

      return runs;
    } finally {
      await model.close();
    }
  }

  Future<BenchmarkRun> _measure(
    InferenceModel model,
    String label,
    String prompt,
  ) async {
    // A fresh session per run: reusing one would let the KV cache from the
    // previous prompt make later runs look artificially fast.
    final session = await model.createSession(temperature: 0.8, randomSeed: 1);

    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));

      final stopwatch = Stopwatch()..start();
      final response = await session.getResponse();
      stopwatch.stop();

      // Count with the model's own tokenizer rather than splitting on spaces,
      // so tok/s is comparable to published benchmarks.
      final tokens = await session.sizeInTokens(response);

      return BenchmarkRun(
        label: label,
        prompt: prompt,
        response: response,
        elapsed: stopwatch.elapsed,
        responseTokens: tokens,
      );
    } finally {
      await session.close();
    }
  }
}
