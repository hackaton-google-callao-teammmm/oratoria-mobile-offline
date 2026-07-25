import 'dart:convert';

import 'package:oratoria_core/oratoria_core.dart';

import '../../data/local_store.dart';
import 'gemma_coach.dart' show LlmRewrite;
import 'gemma_service.dart';

/// Rewrites ONE exercise's title/prompt/hint to reflect the child's AI
/// profile — never its `id`, `targetSkill` or `targetDuration`. Called for a
/// single [Exercise] at a time (the one `suggestNextChallenge()` just
/// recommended), never in bulk — see the `personalized-exercises` change.
///
/// Same contract as the rest of the Gemma adapters: never throws, returns
/// null on any failure/timeout/unparseable reply so the caller simply keeps
/// the exercise's original text.
class ExercisePersonalizer {
  final LlmRewrite _rewrite;

  const ExercisePersonalizer({required LlmRewrite rewrite}) : _rewrite = rewrite;

  /// Production wiring: same singleton Gemma model, same bounded timeout
  /// pattern as [GemmaCoach.gemma] and [AudienceQuestion].
  factory ExercisePersonalizer.gemma() => ExercisePersonalizer(
        rewrite: (prompt) => GemmaService.instance.ask(
          prompt,
          maxTokens: 180,
          timeout: const Duration(seconds: 10),
        ),
      );

  Future<PersonalizedExercise?> personalize(
    Exercise exercise,
    String? aiProfile,
  ) async {
    try {
      final raw = await _rewrite(_prompt(exercise, aiProfile));
      return _parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _prompt(Exercise exercise, String? aiProfile) =>
      'Eres Vox, un entrenador de oratoria cálido para niños. '
      'Este reto de práctica sirve para ${_actLabel(exercise.targetSkill)}.\n'
      'Título original: ${exercise.title}\n'
      'Consigna original: ${exercise.prompt}\n'
      'Perfil del niño en JSON: ${aiProfile ?? "{}"}\n\n'
      'Reescribe el título y la consigna usando los intereses o fortalezas '
      'del perfil como tema nuevo, pero SIN cambiar el tipo de consigna: '
      'debe seguir sirviendo para ${_actLabel(exercise.targetSkill)}. '
      'También reescribe el hint (un consejo breve de una frase) en el '
      'mismo tono cálido.\n'
      'Responde ÚNICAMENTE con un objeto JSON válido, sin markdown ni '
      'explicaciones, con este formato exacto: '
      '{"title":"","prompt":"","hint":""}';

  /// The speech-act each targetSkill trains — the one thing the rewrite must
  /// never change, only the topic. `TargetSkill.none` is never actually
  /// reached here: `e-libre` (the only exercise with that skill) is always
  /// excluded from personalization before this is called.
  String _actLabel(TargetSkill s) => switch (s) {
        TargetSkill.pace => 'presentarse a sí mismo',
        TargetSkill.fillers => 'describir algo con detalle',
        TargetSkill.eyeContact => 'defender o convencer sobre una idea',
        TargetSkill.posture => 'contar una historia corta',
        TargetSkill.none => 'hablar libremente',
      };

  PersonalizedExercise? _parse(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) return null;
      final title = decoded['title'];
      final prompt = decoded['prompt'];
      final hint = decoded['hint'];
      if (title is! String || prompt is! String || hint is! String) {
        return null;
      }
      if (title.trim().isEmpty || prompt.trim().isEmpty || hint.trim().isEmpty) {
        return null;
      }
      return PersonalizedExercise(
        title: title.trim(),
        prompt: prompt.trim(),
        hint: hint.trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
