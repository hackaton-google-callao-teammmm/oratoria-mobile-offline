import 'package:oratoria_core/oratoria_core.dart';
import 'package:test/test.dart';

void main() {
  const scoring = Scoring();

  ParaverbalMetrics metrics({
    double wpm = 130,
    double fillerRate = 0,
    int awkwardPauses = 0,
  }) =>
      ParaverbalMetrics(
        wordCount: 60,
        fillerCount: 0,
        wordsPerMinute: wpm,
        fillerRate: fillerRate,
        longestPause: Duration.zero,
        awkwardPauseCount: awkwardPauses,
        speakingDuration: const Duration(seconds: 30),
      );

  group('Scoring bands', () {
    test('gives full marks inside the comfortable pace band', () {
      expect(scoring.paceScore(110), 100);
      expect(scoring.paceScore(130), 100);
      expect(scoring.paceScore(150), 100);
    });

    test('penalises rushing and dragging', () {
      expect(scoring.paceScore(190), lessThan(5));
      expect(scoring.paceScore(60), lessThan(5));
    });

    test('never returns a negative score', () {
      expect(scoring.paceScore(400), greaterThanOrEqualTo(0));
      expect(scoring.fillerScore(100), greaterThanOrEqualTo(0));
      expect(scoring.pauseScore(50), greaterThanOrEqualTo(0));
    });
  });

  group('Scoring.score', () {
    test('returns a neutral 50 when there is too little speech', () {
      // A shy child who says four words must not be told they failed.
      const short = ParaverbalMetrics(
        wordCount: 2,
        fillerCount: 0,
        wordsPerMinute: 200,
        fillerRate: 0,
        longestPause: Duration.zero,
        awkwardPauseCount: 0,
        speakingDuration: Duration(seconds: 2),
      );

      expect(scoring.score(short), 50);
    });

    test('scores a clean run highly', () {
      expect(scoring.score(metrics()), greaterThan(90));
    });

    test('ignores body metrics when the camera produced no data', () {
      // Audio-only practice must not be penalised for absent camera signals.
      final withoutCamera = scoring.score(metrics());
      final withEmptyCamera =
          scoring.score(metrics(), body: BodyMetrics.none);

      expect(withEmptyCamera, withoutCamera);
    });

    test('includes body metrics once there is enough camera data', () {
      const poorBody = BodyMetrics(
        eyeContactRatio: 0.1,
        smileRatio: 0.1,
        uprightRatio: 0.1,
        framesAnalyzed: 300,
      );

      expect(
        scoring.score(metrics(), body: poorBody),
        lessThan(scoring.score(metrics())),
      );
    });

    test('stays within 0..100', () {
      const awful = ParaverbalMetrics(
        wordCount: 200,
        fillerCount: 100,
        wordsPerMinute: 400,
        fillerRate: 60,
        longestPause: Duration(seconds: 9),
        awkwardPauseCount: 30,
        speakingDuration: Duration(seconds: 90),
      );

      expect(scoring.score(awful), inInclusiveRange(0, 100));
    });
  });

  group('Scoring.stars', () {
    test('maps scores onto 1..5 stars', () {
      expect(scoring.stars(0), 1);
      expect(scoring.stars(35), 2);
      expect(scoring.stars(55), 3);
      expect(scoring.stars(75), 4);
      expect(scoring.stars(100), 5);
    });

    test('never shows zero stars', () {
      for (var score = 0; score <= 100; score++) {
        expect(scoring.stars(score), inInclusiveRange(1, 5));
      }
    });

    test('gives every star count a label', () {
      for (var stars = 1; stars <= 5; stars++) {
        expect(scoring.level(stars), isNotEmpty);
      }
    });
  });
}
