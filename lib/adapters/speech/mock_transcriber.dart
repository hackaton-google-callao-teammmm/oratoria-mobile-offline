import 'dart:async';

import 'package:oratoria_core/oratoria_core.dart';

/// Development and demo transcriber.
///
/// Replays a canned Spanish transcript so the whole pipeline — analysis,
/// scoring, coaching, report UI — can be exercised before the sherpa-onnx
/// adapter lands in phase 2. It is also what makes the report screen testable
/// without a microphone.
class MockTranscriber implements SpeechTranscriber {
  /// A transcript with the flaws a child actually produces: fillers, a rushed
  /// pace, and one real demonstrative ("de este modo") that the detector must
  /// *not* count.
  static const sampleTranscript =
      'Hola a todos, este, hoy les quiero contar sobre mi perro. '
      'Este, se llama Rocky y, o sea, es muy juguetón. '
      'Le enseñé a dar la pata de este modo, con premios. '
      'Le gusta correr en el parque y, este, jugar con la pelota hasta que '
      'se cansa. Eso es todo, gracias.';

  final String transcript;
  final _controller = StreamController<String>.broadcast();

  MockTranscriber({this.transcript = sampleTranscript});

  @override
  bool get isReady => true;

  @override
  Stream<String> get partials => _controller.stream;

  @override
  Future<void> start() async {
    // Emit the transcript word by word so the live HUD has something to react
    // to, at roughly a natural speaking cadence.
    final words = transcript.split(' ');
    var soFar = '';
    for (final word in words) {
      if (_controller.isClosed) return;
      soFar = soFar.isEmpty ? word : '$soFar $word';
      _controller.add(soFar);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
  }

  @override
  Future<String> stop() async {
    await _controller.close();
    return transcript;
  }
}
