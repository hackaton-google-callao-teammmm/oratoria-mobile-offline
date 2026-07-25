import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';

/// Clipper circular para animaciones de revelado desde un punto focal dinámico.
class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;

  CircularRevealClipper({
    required this.fraction,
    required this.center,
  });

  @override
  Path getClip(Size size) {
    final maxRadius = calcMaxRadius(size, center);
    final currentRadius = maxRadius * fraction;

    return Path()
      ..addOval(
        Rect.fromCircle(
          center: center,
          radius: currentRadius,
        ),
      );
  }

  /// Calcula la distancia máxima desde el centro focal hasta la esquina más lejana.
  static double calcMaxRadius(Size size, Offset center) {
    final w = max(center.dx, size.width - center.dx);
    final h = max(center.dy, size.height - center.dy);
    return sqrt(w * w + h * h);
  }

  @override
  bool shouldReclip(CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction || oldClipper.center != center;
  }
}

/// Pintador del anillo perimetral en verde lime para destacar visualmente el contorno expansivo.
class _CircularRevealRingPainter extends CustomPainter {
  final double fraction;
  final Offset center;
  final Color color;

  _CircularRevealRingPainter({
    required this.fraction,
    required this.center,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0.001 || fraction >= 0.999) return;

    final maxRadius = CircularRevealClipper.calcMaxRadius(size, center);
    final radius = maxRadius * fraction;
    final alphaFade = (1.0 - fraction * 0.3).clamp(0.0, 1.0);

    // Resplandor exterior (Glow halo en verde lime del token)
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.40 * alphaFade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawCircle(center, radius, glowPaint);

    // Anillo nítido de borde expansivo
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.95 * alphaFade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(_CircularRevealRingPainter old) =>
      old.fraction != fraction || old.center != center || old.color != color;
}

/// Ruta de página personalizada que anima la transición con un revelado circular expansivo
/// resaltado por un anillo luminoso en verde lime.
class CircularRevealPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset center;

  CircularRevealPageRoute({
    required this.page,
    required this.center,
    super.settings,
    super.transitionDuration = const Duration(milliseconds: 450),
    super.reverseTransitionDuration = const Duration(milliseconds: 400),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.easeInCubic,
            );

            return AnimatedBuilder(
              animation: curvedAnimation,
              builder: (context, child) {
                final fraction = curvedAnimation.value;
                final tokens = AppTokens.of(context);

                return CustomPaint(
                  foregroundPainter: fraction < 0.999
                      ? _CircularRevealRingPainter(
                          fraction: fraction,
                          center: center,
                          color: tokens.lime,
                        )
                      : null,
                  child: ClipPath(
                    clipper: CircularRevealClipper(
                      fraction: fraction,
                      center: center,
                    ),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
        );
}
