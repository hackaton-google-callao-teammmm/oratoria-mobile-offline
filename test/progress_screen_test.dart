import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:oratoria_kids/presentation/progress/progress_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the empty state (never a blank canvas) with no results',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    const profile = Profile(id: 'p1', name: 'Ana', avatarKey: 'fox');

    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: ProgressScreen(profile: profile, store: store)),
    );
    await tester.pump(const Duration(seconds: 1)); // aurora animates forever

    // Header is always there...
    expect(find.text('Mi progreso'), findsOneWidget);
    // ...and the empty state renders content, not a blank screen.
    expect(find.textContaining('Aún no hay progreso'), findsOneWidget);
    expect(find.text('Empezar a practicar'), findsOneWidget);
  });

  testWidgets(
      'renders summary bento and practice results cleanly when history exists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    const profile = Profile(id: 'p1', name: 'Ana', avatarKey: 'fox');

    await store.saveResult(
      profile.id,
      SavedResult(
        exerciseId: 'articulacion',
        score: 85,
        stars: 4,
        atMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: ProgressScreen(profile: profile, store: store)),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Mi progreso'), findsOneWidget);
    expect(find.text('Estrellas ganadas'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Prácticas'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('TU EVOLUCIÓN'), findsOneWidget);
    expect(find.text('TUS PRÁCTICAS'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
  });
}



