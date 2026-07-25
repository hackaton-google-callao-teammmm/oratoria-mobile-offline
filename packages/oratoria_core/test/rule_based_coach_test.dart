import 'package:oratoria_core/oratoria_core.dart';
import 'package:test/test.dart';

void main() {
  const coach = RuleBasedCoach();
  const analyzer = ParaverbalAnalyzer();

  ParaverbalMetrics voice({
    double wpm = 130,
    int fillerCount = 0,
    double fillerRate = 0,
    int awkwardPauses = 0,
    Duration duration = const Duration(seconds: 40),
    int wordCount = 80,
  }) =>
      ParaverbalMetrics(
        wordCount: wordCount,
        fillerCount: fillerCount,
        wordsPerMinute: wpm,
        fillerRate: fillerRate,
        longestPause: Duration.zero,
        awkwardPauseCount: awkwardPauses,
        speakingDuration: duration,
      );

  group('RuleBasedCoach — terminal fallback contract', () {
    test('always returns exactly one strength and one improvement', () async {
      final feedback = await coach.generate(
        voice: voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
      );

      expect(feedback.strengthTitle, isNotEmpty);
      expect(feedback.strengthBody, isNotEmpty);
      expect(feedback.improvementTitle, isNotEmpty);
      expect(feedback.improvementBody, isNotEmpty);
    });

    test('stamps itself as rule-based', () async {
      final feedback = await coach.generate(
        voice: voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
      );

      expect(feedback.source, FeedbackSource.ruleBased);
    });

    test('never fails on hostile inputs', () async {
      final hostile = <ParaverbalMetrics>[
        ParaverbalMetrics.empty,
        voice(wpm: 0, duration: Duration.zero, wordCount: 0),
        voice(wpm: 9999, fillerRate: 9999, awkwardPauses: 9999),
        voice(wpm: -5, fillerRate: -5),
      ];

      for (final metrics in hostile) {
        final feedback = await coach.generate(
          voice: metrics,
          body: BodyMetrics.none,
          exercise: Exercise.free,
        );
        expect(feedback.strengthBody, isNotEmpty);
        expect(feedback.improvementBody, isNotEmpty);
      }
    });

    test('produces feedback for every exercise in the catalog', () async {
      for (final exercise in ExerciseCatalog.all) {
        final feedback = await coach.generate(
          voice: voice(),
          body: BodyMetrics.none,
          exercise: exercise,
        );
        expect(feedback.improvementTitle, isNotEmpty,
            reason: 'exercise ${exercise.id} produced no improvement');
      }
    });
  });

  group('RuleBasedCoach — choices', () {
    test('names fillers as the weak point when they dominate', () async {
      final feedback = await coach.generate(
        voice: voice(fillerCount: 12, fillerRate: 12),
        body: BodyMetrics.none,
        exercise: Exercise.free,
      );

      expect(feedback.improvementDimension, Dimension.fillers);
      expect(feedback.improvementBody, contains('12'));
    });

    test('praises pace when it is the best dimension', () async {
      final feedback = await coach.generate(
        voice: voice(wpm: 130, fillerRate: 8, awkwardPauses: 4),
        body: BodyMetrics.none,
        exercise: Exercise.free,
      );

      expect(feedback.strengthDimension, Dimension.pace);
    });

    test('ignores body dimensions when the camera gave no data', () async {
      final feedback = await coach.generate(
        voice: voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
      );

      expect(
        {feedback.strengthDimension, feedback.improvementDimension},
        isNot(contains(Dimension.eyeContact)),
      );
    });

    test('can pick a body dimension once the camera has data', () async {
      const badPosture = BodyMetrics(
        eyeContactRatio: 0.9,
        smileRatio: 0.5,
        uprightRatio: 0.05,
        framesAnalyzed: 400,
      );

      final feedback = await coach.generate(
        voice: voice(),
        body: badPosture,
        exercise: Exercise.free,
      );

      expect(feedback.improvementDimension, Dimension.posture);
    });

    test('encourages rather than judges when the child barely spoke',
        () async {
      final feedback = await coach.generate(
        voice: voice(wordCount: 2, duration: const Duration(seconds: 2)),
        body: BodyMetrics.none,
        exercise: Exercise.free,
      );

      expect(feedback.strengthTitle, 'Te animaste');
      expect(feedback.improvementBody, contains('Intenta de nuevo'));
    });
  });

  group('RuleBasedCoach — exercise goals', () {
    test('confirms a met pace goal', () async {
      final exercise = ExerciseCatalog.byId('e-presentate')!;
      final feedback = await coach.generate(
        voice: voice(wpm: 130),
        body: BodyMetrics.none,
        exercise: exercise,
      );

      expect(feedback.goalMet, isTrue);
      expect(feedback.goalMessage, contains('lo lograste'));
    });

    test('reports a missed filler goal without scolding', () async {
      final exercise = ExerciseCatalog.byId('e-animal')!;
      final feedback = await coach.generate(
        voice: voice(fillerCount: 20, fillerRate: 20),
        body: BodyMetrics.none,
        exercise: exercise,
      );

      expect(feedback.goalMet, isFalse);
      expect(feedback.goalMessage, isNotNull);
    });

    test('skips a camera goal when there is no camera data', () async {
      // Judging eye contact with no frames would be a confident lie.
      final exercise = ExerciseCatalog.byId('e-pitch')!;
      final feedback = await coach.generate(
        voice: voice(),
        body: BodyMetrics.none,
        exercise: exercise,
      );

      expect(feedback.goalMet, isNull);
      expect(feedback.goalMessage, isNull);
    });

    test('has no goal verdict for free practice', () async {
      final feedback = await coach.generate(
        voice: voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
      );

      expect(feedback.goalMet, isNull);
    });
  });

  group('RuleBasedCoach — honest signals only', () {
    test('never judges pace or fillers when the transcript is untrusted',
        () async {
      // STT failed → the transcript is a sample fallback. Judging its "pace"
      // or "fillers" would be inventing a verdict from placeholder words.
      final feedback = await coach.generate(
        voice: voice(wpm: 130, fillerCount: 9, fillerRate: 9, awkwardPauses: 0),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        voiceTrusted: false,
      );

      final judged = {feedback.strengthDimension, feedback.improvementDimension};
      expect(judged, isNot(contains(Dimension.pace)));
      expect(judged, isNot(contains(Dimension.fillers)));
    });

    test('does not judge pauses when they were not measured', () async {
      final feedback = await coach.generate(
        voice: voice(awkwardPauses: 5),
        body: const BodyMetrics(
          eyeContactRatio: 0.9,
          smileRatio: 0.5,
          uprightRatio: 0.8,
          framesAnalyzed: 400,
        ),
        exercise: Exercise.free,
        voiceTrusted: false,
        pausesTrusted: false,
      );

      final judged = {feedback.strengthDimension, feedback.improvementDimension};
      expect(judged, isNot(contains(Dimension.pauses)));
      // Body was the only trusted signal, so it must carry the feedback.
      expect(judged, contains(Dimension.eyeContact));
    });

    test('falls back to encouragement when nothing trustworthy remains',
        () async {
      // Untrusted transcript AND no camera → there is nothing honest to score.
      final feedback = await coach.generate(
        voice: voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        voiceTrusted: false,
        pausesTrusted: false,
      );

      expect(feedback.strengthTitle, 'Te animaste');
      expect(feedback.improvementBody, contains('Intenta de nuevo'));
    });

    test('withholds a pace goal verdict when the transcript is untrusted',
        () async {
      final exercise = ExerciseCatalog.byId('e-presentate')!;
      final feedback = await coach.generate(
        voice: voice(wpm: 130),
        body: BodyMetrics.none,
        exercise: exercise,
        voiceTrusted: false,
        pausesTrusted: false,
      );

      expect(feedback.goalMet, isNull);
      expect(feedback.goalMessage, isNull);
    });
  });

  group('End-to-end through the analyzer', () {
    test('a real Spanish transcript produces coherent feedback', () async {
      const transcript =
          'Hola a todos, este, hoy quiero contarles sobre mi perro. '
          'Este, se llama Rocky y, o sea, es muy juguetón. '
          'Le gusta correr en el parque y, este, jugar con la pelota.';

      final metrics = analyzer.analyze(
        transcript: transcript,
        speakingDuration: const Duration(seconds: 25),
        pauses: const [Duration(milliseconds: 1800)],
      );

      final feedback = await coach.generate(
        voice: metrics,
        body: BodyMetrics.none,
        exercise: ExerciseCatalog.byId('e-animal')!,
      );

      expect(metrics.fillerCount, 4); // 3x "este" + 1x "o sea"
      expect(feedback.improvementDimension, Dimension.fillers);
      expect(feedback.goalMet, isFalse);
    });
  });
}
