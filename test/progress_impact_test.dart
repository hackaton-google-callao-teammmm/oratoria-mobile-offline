import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:oratoria_kids/data/progress_impact.dart';

SavedResult _r({
  required int atMillis,
  double? wpm,
  double? fillerRate,
}) =>
    SavedResult(
      exerciseId: 'e-animal',
      score: 80,
      stars: 4,
      atMillis: atMillis,
      wordsPerMinute: wpm,
      fillerRate: fillerRate,
    );

void main() {
  group('compareToPrevious', () {
    test('no comparison when there is no older confiable entry', () {
      final history = [_r(atMillis: 200, wpm: 118, fillerRate: 3)];

      expect(compareToPrevious(history, 0), isEmpty);
    });

    test('compares pace and fillers against the immediately older entry',
        () {
      final history = [
        _r(atMillis: 200, wpm: 118, fillerRate: 3), // current
        _r(atMillis: 100, wpm: 95, fillerRate: 6), // previous
      ];

      final impacts = compareToPrevious(history, 0);

      expect(impacts, hasLength(2));
      final pace =
          impacts.firstWhere((i) => i.dimension == ImpactDimension.pace);
      expect(pace.previous, 95);
      expect(pace.current, 118);
      final fillers =
          impacts.firstWhere((i) => i.dimension == ImpactDimension.fillers);
      expect(fillers.previous, 6);
      expect(fillers.current, 3);
    });

    test('skips non-confiable entries to find the nearest real one', () {
      final history = [
        _r(atMillis: 300, wpm: 120, fillerRate: 2), // current
        _r(atMillis: 200, wpm: null, fillerRate: null), // untrusted run
        _r(atMillis: 100, wpm: 90, fillerRate: 8), // last confiable
      ];

      final impacts = compareToPrevious(history, 0);

      final pace =
          impacts.firstWhere((i) => i.dimension == ImpactDimension.pace);
      expect(pace.previous, 90);
    });

    test('only compares dimensions the current entry actually has', () {
      final history = [
        _r(atMillis: 200, wpm: 118, fillerRate: null), // current: no fillers
        _r(atMillis: 100, wpm: 95, fillerRate: 6),
      ];

      final impacts = compareToPrevious(history, 0);

      expect(impacts, hasLength(1));
      expect(impacts.single.dimension, ImpactDimension.pace);
    });

    test('works from any index, not just the newest (for ProgressScreen)',
        () {
      final history = [
        _r(atMillis: 300, wpm: 130, fillerRate: 1),
        _r(atMillis: 200, wpm: 118, fillerRate: 3), // compare THIS one
        _r(atMillis: 100, wpm: 95, fillerRate: 6),
      ];

      final impacts = compareToPrevious(history, 1);

      final pace =
          impacts.firstWhere((i) => i.dimension == ImpactDimension.pace);
      expect(pace.previous, 95);
      expect(pace.current, 118);
    });
  });
}
