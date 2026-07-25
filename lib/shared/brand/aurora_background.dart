import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Aurora mesh backdrop — the app's signature texture, ported from the web
/// (`components/reports/aurora-background.tsx`). Large soft colour blobs in the
/// brand palette drift slowly behind the content.
///
/// A12-safe by design: instead of a real Gaussian blur (expensive on the
/// Exynos 850 GPU), each blob is a [RadialGradient] that already fades to
/// transparent, so it *reads* as blurred with zero filter cost. Only a handful
/// of gradients repaint per frame, driven by one slow controller.
class AuroraBackground extends StatefulWidget {
  /// The content painted on top of the aurora.
  final Widget child;

  /// Dial the effect down on busy screens (0.0–1.0).
  final double intensity;

  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // One slow loop drives all blob drift — cheap, and calm enough for kids.
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  t: _c.value,
                  dark: dark,
                  stage: t.stage,
                  intensity: widget.intensity,
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t; // 0..1 loop
  final bool dark;
  final Color stage;
  final double intensity;

  _AuroraPainter({
    required this.t,
    required this.dark,
    required this.stage,
    required this.intensity,
  });

  // Brand palette blobs, matching the web (lime, teal, emerald, faint violet).
  static const _lime = Color(0xFFC6FF3D);
  static const _teal = Color(0xFF2DD4BF);
  static const _emerald = Color(0xFF34D399);
  static const _violet = Color(0xFFA78BFA);

  @override
  void paint(Canvas canvas, Size size) {
    // Base wash so blobs sit on the brand surface, not raw black/white.
    canvas.drawRect(Offset.zero & size, Paint()..color = stage);

    final w = size.width;
    final h = size.height;
    final r = math.max(w, h);
    final a = intensity * (dark ? 1.0 : 0.85);

    // Each blob drifts on its own slow phase.
    _blob(canvas, size, _lime, a * (dark ? 0.34 : 0.42),
        Offset(w * (0.12 + 0.06 * _s(0)), h * (-0.05 + 0.05 * _s(1))), r * 0.85);
    _blob(canvas, size, _teal, a * (dark ? 0.26 : 0.30),
        Offset(w * (0.92 + 0.05 * _s(2)), h * (0.10 + 0.06 * _s(3))), r * 0.78);
    _blob(canvas, size, _emerald, a * (dark ? 0.24 : 0.28),
        Offset(w * (0.30 + 0.08 * _s(4)), h * (0.42 + 0.05 * _s(1))), r * 0.80);
    _blob(canvas, size, _violet, a * (dark ? 0.20 : 0.18),
        Offset(w * (0.80 + 0.06 * _s(5)), h * (0.95 + 0.05 * _s(2))), r * 0.72);
  }

  /// Slow oscillation in [-1, 1] with a per-blob phase offset.
  double _s(int i) => math.sin(t * 2 * math.pi + i * 1.7);

  void _blob(
    Canvas canvas,
    Size size,
    Color color,
    double alpha,
    Offset center,
    double radius,
  ) {
    final shader = RadialGradient(
      colors: [
        color.withValues(alpha: alpha),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.7],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.dark != dark || old.intensity != intensity;
}
