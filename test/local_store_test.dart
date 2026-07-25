import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('SavedResult round-trips wordsPerMinute and fillerRate', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.saveResult(
      'p1',
      const SavedResult(
        exerciseId: 'e-animal',
        score: 85,
        stars: 4,
        atMillis: 100,
        wordsPerMinute: 118,
        fillerRate: 3.5,
      ),
    );

    final saved = store.resultsFor('p1').single;
    expect(saved.wordsPerMinute, 118);
    expect(saved.fillerRate, 3.5);
  });

  test('SavedResult defaults wordsPerMinute/fillerRate to null when omitted',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.saveResult(
      'p1',
      const SavedResult(exerciseId: 'e-animal', score: 85, stars: 4, atMillis: 100),
    );

    final saved = store.resultsFor('p1').single;
    expect(saved.wordsPerMinute, isNull);
    expect(saved.fillerRate, isNull);
  });

  test('SavedResult.fromJson tolerates old records missing the new fields',
      () async {
    // Simulates a practice saved before this change shipped — no 'wpm'/'fr'
    // keys at all in the persisted JSON.
    final old = SavedResult.fromJson(
      jsonDecode('{"e":"e-animal","s":80,"st":4,"t":50}') as Map<String, dynamic>,
    );

    expect(old.wordsPerMinute, isNull);
    expect(old.fillerRate, isNull);
    expect(old.exerciseId, 'e-animal');
  });

  test('updateProfile changes name/avatar but keeps the same id', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final created = await store.addProfile(
      id: 'p1',
      name: 'Ana',
      avatarKey: '🦊',
    );

    await store.updateProfile(
      id: created.id,
      name: 'Anita',
      avatarKey: '🐱',
    );

    final profiles = store.profiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.id, 'p1');
    expect(profiles.single.name, 'Anita');
    expect(profiles.single.avatarKey, '🐱');
  });

  test('deleteProfile removes the profile and its saved results', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final created = await store.addProfile(
      id: 'p1',
      name: 'Ana',
      avatarKey: '🦊',
    );
    await store.saveResult(
      created.id,
      const SavedResult(exerciseId: 'e1', score: 80, stars: 2, atMillis: 1),
    );

    await store.deleteProfile(created.id);

    expect(store.profiles(), isEmpty);
    expect(store.resultsFor(created.id), isEmpty);
  });

  test('saveAiProfile and getAiProfile manage AI profile json', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());

    expect(store.getAiProfile('p1'), isNull);

    const sampleJson = '{"interests":["dinosaurs"],"strengths":["loud voice"]}';
    await store.saveAiProfile('p1', sampleJson);

    expect(store.getAiProfile('p1'), sampleJson);

    await store.deleteProfile('p1');
    expect(store.getAiProfile('p1'), isNull);
  });

  test('getPersonalizedExercise returns null when nothing was saved',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());

    expect(store.getPersonalizedExercise('p1', 'e-animal'), isNull);
  });

  test('savePersonalizedExercise persists and round-trips one override',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    const override = PersonalizedExercise(
      title: '¡Cuéntanos de tu T-Rex favorito!',
      prompt: 'Cuéntanos de tu dinosaurio favorito',
      hint: 'Cuando dudes, respira en vez de decir "este".',
    );

    await store.savePersonalizedExercise('p1', 'e-animal', override);

    // New instance over the same prefs — real persistence, not in-memory state.
    final reopened = LocalStore(await SharedPreferences.getInstance());
    final saved = reopened.getPersonalizedExercise('p1', 'e-animal');
    expect(saved?.title, override.title);
    expect(saved?.prompt, override.prompt);
    expect(saved?.hint, override.hint);
  });

  test('savePersonalizedExercise upserts without touching other entries',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    const first = PersonalizedExercise(
      title: 'A', prompt: 'a', hint: 'a-hint',
    );
    const second = PersonalizedExercise(
      title: 'B', prompt: 'b', hint: 'b-hint',
    );

    await store.savePersonalizedExercise('p1', 'e-animal', first);
    await store.savePersonalizedExercise('p1', 'e-pitch', second);

    final all = store.getAllPersonalizedExercises('p1');
    expect(all, hasLength(2));
    expect(all['e-animal']?.title, 'A');
    expect(all['e-pitch']?.title, 'B');
  });

  test('getAllPersonalizedExercises is empty when nothing was saved',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());

    expect(store.getAllPersonalizedExercises('p1'), isEmpty);
  });

  test('deleteProfile also clears personalized exercises', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.savePersonalizedExercise(
      'p1',
      'e-animal',
      const PersonalizedExercise(title: 'A', prompt: 'a', hint: 'a-hint'),
    );

    await store.deleteProfile('p1');

    expect(store.getPersonalizedExercise('p1', 'e-animal'), isNull);
    expect(store.getAllPersonalizedExercises('p1'), isEmpty);
  });
}
