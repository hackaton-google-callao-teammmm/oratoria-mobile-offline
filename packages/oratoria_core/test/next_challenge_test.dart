import 'package:oratoria_core/oratoria_core.dart';
import 'package:test/test.dart';

PracticeResult _result({
  required Dimension improvement,
  required Exercise exercise,
  bool voiceTextTrusted = true,
  bool pausesTrusted = true,
  bool meaningful = true,
  bool bodyHasData = false,
}) {
  final voice = ParaverbalMetrics(
    wordCount: meaningful ? 60 : 2,
    fillerCount: 0,
    wordsPerMinute: 120,
    fillerRate: 0,
    longestPause: Duration.zero,
    awkwardPauseCount: 1,
    speakingDuration: Duration(seconds: meaningful ? 40 : 2),
  );
  final body = bodyHasData
      ? const BodyMetrics(
          eyeContactRatio: 0.8,
          smileRatio: 0.5,
          uprightRatio: 0.8,
          framesAnalyzed: 400,
        )
      : BodyMetrics.none;
  final feedback = CoachFeedback(
    strengthDimension: Dimension.pace,
    strengthTitle: 's',
    strengthBody: 's',
    improvementDimension: improvement,
    improvementTitle: 'i',
    improvementBody: 'i',
    source: FeedbackSource.ruleBased,
  );
  return PracticeResult(
    exercise: exercise,
    voice: voice,
    body: body,
    feedback: feedback,
    score: 70,
    stars: 3,
    levelLabel: 'x',
    voiceTextTrusted: voiceTextTrusted,
    pausesTrusted: pausesTrusted,
  );
}

void main() {
  group('suggestNextChallenge — exact maps (causal)', () {
    final cases = {
      Dimension.pace: 'e-presentate',
      Dimension.fillers: 'e-animal',
      Dimension.eyeContact: 'e-pitch',
      Dimension.posture: 'e-cuento',
    };

    cases.forEach((dimension, exerciseId) {
      test('$dimension -> $exerciseId, causal', () {
        final s = suggestNextChallenge(
          // Just finished free practice, so it is never a repeat.
          _result(improvement: dimension, exercise: Exercise.free),
        );
        expect(s.exercise.id, exerciseId);
        expect(s.kind, SuggestionKind.causal);
        expect(s.forDimension, dimension);
      });
    });
  });

  group('suggestNextChallenge — proxy (no dedicated reto)', () {
    test('pauses -> Cuenta un cuento, proxy', () {
      final s = suggestNextChallenge(
        _result(improvement: Dimension.pauses, exercise: Exercise.free),
      );
      expect(s.exercise.id, 'e-cuento');
      expect(s.kind, SuggestionKind.proxy);
      expect(s.forDimension, Dimension.pauses);
    });

    test('expression (defensive dead branch) -> Cuenta un cuento, proxy', () {
      final s = suggestNextChallenge(
        _result(improvement: Dimension.expression, exercise: Exercise.free),
      );
      expect(s.exercise.id, 'e-cuento');
      expect(s.kind, SuggestionKind.proxy);
    });
  });

  group('suggestNextChallenge — reinforce (recommended == just done)', () {
    test('weak pace after Preséntate -> Preséntate, reinforce', () {
      final presentate = ExerciseCatalog.byId('e-presentate')!;
      final s = suggestNextChallenge(
        _result(improvement: Dimension.pace, exercise: presentate),
      );
      expect(s.exercise.id, 'e-presentate');
      expect(s.kind, SuggestionKind.reinforce);
      expect(s.forDimension, Dimension.pace);
    });

    test('weak pauses after Cuento -> Cuento, reinforce (proxy becomes repeat)',
        () {
      final cuento = ExerciseCatalog.byId('e-cuento')!;
      final s = suggestNextChallenge(
        _result(improvement: Dimension.pauses, exercise: cuento),
      );
      expect(s.exercise.id, 'e-cuento');
      expect(s.kind, SuggestionKind.reinforce);
    });
  });

  group('suggestNextChallenge — diagnostic (no confident weakness)', () {
    test('untrusted audio + no face -> Preséntate, diagnostic', () {
      final s = suggestNextChallenge(_result(
        improvement: Dimension.pace,
        exercise: Exercise.free,
        voiceTextTrusted: false,
        pausesTrusted: false,
        bodyHasData: false,
      ));
      expect(s.exercise.id, 'e-presentate');
      expect(s.kind, SuggestionKind.diagnostic);
      expect(s.forDimension, isNull);
    });

    test('too short (not meaningful) + no other signal -> diagnostic', () {
      final s = suggestNextChallenge(_result(
        improvement: Dimension.pace,
        exercise: Exercise.free,
        meaningful: false,
        pausesTrusted: false,
        bodyHasData: false,
      ));
      expect(s.kind, SuggestionKind.diagnostic);
    });

    test('trusted body alone (no voice) still routes on the body weakness', () {
      // Camera measured something, so it is NOT diagnostic.
      final s = suggestNextChallenge(_result(
        improvement: Dimension.posture,
        exercise: Exercise.free,
        voiceTextTrusted: false,
        pausesTrusted: false,
        bodyHasData: true,
      ));
      expect(s.kind, isNot(SuggestionKind.diagnostic));
      expect(s.exercise.id, 'e-cuento');
    });
  });

  test('is total: every improvement dimension yields a real exercise', () {
    for (final dimension in Dimension.values) {
      final s = suggestNextChallenge(
        _result(improvement: dimension, exercise: Exercise.free),
      );
      expect(s.exercise.id, isNotEmpty);
      expect(ExerciseCatalog.byId(s.exercise.id), isNotNull);
    }
  });
}
