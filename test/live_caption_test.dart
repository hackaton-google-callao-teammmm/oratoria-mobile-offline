import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/presentation/practice/widgets/live_caption.dart';

Future<void> _pump(WidgetTester tester, String text) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: LiveCaption(text: text)))),
  );
}

void main() {
  testWidgets('shows nothing when there is no text yet', (tester) async {
    await _pump(tester, '');
    expect(find.textContaining('EN VIVO'), findsNothing);
    await _pump(tester, '   ');
    expect(find.textContaining('EN VIVO'), findsNothing);
  });

  testWidgets('renders the partial words with a subtle "en vivo" marker',
      (tester) async {
    await _pump(tester, 'hola me llamo ana');
    expect(find.text('hola me llamo ana'), findsOneWidget);
    expect(find.textContaining('EN VIVO'), findsOneWidget);
  });
}
