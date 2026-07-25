import 'local_store.dart';

/// A voice dimension that gets a persisted history to compare against — see
/// `progress-impact-indicators`. Body dimensions (eye contact/posture) are
/// deliberately not tracked here (design.md).
enum ImpactDimension { pace, fillers }

/// One honest comparison: this practice's value for [dimension] against the
/// nearest older confiable value in the history.
class ProgressImpact {
  final ImpactDimension dimension;
  final double previous;
  final double current;

  const ProgressImpact({
    required this.dimension,
    required this.previous,
    required this.current,
  });
}

/// Compares `history[index]` against the nearest OLDER entry (scanning
/// `history` from `index + 1` onward) that has a confiable value for each
/// dimension — never a promedio, never an invented trend. `history` is
/// expected sorted newest-first, exactly like `LocalStore.resultsFor`
/// returns it. Works from any index, not just 0, so `ReportScreen` (index 0,
/// the just-finished practice) and `ProgressScreen` (any past entry) share
/// this exact function.
List<ProgressImpact> compareToPrevious(List<SavedResult> history, int index) {
  if (index < 0 || index >= history.length) return const [];
  final current = history[index];
  final impacts = <ProgressImpact>[];

  double? previousWpm;
  double? previousFillerRate;
  for (var i = index + 1; i < history.length; i++) {
    previousWpm ??= history[i].wordsPerMinute;
    previousFillerRate ??= history[i].fillerRate;
    if (previousWpm != null && previousFillerRate != null) break;
  }

  if (current.wordsPerMinute != null && previousWpm != null) {
    impacts.add(ProgressImpact(
      dimension: ImpactDimension.pace,
      previous: previousWpm,
      current: current.wordsPerMinute!,
    ));
  }
  if (current.fillerRate != null && previousFillerRate != null) {
    impacts.add(ProgressImpact(
      dimension: ImpactDimension.fillers,
      previous: previousFillerRate,
      current: current.fillerRate!,
    ));
  }
  return impacts;
}

String _impactLabel(ImpactDimension d) => switch (d) {
      ImpactDimension.pace => 'Ritmo',
      ImpactDimension.fillers => 'Muletillas',
    };

/// Neutral, factual phrasing shared by `ReportScreen` and `ProgressScreen` —
/// deliberately no "you improved!" framing (see `ImpactDimension` doc).
String describeImpact(ProgressImpact i) =>
    '${_impactLabel(i.dimension)}: pasaste de ${i.previous.round()} a '
    '${i.current.round()}';
