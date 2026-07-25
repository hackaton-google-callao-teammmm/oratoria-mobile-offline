import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/data/local_store.dart';
import 'package:oratoria_kids/presentation/hub/widgets/playful_hold_header.dart';

void main() {
  testWidgets('renders avatar and profile name correctly', (tester) async {
    const profile = Profile(id: 'p1', name: 'Mateo', avatarKey: '🦁');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayfulHoldHeader(
            profile: profile,
            onTap: () {},
            onLongPressComplete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Mateo'), findsOneWidget);
    expect(find.text('🦁'), findsOneWidget);
  });

  testWidgets('triggers onTap on quick tap', (tester) async {
    const profile = Profile(id: 'p1', name: 'Mateo', avatarKey: '🦁');
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayfulHoldHeader(
            profile: profile,
            onTap: () => tapped = true,
            onLongPressComplete: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mateo'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('triggers onLongPressComplete after 500ms hold and jump animation',
      (tester) async {
    const profile = Profile(id: 'p1', name: 'Mateo', avatarKey: '🦁');
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayfulHoldHeader(
            profile: profile,
            onTap: () {},
            onLongPressComplete: () => completed = true,
          ),
        ),
      ),
    );

    // Press down and hold
    final gesture = await tester.startGesture(tester.getCenter(find.text('Mateo')));
    await tester.pump(const Duration(milliseconds: 600));

    // Jump animation runs (~900ms)
    await tester.pump(const Duration(milliseconds: 1000));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });
}
