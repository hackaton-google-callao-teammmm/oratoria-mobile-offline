import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// "La Banca" — the audience. A row of little faces that react, live, to how
/// energetically the child is speaking. This is the on-device stand-in for the
/// web's Tavus avatar: the audience *is* the live feedback, so no corrective
/// text ever appears while the child talks.
///
/// [energy] is 0..1 (typically mapped from mic amplitude): near 0 the faces
/// get distracted; near 1 they light up. Placeholder art on purpose — pure
/// [CustomPaint], no image assets — so it ships today and can be swapped for
/// illustrated characters later without touching callers.
class LaBanca extends StatefulWidget {
  /// 0 = silence/distracted, 1 = loud/excited. Smoothly animated internally.
  final double energy;
  final int faceCount;
  final double height;

  const LaBanca({
    super.key,
    required this.energy,
    this.faceCount = 5,
    this.height = 120,
  });

  @override
  State<LaBanca> createState() => _LaBancaState();
}

class _LaBancaState extends State<LaBanca> with SingleTickerProviderStateMixin {
  late final AnimationController _idle;
  // Smoothed energy so a spiky amplitude signal doesn't make faces jitter.
  double _shownEnergy = 0;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shownEnergy = widget.energy;
  }

  @override
  void didUpdateWidget(LaBanca old) {
    super.didUpdateWidget(old);
    // Ease toward the new energy — one low-pass step per frame-ish update.
    _shownEnergy += (widget.energy.clamp(0, 1) - _shownEnergy) * 0.35;
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return AnimatedBuilder(
      animation: _idle,
      builder: (context, _) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _BancaPainter(
          energy: _shownEnergy.clamp(0, 1),
          idle: _idle.value,
          faceCount: widget.faceCount,
          accent: t.accent,
          faceFill: t.surface2,
          ink: t.ink,
          inkFaint: t.inkFaint,
        ),
      ),
    );
  }
}

class _BancaPainter extends CustomPainter {
  final double energy; // 0..1
  final double idle; // 0..1 loop
  final int faceCount;
  final Color accent;
  final Color faceFill;
  final Color ink;
  final Color inkFaint;

  _BancaPainter({
    required this.energy,
    required this.idle,
    required this.faceCount,
    required this.accent,
    required this.faceFill,
    required this.ink,
    required this.inkFaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / faceCount;
    final r = math.min(slot, size.height) * 0.32;

    for (var i = 0; i < faceCount; i++) {
      // Each face bobs on its own phase so the row feels alive, and bobs
      // harder as energy rises.
      final phase = idle * 2 * math.pi + i * 0.9;
      final bob = math.sin(phase) * (2 + energy * 10);
      final cx = slot * (i + 0.5);
      final cy = size.height * 0.55 - bob - energy * 6;
      _paintFace(canvas, Offset(cx, cy), r, i);
    }
  }

  void _paintFace(Canvas canvas, Offset c, double r, int index) {
    // Head — tints toward the accent as the crowd warms up.
    final warmth = Color.lerp(faceFill, accent.withValues(alpha: 0.25), energy)!;
    canvas.drawCircle(c, r, Paint()..color = warmth);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ink.withValues(alpha: 0.12),
    );

    // Eyes. Distracted (low energy) → look aside; engaged → look forward and
    // open wider.
    final eyeDx = r * 0.42;
    final eyeDy = -r * 0.15;
    final gaze = (1 - energy) * r * 0.22; // slide pupils aside when bored
    final eyeR = r * (0.14 + energy * 0.06);
    final eyePaint = Paint()..color = ink.withValues(alpha: 0.85);
    canvas.drawCircle(c + Offset(-eyeDx + gaze, eyeDy), eyeR, eyePaint);
    canvas.drawCircle(c + Offset(eyeDx + gaze, eyeDy), eyeR, eyePaint);

    // Mouth: frown/flat when distracted → smile when excited.
    final mouth = Path();
    final mw = r * 0.5;
    final my = c.dy + r * 0.35;
    // curve: negative (frown) at energy 0 → positive (smile) at energy 1
    final curve = (energy - 0.4) * r * 0.9;
    mouth.moveTo(c.dx - mw, my);
    mouth.quadraticBezierTo(c.dx, my + curve, c.dx + mw, my);
    canvas.drawPath(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round
        ..color = ink.withValues(alpha: 0.75),
    );

    // A little excitement spark above the most animated faces.
    if (energy > 0.75 && index.isEven) {
      final sparkPaint = Paint()..color = accent;
      canvas.drawCircle(c + Offset(r * 0.9, -r * 1.05), r * 0.1, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_BancaPainter old) =>
      old.energy != energy || old.idle != idle;
}
