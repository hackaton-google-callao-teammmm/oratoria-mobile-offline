import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_core/oratoria_core.dart';
import 'package:oratoria_kids/adapters/coach/exercise_personalizer.dart';

void main() {
  const exercise = Exercise(
    id: 'e-animal',
    title: 'Mi animal favorito',
    prompt: 'Cuéntanos de tu animal favorito',
    targetDuration: Duration(seconds: 45),
    targetSkill: TargetSkill.fillers,
    targetHint: 'Cuando dudes, respira en vez de decir "este".',
  );

  test('parses a strict JSON reply into a PersonalizedExercise', () async {
    final personalizer = ExercisePersonalizer(
      rewrite: (_) async =>
          '{"title":"¡Cuéntanos de tu T-Rex favorito!",'
          '"prompt":"Cuéntanos de tu dinosaurio favorito",'
          '"hint":"Respira antes de decir este."}',
    );

    final out = await personalizer.personalize(
      exercise,
      '{"interests":["dinosaurios"]}',
    );

    expect(out, isNotNull);
    expect(out!.title, contains('T-Rex'));
    expect(out.prompt, contains('dinosaurio'));
    expect(out.hint, isNotEmpty);
  });

  test('strips a ```json fence before parsing', () async {
    final personalizer = ExercisePersonalizer(
      rewrite: (_) async => '```json\n'
          '{"title":"T","prompt":"P","hint":"H"}\n'
          '```',
    );

    final out = await personalizer.personalize(exercise, '{"interests":[]}');

    expect(out?.title, 'T');
  });

  test('returns null when the rewrite returns null', () async {
    final personalizer = ExercisePersonalizer(rewrite: (_) async => null);

    final out = await personalizer.personalize(exercise, '{}');

    expect(out, isNull);
  });

  test('returns null instead of throwing when the rewrite throws', () async {
    final personalizer = ExercisePersonalizer(
      rewrite: (_) async => throw StateError('oom'),
    );

    final out = await personalizer.personalize(exercise, '{}');

    expect(out, isNull);
  });

  test('returns null for unparseable (non-JSON) text', () async {
    final personalizer = ExercisePersonalizer(
      rewrite: (_) async => 'claro, aquí tienes tu reto sobre dinosaurios',
    );

    final out = await personalizer.personalize(exercise, '{}');

    expect(out, isNull);
  });

  test('returns null when a required field is missing', () async {
    final personalizer = ExercisePersonalizer(
      rewrite: (_) async => '{"title":"T","prompt":"P"}',
    );

    final out = await personalizer.personalize(exercise, '{}');

    expect(out, isNull);
  });

  test('returns null when a field is empty', () async {
    final personalizer = ExercisePersonalizer(
      rewrite: (_) async => '{"title":"","prompt":"P","hint":"H"}',
    );

    final out = await personalizer.personalize(exercise, '{}');

    expect(out, isNull);
  });

  test('the prompt preserves the speech-act type per targetSkill', () async {
    String? capturedPrompt;
    final personalizer = ExercisePersonalizer(
      rewrite: (prompt) async {
        capturedPrompt = prompt;
        return null;
      },
    );

    await personalizer.personalize(exercise, '{}');

    // e-animal trains "fillers" via describing something — the prompt must
    // instruct Gemma to keep that act, not turn it into a different one.
    expect(capturedPrompt, contains('describir'));
  });
}
