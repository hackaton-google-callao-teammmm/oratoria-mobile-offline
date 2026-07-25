/// Which engine wrote the prose.
///
/// Persisted on every result so the UI can be honest and, more importantly,
/// so a progress chart never plots a template-scored run against an
/// LLM-scored one as if they were the same measurement.
enum FeedbackSource {
  /// Gemma running on this device.
  onDeviceLlm,

  /// A larger model on a LAN host (classroom PC).
  remoteLlm,

  /// Deterministic templates. Always available, never fails.
  ruleBased,
}

/// The dimension a piece of feedback is about. Kept as an enum rather than a
/// string so the UI can pick an icon and the coach can be exhaustively tested.
enum Dimension {
  pace,
  fillers,
  pauses,
  eyeContact,
  posture,
  expression;

  /// Child-facing label, Spanish. Lives here so every adapter — templates,
  /// Gemma, remote — names the dimension identically.
  String get label => switch (this) {
        Dimension.pace => 'ritmo',
        Dimension.fillers => 'muletillas',
        Dimension.pauses => 'pausas',
        Dimension.eyeContact => 'mirada',
        Dimension.posture => 'postura',
        Dimension.expression => 'expresión',
      };
}

/// Exactly one strength and one improvement — the cognitive-load rule from the
/// design doc. Adding a third field here is a product decision, not a
/// refactor: resist it.
class CoachFeedback {
  final Dimension strengthDimension;
  final String strengthTitle;
  final String strengthBody;

  final Dimension improvementDimension;
  final String improvementTitle;
  final String improvementBody;

  /// Null when the exercise declared no target skill.
  final bool? goalMet;

  /// Verdict on the exercise's own objective, e.g.
  /// "El objetivo era hablar despacio — ¡lo lograste!".
  final String? goalMessage;

  final FeedbackSource source;

  const CoachFeedback({
    required this.strengthDimension,
    required this.strengthTitle,
    required this.strengthBody,
    required this.improvementDimension,
    required this.improvementTitle,
    required this.improvementBody,
    required this.source,
    this.goalMet,
    this.goalMessage,
  });

  CoachFeedback copyWith({FeedbackSource? source}) => CoachFeedback(
        strengthDimension: strengthDimension,
        strengthTitle: strengthTitle,
        strengthBody: strengthBody,
        improvementDimension: improvementDimension,
        improvementTitle: improvementTitle,
        improvementBody: improvementBody,
        source: source ?? this.source,
        goalMet: goalMet,
        goalMessage: goalMessage,
      );
}
