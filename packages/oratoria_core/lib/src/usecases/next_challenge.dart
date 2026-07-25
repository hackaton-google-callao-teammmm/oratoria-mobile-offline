import '../entities/coach_feedback.dart';
import '../entities/exercise.dart';
import '../entities/exercise_catalog.dart';
import '../entities/practice_result.dart';

/// How the next challenge relates to the run that was just finished — drives the
/// copy the UI shows, never a different exercise.
enum SuggestionKind {
  /// The exercise trains exactly the weak skill (targetSkill == dimension).
  causal,

  /// Same as [causal] but the recommended exercise is the one just done — keep
  /// drilling the top weakness (spaced repetition), reworded so it reads as
  /// deliberate coaching, not a loop.
  reinforce,

  /// The weak dimension has no dedicated exercise (pauses); the closest reto
  /// only *helps* with it — the copy must say so, not claim it's designed for it.
  proxy,

  /// No confident weakness was measured (too short / untrusted audio / no
  /// face) — a warm default to produce a clean signal, with no invented cause.
  diagnostic,
}

/// The next reto to recommend on the report, and why.
class ChallengeSuggestion {
  final Exercise exercise;
  final SuggestionKind kind;

  /// The weak dimension the suggestion is for — null for [diagnostic], where
  /// nothing was measured with confidence.
  final Dimension? forDimension;

  const ChallengeSuggestion({
    required this.exercise,
    required this.kind,
    this.forDimension,
  });
}

/// Picks the next challenge from the just-finished run's weakest *trusted*
/// dimension. Pure and total: every [PracticeResult] yields a real exercise.
///
/// The gate for "there is a confident weakness" is deliberately the SAME
/// condition the report uses to show "Tus números": a recommendation appears if
/// and only if we measured something real, so it never routes on an invented
/// weakness (the project's golden rule, reused without a line of new logic).
ChallengeSuggestion suggestNextChallenge(PracticeResult result) {
  final measured = (result.voiceTextTrusted && result.voice.isMeaningful) ||
      result.pausesTrusted ||
      result.body.hasData;

  if (!measured) {
    return ChallengeSuggestion(
      exercise: ExerciseCatalog.byId('e-presentate')!,
      kind: SuggestionKind.diagnostic,
    );
  }

  final weak = result.feedback.improvementDimension;
  final (exercise, isProxy) = _exerciseFor(weak);
  final repeat = exercise.id == result.exercise.id;

  return ChallengeSuggestion(
    exercise: exercise,
    kind: repeat
        ? SuggestionKind.reinforce
        : (isProxy ? SuggestionKind.proxy : SuggestionKind.causal),
    forDimension: weak,
  );
}

/// Maps a weak dimension to the exercise that trains it. Exhaustive over
/// [Dimension] — the compiler guarantees no dead branch. The bool is true when
/// the match is a proxy (no exercise declares that targetSkill).
(Exercise, bool) _exerciseFor(Dimension dimension) => switch (dimension) {
      Dimension.pace => (ExerciseCatalog.byId('e-presentate')!, false),
      Dimension.fillers => (ExerciseCatalog.byId('e-animal')!, false),
      Dimension.eyeContact => (ExerciseCatalog.byId('e-pitch')!, false),
      Dimension.posture => (ExerciseCatalog.byId('e-cuento')!, false),
      // Storytelling naturally exercises flow/pacing — the closest thing to a
      // "pauses" reto, but only a proxy (no exercise targets pauses).
      Dimension.pauses => (ExerciseCatalog.byId('e-cuento')!, true),
      // Never actually scored as an improvement dimension; mapped defensively
      // so the function stays total.
      Dimension.expression => (ExerciseCatalog.byId('e-cuento')!, true),
    };
