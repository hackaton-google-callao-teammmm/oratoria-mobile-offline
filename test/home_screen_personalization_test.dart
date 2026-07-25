import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:oratoria_kids/presentation/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = Profile(id: 'p1', name: 'Ana', avatarKey: '🦊');

Future<void> _pump(WidgetTester tester, LocalStore store) async {
  tester.view.physicalSize = const Size(1400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(profile: _profile, store: store)),
  );
  await tester.pump(const Duration(seconds: 1)); // aurora animates forever
}

void main() {
  testWidgets('shows the original catalog when nothing was personalized',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());

    await _pump(tester, store);

    expect(find.text('Mi animal favorito'), findsOneWidget);
    expect(find.text('Cuéntanos de tu animal favorito'), findsOneWidget);
  });

  testWidgets('overlays a personalized title/prompt/hint by id',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.savePersonalizedExercise(
      _profile.id,
      'e-animal',
      const PersonalizedExercise(
        title: '¡Cuéntanos de tu T-Rex favorito!',
        prompt: 'Cuéntanos de tu dinosaurio favorito',
        hint: 'Respira antes de decir este.',
      ),
    );

    await _pump(tester, store);

    expect(find.text('¡Cuéntanos de tu T-Rex favorito!'), findsOneWidget);
    expect(find.text('Cuéntanos de tu dinosaurio favorito'), findsOneWidget);
    // The original text for that exercise is gone, replaced, not duplicated.
    expect(find.text('Mi animal favorito'), findsNothing);
    // Every other exercise (e.g. Preséntate) stays untouched.
    expect(find.text('Preséntate'), findsOneWidget);
  });

  testWidgets('an override for an unknown id is simply ignored', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.savePersonalizedExercise(
      _profile.id,
      'e-does-not-exist',
      const PersonalizedExercise(title: 'X', prompt: 'Y', hint: 'Z'),
    );

    await _pump(tester, store);

    expect(find.text('Mi animal favorito'), findsOneWidget);
    expect(find.text('X'), findsNothing);
  });
}
