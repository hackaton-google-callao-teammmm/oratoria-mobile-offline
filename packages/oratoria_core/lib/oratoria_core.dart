/// Pure Dart core for OratorIA Kids.
///
/// Contains every rule that produces value — filler detection, pace, scoring
/// and the deterministic coach — with **no dependency on Flutter, on any AI
/// SDK, or on I/O**. That is deliberate: this package is testable with
/// `dart test` in milliseconds, and it guarantees the app still coaches a
/// child when there is no model, no camera and no network.
library;

export 'src/analysis/paraverbal_analyzer.dart';
export 'src/analysis/scoring.dart';
export 'src/analysis/spanish_fillers.dart';
export 'src/coach/profile_updater.dart';
export 'src/coach/rule_based_coach.dart';
export 'src/entities/body_metrics.dart';
export 'src/entities/coach_feedback.dart';
export 'src/entities/exercise.dart';
export 'src/entities/exercise_catalog.dart';
export 'src/entities/paraverbal_metrics.dart';
export 'src/entities/practice_result.dart';
export 'src/ports/ports.dart';
export 'src/usecases/evaluate_practice.dart';
export 'src/usecases/next_challenge.dart';
