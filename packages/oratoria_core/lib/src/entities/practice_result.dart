import 'body_metrics.dart';
import 'coach_feedback.dart';
import 'exercise.dart';
import 'paraverbal_metrics.dart';

/// Everything produced by one practice run — what gets persisted and rendered.
///
/// The raw [score] is stored but never shown: a number invites a child to
/// compare themselves with the kid at the next desk. The UI renders [stars]
/// and [levelLabel].
class PracticeResult {
  final Exercise exercise;
  final ParaverbalMetrics voice;
  final BodyMetrics body;
  final CoachFeedback feedback;

  /// Internal 0..100. Kept for progress tracking, never displayed raw.
  final int score;

  /// 1..5, derived from [score].
  final int stars;

  /// Child-facing level, e.g. "Buen despegue".
  final String levelLabel;

  /// False when the transcript was the sample fallback, not real STT. The
  /// report must then hide the word-derived metrics (pace, fillers) instead of
  /// presenting placeholder numbers as if the child had produced them.
  final bool voiceTextTrusted;

  /// False when pauses were not measured from the audio. The report hides the
  /// pauses metric rather than showing a hardcoded value.
  final bool pausesTrusted;

  /// The exact words the STT heard. Shown on the report as "Lo que escuché" —
  /// but only when [voiceTextTrusted], so the sample fallback is never passed
  /// off as the child's real speech. Transient: never persisted to disk (the
  /// audio and its transcript are discarded after the run).
  final String transcript;

  const PracticeResult({
    required this.exercise,
    required this.voice,
    required this.body,
    required this.feedback,
    required this.score,
    required this.stars,
    required this.levelLabel,
    this.voiceTextTrusted = true,
    this.pausesTrusted = true,
    this.transcript = '',
  });

  /// Where the prose came from — convenience for the UI badge.
  FeedbackSource get source => feedback.source;
}
