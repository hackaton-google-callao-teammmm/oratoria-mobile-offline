import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// What Vox is doing right now. Drives the face and the little animation.
enum VoxMood {
  /// Warm, welcoming — the splash and the hub.
  greeting,

  /// "Thinking" — masks Gemma's 2–6 s latency after the child finishes. The
  /// audience pausing before it asks a question reads as natural, not a bug.
  thinking,

  /// Delivering the report / talking.
  speaking,

  /// Calm resting state.
  idle,
}

/// "Vox" — the coach mascot that guides every screen. Placeholder art built
/// from [CustomPaint] (no image assets) so it ships today; the shape is a
/// friendly rounded blob with eyes, echoing the OratorIA isotype's spirit
/// without needing the illustrated character yet.
class Vox extends StatefulWidget {
  final VoxMood mood;
  final double size;

  const Vox({super.key, this.mood = VoxMood.idle, this.size = 96});

  @override
  State<Vox> createState() => _VoxState();
}

class _VoxState extends State<Vox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
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
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _VoxPainter(
          mood: widget.mood,
          tick: _c.value,
          accent: t.accent,
          onAccent: t.onLime,
          ink: t.ink,
          surface: t.surface,
        ),
      ),
    );
  }
}

class _VoxPainter extends CustomPainter {
  final VoxMood mood;
  final double tick; // 0..1 loop
  final Color accent;
  final Color onAccent;
  final Color ink;
  final Color surface;

  _VoxPainter({
    required this.mood,
    required this.tick,
    required this.accent,
    required this.onAccent,
    required this.ink,
    required this.surface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;
    final breathe = math.sin(tick * 2 * math.pi) * size.width * 0.015;

    // Body — a soft rounded square (superellipse feel). A subtle top-lit
    // gradient gives it dimension instead of a flat fill.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCircle(center: c, radius: r + breathe),
      Radius.circular(r * 0.7),
    );
    final bodyRectPlain = Rect.fromCircle(center: c, radius: r + breathe);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(accent, Colors.white, 0.14)!,
          accent,
          Color.lerp(accent, Colors.black, 0.10)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bodyRectPlain);
    // Soft drop shadow for lift.
    canvas.drawRRect(
      bodyRect.shift(Offset(0, r * 0.06)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    // Glossy highlight arc near the top.
    canvas.drawArc(
      Rect.fromCircle(center: c - Offset(0, r * 0.1), radius: r * 0.72),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    switch (mood) {
      case VoxMood.thinking:
        _thinkingFace(canvas, c, r);
      case VoxMood.speaking:
        _speakingFace(canvas, c, r);
      case VoxMood.greeting:
        _happyFace(canvas, c, r, big: true);
      case VoxMood.idle:
        _happyFace(canvas, c, r, big: false);
    }
  }

  Paint get _eye => Paint()..color = onAccent;

  void _happyFace(Canvas canvas, Offset c, double r, {required bool big}) {
    final dx = r * 0.34;
    final dy = -r * 0.12;
    final blink = (math.sin(tick * 2 * math.pi) > 0.95) ? 0.3 : 1.0;
    canvas.drawOval(
      Rect.fromCenter(
          center: c + Offset(-dx, dy), width: r * 0.24, height: r * 0.24 * blink),
      _eye,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: c + Offset(dx, dy), width: r * 0.24, height: r * 0.24 * blink),
      _eye,
    );
    // Smile
    final mouth = Path();
    final mw = r * (big ? 0.5 : 0.38);
    final my = c.dy + r * 0.32;
    mouth.moveTo(c.dx - mw, my);
    mouth.quadraticBezierTo(c.dx, my + r * (big ? 0.5 : 0.34), c.dx + mw, my);
    canvas.drawPath(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.13
        ..strokeCap = StrokeCap.round
        ..color = onAccent,
    );
  }

  void _speakingFace(Canvas canvas, Offset c, double r) {
    final dx = r * 0.34;
    final dy = -r * 0.12;
    canvas.drawCircle(c + Offset(-dx, dy), r * 0.12, _eye);
    canvas.drawCircle(c + Offset(dx, dy), r * 0.12, _eye);
    // Open, animated mouth (talking).
    final open = (0.6 + 0.4 * math.sin(tick * 2 * math.pi * 3)).abs();
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, r * 0.36),
        width: r * 0.42,
        height: r * 0.3 * open,
      ),
      Paint()..color = onAccent,
    );
  }

  void _thinkingFace(Canvas canvas, Offset c, double r) {
    final dx = r * 0.34;
    final dy = -r * 0.12;
    // Eyes glance up while thinking.
    canvas.drawCircle(c + Offset(-dx, dy - r * 0.06), r * 0.11, _eye);
    canvas.drawCircle(c + Offset(dx, dy - r * 0.06), r * 0.11, _eye);
    // Flat, small mouth.
    canvas.drawLine(
      c + Offset(-r * 0.18, r * 0.34),
      c + Offset(r * 0.18, r * 0.34),
      Paint()
        ..strokeWidth = r * 0.1
        ..strokeCap = StrokeCap.round
        ..color = onAccent,
    );
    // Three thinking dots that pulse in sequence, above Vox.
    for (var i = 0; i < 3; i++) {
      final t = (tick * 3 - i) % 1.0;
      final a = (math.sin(t * math.pi)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(c.dx + (i - 1) * r * 0.4, c.dy - r * 1.25),
        r * 0.1,
        Paint()..color = accent.withValues(alpha: 0.35 + a * 0.65),
      );
    }
  }

  @override
  bool shouldRepaint(_VoxPainter old) => old.tick != tick || old.mood != mood;
}
