import 'exercise.dart';

/// Seeded practice prompts. Bundled with the app, never fetched.
///
/// Kept in the core (not the database layer) so the domain and its tests can
/// reason about real exercises without spinning up SQLite.
abstract final class ExerciseCatalog {
  static const List<Exercise> all = [
    Exercise(
      id: 'e-presentate',
      title: 'Preséntate',
      prompt: 'Di tu nombre y qué te gusta hacer',
      targetDuration: Duration(seconds: 30),
      targetSkill: TargetSkill.pace,
      targetHint: 'Tómate tu tiempo. No hay apuro.',
    ),
    Exercise(
      id: 'e-animal',
      title: 'Mi animal favorito',
      prompt: 'Cuéntanos de tu animal favorito',
      targetDuration: Duration(seconds: 45),
      targetSkill: TargetSkill.fillers,
      targetHint: 'Cuando dudes, respira en vez de decir "este".',
    ),
    Exercise(
      id: 'e-pitch',
      title: 'Mi gran idea',
      prompt: 'Convéncenos de una idea en un minuto',
      targetDuration: Duration(seconds: 60),
      targetSkill: TargetSkill.eyeContact,
      targetHint: 'Busca un punto al fondo y cuéntaselo a ese punto.',
    ),
    Exercise(
      id: 'e-cuento',
      title: 'Cuenta un cuento',
      prompt: 'Cuéntanos un cuento corto',
      targetDuration: Duration(seconds: 60),
      targetSkill: TargetSkill.posture,
      targetHint: 'Planta los dos pies y sube el pecho antes de empezar.',
    ),
    Exercise.free,
  ];

  static Exercise? byId(String id) {
    for (final exercise in all) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }
}
