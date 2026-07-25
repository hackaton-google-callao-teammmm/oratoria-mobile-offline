import 'package:oratoria_core/oratoria_core.dart';
import 'package:test/test.dart';

/// Stands in for Gemma or a LAN host that dies mid-call.
class _ExplodingCoach implements CoachFeedbackGenerator {
  @override
  Future<CoachFeedback> generate({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
  }) async {
    throw StateError('out of memory');
  }

  @override
  Future<String> generateInitialChallenge(String? aiProfile) async {
    throw StateError('out of memory');
  }

  @override
  Future<(CoachFeedback feedback, String? updatedAiProfile)> generateWithProfile({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
    String? aiProfile,
    String? transcript,
  }) async {
    throw StateError('out of memory');
  }
}

/// Stands in for a healthy on-device model.
class _FakeLlmCoach implements CoachFeedbackGenerator {
  @override
  Future<CoachFeedback> generate({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
  }) async =>
      const CoachFeedback(
        strengthDimension: Dimension.pace,
        strengthTitle: 'Qué bien te expresaste',
        strengthBody: 'Prosa cálida generada por el modelo.',
        improvementDimension: Dimension.fillers,
        improvementTitle: 'Un detalle para la próxima',
        improvementBody: 'Prosa cálida generada por el modelo.',
        source: FeedbackSource.onDeviceLlm,
      );

  @override
  Future<String> generateInitialChallenge(String? aiProfile) async =>
      '¡Hola! Soy Vox. ¿Cuál es tu dinosaurio favorito?';

  @override
  Future<(CoachFeedback feedback, String? updatedAiProfile)> generateWithProfile({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
    String? aiProfile,
    String? transcript,
  }) async {
    final fb = await generate(
      voice: voice,
      body: body,
      exercise: exercise,
      voiceTrusted: voiceTrusted,
      pausesTrusted: pausesTrusted,
    );
    final updated = '{"interests":["dinosaurios"]}';
    return (fb, updated);
  }
}

void main() {
  group('EvaluatePractice', () {
    test('produces a complete result from a transcript', () async {
      final evaluate = EvaluatePractice(coach: const RuleBasedCoach());

      final result = await evaluate(
        transcript:
            'Hola, me llamo Ana y hoy quiero contarles sobre mi colegio '
            'y sobre las cosas que aprendo cada día con mis compañeros.',
        speakingDuration: const Duration(seconds: 20),
        exercise: ExerciseCatalog.byId('e-presentate')!,
      );

      expect(result.score, inInclusiveRange(0, 100));
      expect(result.stars, inInclusiveRange(1, 5));
      expect(result.levelLabel, isNotEmpty);
      expect(result.feedback.strengthBody, isNotEmpty);
      expect(result.voice.wordCount, greaterThan(0));
    });

    test('uses the injected coach when it works', () async {
      final evaluate = EvaluatePractice(coach: _FakeLlmCoach());

      final result = await evaluate(
        transcript: 'hola a todos hoy les quiero contar una historia bonita',
        speakingDuration: const Duration(seconds: 15),
      );

      expect(result.source, FeedbackSource.onDeviceLlm);
    });

    test('falls back to templates when the coach explodes', () async {
      // The whole "works on any device" promise lives in this test: a model
      // that runs out of memory must never cost a child their feedback.
      final evaluate = EvaluatePractice(coach: _ExplodingCoach());

      final result = await evaluate(
        transcript: 'hola a todos hoy les quiero contar una historia bonita',
        speakingDuration: const Duration(seconds: 15),
      );

      expect(result.source, FeedbackSource.ruleBased);
      expect(result.feedback.improvementBody, isNotEmpty);
    });

    test('handles an empty transcript without throwing', () async {
      final evaluate = EvaluatePractice(coach: const RuleBasedCoach());

      final result = await evaluate(
        transcript: '',
        speakingDuration: Duration.zero,
      );

      expect(result.stars, inInclusiveRange(1, 5));
      expect(result.feedback.strengthBody, isNotEmpty);
    });

    test('passes aiProfile and returns updatedAiProfile when available', () async {
      final evaluate = EvaluatePractice(coach: _FakeLlmCoach());

      final result = await evaluate(
        transcript: 'me gustan los dinosaurios rex',
        speakingDuration: const Duration(seconds: 10),
        aiProfile: '{"interests":[]}',
      );

      expect(result.updatedAiProfile, contains('dinosaurios'));
    });

    test('runs audio-only when there is no camera', () async {
      final evaluate = EvaluatePractice(coach: const RuleBasedCoach());

      final result = await evaluate(
        transcript: 'hola a todos hoy les quiero contar una historia bonita',
        speakingDuration: const Duration(seconds: 15),
        body: BodyMetrics.none,
      );

      expect(result.body.hasData, isFalse);
      expect(result.score, greaterThan(0));
    });
  });

  group('NullBodyLanguageAnalyzer', () {
    test('reports unavailable and yields no data', () async {
      const analyzer = NullBodyLanguageAnalyzer();
      await analyzer.start();

      expect(analyzer.isAvailable, isFalse);
      expect(await analyzer.stop(), BodyMetrics.none);
      expect(await analyzer.live.toList(), isEmpty);
    });
  });
}
