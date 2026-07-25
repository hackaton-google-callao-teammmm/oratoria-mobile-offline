import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
}
