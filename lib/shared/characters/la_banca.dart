import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme/tokens.dart';
import 'audience_mood.dart';

/// "La Banca" — the audience. A little face (or row of them) that reacts, live,
/// to how the child is speaking. The on-device stand-in for the web's avatar:
/// the audience *is* the live feedback, so no corrective text ever appears while
/// the child talks.
///
/// [energy] is the raw mic level (0..1). The reaction ballistics live in the
/// pure [AudienceMood] (fast-attack engagement + slow boredom), advanced here by
/// a frame [Ticker] with real dt so the integrator is stable and in step with
/// the eye — NOT the jittery audio-chunk rate. [personality] biases how easily
/// this face engages and how quickly it drifts. The painter is deliberately
/// dumb: it only draws the mood's [AudienceMood.engage] / [AudienceMood.boredom].
class LaBanca extends StatefulWidget {
  /// Raw mic level, 0..1. The mood smooths it internally.
  final double energy;
  final int faceCount;
  final double height;

  /// This face's disposition (warm / neutral / tough). Defaults to neutral.
  final AudiencePersonality personality;

  const LaBanca({
    super.key,
    required this.energy,
    this.faceCount = 1,
    this.height = 120,
    this.personality = AudiencePersonality.neutral,
  });

  @override
  State<LaBanca> createState() => _LaBancaState();
}

class _LaBancaState extends State<LaBanca> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late AudienceMood _mood = AudienceMood(personality: widget.personality);

  Duration _last = Duration.zero;
  double _elapsedSec = 0; // drives the idle bob

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _elapsedSec = elapsed.inMicroseconds / 1e6;
    _mood.advance(widget.energy, dt);
    if (mounted) setState(() {}); // repaint from the fresh E/B
  }

  @override
  void didUpdateWidget(LaBanca old) {
    super.didUpdateWidget(old);
    // Only the mic level normally changes; rebuild the mood only if the
    // personality itself is swapped (rare).
    if (old.personality != widget.personality) {
      _mood = AudienceMood(personality: widget.personality);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return CustomPaint(
      size: Size(double.infinity, widget.height),
      painter: _BancaPainter(
        engage: _mood.engage,
        boredom: _mood.boredom,
        elapsedSec: _elapsedSec,
        phaseSeed: widget.personality.phaseSeed,
        faceCount: widget.faceCount,
        accent: t.accent,
        faceFill: t.surface2,
        ink: t.ink,
      ),
    );
  }
}

class _BancaPainter extends CustomPainter {
  final double engage; // E: 0 = flat, 1 = beaming
  final double boredom; // B: 0 = rapt, 1 = checked out
  final double elapsedSec; // wall-clock for the idle bob
  final double phaseSeed; // per-face desync
  final int faceCount;
  final Color accent;
  final Color faceFill;
  final Color ink;

  _BancaPainter({
    required this.engage,
    required this.boredom,
    required this.elapsedSec,
    required this.phaseSeed,
    required this.faceCount,
    required this.accent,
    required this.faceFill,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / faceCount;
    final r = math.min(slot, size.height) * 0.32;

    for (var i = 0; i < faceCount; i++) {
      // ~3 s idle loop; phaseSeed (+ a per-face nudge) breaks the lockstep.
      final phase = elapsedSec * (2 * math.pi / 3) + phaseSeed + i * 0.9;
      final bob = math.sin(phase) * (2 + engage * 10);
      final cx = slot * (i + 0.5);
      final cy = size.height * 0.55 - bob - engage * 6;
      _paintFace(canvas, Offset(cx, cy), r, i);
    }
  }

  void _paintFace(Canvas canvas, Offset c, double r, int index) {
    // Head warms toward the accent as this face engages.
    final warmth = Color.lerp(faceFill, accent.withValues(alpha: 0.25), engage)!;
    canvas.drawCircle(c, r, Paint()..color = warmth);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ink.withValues(alpha: 0.12),
    );

    // Eyes. Boredom (not silence) slides the gaze away; engagement opens them.
    final eyeDx = r * 0.42;
    final eyeDy = -r * 0.15;
    final gaze = boredom * r * 0.30; // drift aside only when actually bored
    final eyeR = r * (0.14 + engage * 0.06);
    final eyePaint = Paint()..color = ink.withValues(alpha: 0.85);
    canvas.drawCircle(c + Offset(-eyeDx + gaze, eyeDy), eyeR, eyePaint);
    canvas.drawCircle(c + Offset(eyeDx + gaze, eyeDy), eyeR, eyePaint);

    // Mouth: neutral (flat) at rest, smile from engagement, frown only from
    // sustained boredom. A silent pause is 0/0 → flat, never sad.
    final mouth = Path();
    final mw = r * 0.5;
    final my = c.dy + r * 0.35;
    final curve = (engage * 0.9 - boredom * 0.8) * r;
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

    // A little excitement spark above a beaming face.
    if (engage > 0.75 && index.isEven) {
      canvas.drawCircle(
        c + Offset(r * 0.9, -r * 1.05),
        r * 0.1,
        Paint()..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(_BancaPainter old) =>
      old.engage != engage ||
      old.boredom != boredom ||
      old.elapsedSec != elapsedSec;
}
