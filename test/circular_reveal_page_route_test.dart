import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/shared/animations/circular_reveal_page_route.dart';

void main() {
  group('CircularRevealClipper', () {
    test('calcula correctamente el radio máximo según el punto de toque', () {
      const size = Size(400, 800);
      const center = Offset(100, 200);

      // Distancia máxima es desde (100, 200) hasta la esquina opuesta (400, 800)
      // dx = 300, dy = 600 => sqrt(300^2 + 600^2) = sqrt(90000 + 360000) = sqrt(450000) ~ 670.82
      final maxRadius = CircularRevealClipper.calcMaxRadius(size, center);
      final expected = sqrt(300 * 300 + 600 * 600);
      expect(maxRadius, equals(expected));
    });

    test('genera un Path oval circular proporcional a la fracción', () {
      const size = Size(300, 600);
      const center = Offset(150, 300);
      final clipper = CircularRevealClipper(fraction: 0.5, center: center);

      final path = clipper.getClip(size);
      expect(path, isA<Path>());
      
      final maxRadius = CircularRevealClipper.calcMaxRadius(size, center);
      final bounds = path.getBounds();
      expect(bounds.center.dx, closeTo(center.dx, 0.001));
      expect(bounds.center.dy, closeTo(center.dy, 0.001));
      expect(bounds.width, closeTo(maxRadius * 0.5 * 2, 0.001));
    });

    test('shouldReclip responde adecuadamente a cambios de fracción o centro', () {
      final clipper1 = CircularRevealClipper(fraction: 0.5, center: const Offset(10, 10));
      final clipper2 = CircularRevealClipper(fraction: 0.5, center: const Offset(10, 10));
      final clipper3 = CircularRevealClipper(fraction: 0.8, center: const Offset(10, 10));
      final clipper4 = CircularRevealClipper(fraction: 0.5, center: const Offset(20, 20));

      expect(clipper1.shouldReclip(clipper2), isFalse);
      expect(clipper1.shouldReclip(clipper3), isTrue);
      expect(clipper1.shouldReclip(clipper4), isTrue);
    });
  });

  group('CircularRevealPageRoute', () {
    testWidgets('realiza la navegación y animación sin lanzar excepciones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      CircularRevealPageRoute(
                        center: const Offset(100, 100),
                        page: const Scaffold(
                          body: Text('Detalle de prueba'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Detalle de prueba'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Detalle de prueba'), findsOneWidget);
    });
  });
}
