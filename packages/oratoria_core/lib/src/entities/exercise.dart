/// The skill an exercise is training.
///
/// Declaring a target lets the report say "el objetivo era hablar despacio —
/// ¡lo lograste!" instead of generic praise. Feedback about the thing the
/// child was *asked* to do lands; feedback about everything else scatters.
enum TargetSkill {
  /// Speak at a calm, followable pace.
  pace,

  /// Replace fillers with silence.
  fillers,

  /// Look at the audience.
  eyeContact,

  /// Stand tall and open.
  posture,

  /// Free practice — no single target, evaluate everything.
  none,
}

/// A practice prompt. Seeded from a bundled asset; never user-generated.
class Exercise {
  final String id;

  /// Shown as the card title, e.g. "Mi animal favorito".
  final String title;

  /// The instruction read to the child, e.g. "Cuéntanos de tu animal favorito".
  final String prompt;

  /// Suggested speaking time. Not a hard stop — a child cut off mid-sentence
  /// learns that the app is impatient, not that they were long-winded.
  final Duration targetDuration;

  final TargetSkill targetSkill;

  /// One short line of coaching shown before recording, e.g.
  /// "Cuando dudes, respira en vez de decir 'este'".
  final String targetHint;

  const Exercise({
    required this.id,
    required this.title,
    required this.prompt,
    required this.targetDuration,
    required this.targetSkill,
    required this.targetHint,
  });

  /// Fallback used when practice starts without a chosen exercise.
  static const free = Exercise(
    id: 'e-libre',
    title: 'Práctica libre',
    prompt: 'Habla de lo que quieras',
    targetDuration: Duration(seconds: 90),
    targetSkill: TargetSkill.none,
    targetHint: 'Habla con calma y mira al frente.',
  );
}
