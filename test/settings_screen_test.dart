import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/app/config/feature_flags.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:oratoria_kids/presentation/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders SettingsScreen with all feature flag tiles',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(store: store),
      ),
    );

    expect(find.text('Configuración'), findsOneWidget);
    expect(find.text('Subtítulos en vivo'), findsOneWidget);
    expect(find.text('Coach dinámico'), findsOneWidget);
    expect(find.text('Retos adaptativos'), findsOneWidget);
  });

  testWidgets('toggling a flag updates state in LocalStore', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());

    // liveCaption ships ON by default (motor-inferencia-presentacion) — no
    // override saved yet, so this reads the compile-time default.
    expect(FeatureFlags.isLiveCaption(store), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(store: store),
      ),
    );

    final switchFinder = find.byType(Switch).first;
    await tester.tap(switchFinder);
    await tester.pump();

    expect(FeatureFlags.isLiveCaption(store), isFalse);
  });
}
