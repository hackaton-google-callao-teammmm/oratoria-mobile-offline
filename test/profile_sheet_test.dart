import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:oratoria_kids/presentation/profiles/widgets/profile_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders empty state when no AI profile exists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    const profile = Profile(id: 'p1', name: 'Ana', avatarKey: '🦊');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSheet(
            profile: profile,
            store: store,
            onSwitchProfile: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('PERFIL DE ORATORIA'), findsOneWidget);
    expect(find.text('¡Aún estamos conociéndote!'), findsOneWidget);
  });

  testWidgets('renders parsed AI profile insights (interests, strengths, weaknesses)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    const profile = Profile(id: 'p1', name: 'Ana', avatarKey: '🦊');
    await store.saveAiProfile(
      'p1',
      '{"interests":["Dinosaurios","Espacio"],"strengths":["Voz firme"],"weaknesses":["Hablar más lento"]}',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSheet(
            profile: profile,
            store: store,
            onSwitchProfile: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Dinosaurios'), findsOneWidget);
    expect(find.text('Espacio'), findsOneWidget);
    expect(find.text('Voz firme'), findsOneWidget);
    expect(find.text('Hablar más lento'), findsOneWidget);
  });

  testWidgets('triggers onSwitchProfile when switch button is pressed',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    const profile = Profile(id: 'p1', name: 'Ana', avatarKey: '🦊');
    var switched = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSheet(
            profile: profile,
            store: store,
            onSwitchProfile: () => switched = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cambiar de perfil'));
    await tester.pump();

    expect(switched, isTrue);
  });
}
