import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oratoria_kids/app/theme/tokens.dart';
import 'package:oratoria_kids/shared/characters/vox.dart';

/// Golden previews of the robot-parrot Vox: every [VoxMood] in both themes.
/// They double as the visual spec for the mascot — if a refactor moves a
/// feather, these fail. Regenerate after an intentional art change with:
///
///   flutter test test/vox_golden_test.dart --update-goldens
Widget _stage(VoxMood mood, Brightness brightness) {
  final t = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness),
    home: Center(
      child: RepaintBoundary(
        key: const ValueKey('vox-stage'),
        child: Container(
          color: t.stage,
          padding: const EdgeInsets.all(16),
          child: Vox(mood: mood, size: 224),
        ),
      ),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark ? 'dark' : 'light';
    for (final mood in VoxMood.values) {
      testWidgets('Vox ${mood.name} ($theme)', (tester) async {
        await tester.pumpWidget(_stage(mood, brightness));
        // Advance the 2 s loop to a mid-cycle frame: wings mid-wave, bars up,
        // eyes open (the blink window is elsewhere in the cycle).
        await tester.pump(const Duration(milliseconds: 700));
        await expectLater(
          find.byKey(const ValueKey('vox-stage')),
          matchesGoldenFile('goldens/vox_${mood.name}_$theme.png'),
        );
      });
    }
  }
}
