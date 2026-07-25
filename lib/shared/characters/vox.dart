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

  /// Attentive while the child speaks — chest equalizer dances, antenna
  /// pulses like a recording light, little sound arcs by the "ear".
  listening,

  /// Stars earned — bouncing, wings up, sparkles. Never used for low scores.
  celebrating,

  /// Delivering one concrete tip — wing raised like a finger, a wink, and a
  /// bright idea-spark above it.
  tip,
}

/// "Vox" — the coach mascot that guides every screen. A little robot parrot,
/// drawn entirely with [CustomPaint] (no image assets) on purpose: it inherits
/// the light/dark palette from [AppTokens] at paint time, scales from 44 px to
/// 132 px without shipping bitmaps, and stays animatable per mood — none of
/// which a static SVG/PNG would give us offline for free.
///
/// The parrot reads first (crest, hooked beak, wings, tail fan); the robot is
/// in the details: LED-screen eyes, an antenna with a glowing tip, a hinged
/// beak with screw pins, and a chest panel whose equalizer bars echo the
/// OratorIA isotype.
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
        painter: _VoxPainter(mood: widget.mood, tick: _c.value, t: t),
      ),
    );
  }
}

class _VoxPainter extends CustomPainter {
  final VoxMood mood;
  final double tick; // 0..1 loop
  final AppTokens t;

  _VoxPainter({required this.mood, required this.tick, required this.t});

  // All geometry lives on a 100×100 design grid; paint() scales the canvas so
  // stroke widths and blurs stay proportional at every widget size.
  static const double _grid = 100;

  double get _wave => math.sin(tick * 2 * math.pi);

  /// Near-black used for the LED eyes, the beak hinge and the chest panel.
  /// `onLime` is constant across themes, so the face never loses contrast.
  Color get _dark => t.onLime;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _grid);

    _groundShadow(canvas);

    canvas.save();
    // Whole-bird motion: a happy bounce when celebrating, a curious head
    // tilt while listening, and a gentle breathe everywhere else.
    switch (mood) {
      case VoxMood.celebrating:
        canvas.translate(0, -3.0 * math.sin(tick * 2 * math.pi * 2).abs());
      case VoxMood.listening:
        canvas.translate(50, 50);
        canvas.rotate(0.05);
        canvas.translate(-50, -50);
      default:
        canvas.translate(0, _wave * 0.6);
    }

    _tail(canvas);
    _feet(canvas);
    _wings(canvas);
    _body(canvas);
    _cheeks(canvas);
    _crestAndAntenna(canvas);
    _chestPanel(canvas);
    _eyes(canvas);
    _beak(canvas);
    _moodExtras(canvas);

    canvas.restore();
    canvas.restore();
  }

  // ── Soft contact shadow ───────────────────────────────────────────────────

  void _groundShadow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 91), width: 46, height: 8),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  // ── Parrot silhouette ─────────────────────────────────────────────────────

  void _tail(Canvas canvas) {
    // Three feathers fanned out below the body; the side ones spread wide so
    // the fan peeks past the silhouette in the front view — without the tail
    // the parrot reads as a chick.
    for (final (angle, shade) in [(-0.75, 0.12), (0.0, 0.28), (0.75, 0.12)]) {
      canvas.save();
      canvas.translate(50, 72);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.5, 0, 7, 19),
          const Radius.circular(3.5),
        ),
        Paint()..color = Color.lerp(t.limeDim, Colors.black, shade)!,
      );
      canvas.restore();
    }
  }

  void _feet(Canvas canvas) {
    // Tiny metal feet — one of the quiet robot cues.
    final metal = Paint()..color = t.inkFaint;
    for (final x in [43.0, 57.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, 86.5), width: 8, height: 4),
          const Radius.circular(2),
        ),
        metal,
      );
    }
  }

  void _wings(Canvas canvas) {
    // Capsule wings pivoting at the shoulder. Angle 0 points straight down;
    // π points up. Which wing raises (and how) is the clearest mood signal.
    double left = 0.25, right = -0.25;
    switch (mood) {
      case VoxMood.greeting:
        right = math.pi + 0.35 + 0.30 * math.sin(tick * 2 * math.pi * 2);
      case VoxMood.celebrating:
        final flap = 0.15 * math.sin(tick * 2 * math.pi * 2);
        left = math.pi - 0.40 - flap;
        right = math.pi + 0.40 + flap;
      case VoxMood.tip:
        right = math.pi + 0.32;
      default:
        break;
    }
    _wing(canvas, const Offset(25, 54), left);
    _wing(canvas, const Offset(75, 54), right);
  }

  void _wing(Canvas canvas, Offset shoulder, double angle) {
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);
    final wing = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-5.5, -2, 11, 24),
      const Radius.circular(5.5),
    );
    canvas.drawRRect(wing, Paint()..color = t.limeDim);
    // Elbow seam — an articulated joint, not a feather line.
    canvas.drawLine(
      const Offset(-4, 12),
      const Offset(4, 12),
      Paint()
        ..color = _dark.withValues(alpha: 0.18)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _body(Canvas canvas) {
    // Head circle + egg body fused into one silhouette, lit from the top like
    // the rest of the UI's cards. Lime is constant across themes — Vox is the
    // brand made animate.
    final silhouette = Path()
      ..addOval(Rect.fromCircle(center: const Offset(50, 33), radius: 23))
      ..addOval(
        Rect.fromCenter(center: const Offset(50, 60), width: 54, height: 50),
      );
    final bounds = silhouette.getBounds();
    canvas.drawPath(
      silhouette.shift(const Offset(0, 1.6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      silhouette,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(t.lime, Colors.white, 0.16)!,
            t.lime,
            Color.lerp(t.lime, Colors.black, 0.10)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bounds),
    );
    // Glossy highlight over the head — same treatment the old blob had.
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(50, 31), radius: 17),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.20),
    );
  }

  void _cheeks(Canvas canvas) {
    // Warm cheek patches — parrot markings, kept in the star amber so they
    // work over lime in both themes.
    final blush = Paint()..color = t.star.withValues(alpha: 0.30);
    canvas.drawCircle(const Offset(35, 40), 4.5, blush);
    canvas.drawCircle(const Offset(65, 40), 4.5, blush);
  }

  void _crestAndAntenna(Canvas canvas) {
    // Two crest feathers flank a centre antenna: feather bird, robot core.
    for (final (x, angle) in [(43.0, -0.5), (57.0, 0.5)]) {
      canvas.save();
      canvas.translate(x, 14);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2, -9, 4, 12),
          const Radius.circular(2),
        ),
        Paint()..color = t.limeDim,
      );
      canvas.restore();
    }
    canvas.drawLine(
      const Offset(50, 12),
      const Offset(50, 5),
      Paint()
        ..color = t.inkSoft
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // Antenna tip: a steady lamp at rest, a strong pulse while listening
    // (recording light), dim while thinking (the work happens inside).
    final pulse = switch (mood) {
      VoxMood.listening => 0.55 + 0.45 * _wave.abs(),
      VoxMood.thinking => 0.35,
      VoxMood.celebrating => 1.0,
      _ => 0.65 + 0.15 * _wave,
    };
    canvas.drawCircle(
      const Offset(50, 4.5),
      4.2,
      Paint()
        ..color = t.lime.withValues(alpha: 0.35 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(
      const Offset(50, 4.5),
      2.6,
      Paint()..color = Color.lerp(t.lime, Colors.white, 0.25 * pulse)!,
    );
  }

  // ── Robot face ────────────────────────────────────────────────────────────

  void _eyes(Canvas canvas) {
    switch (mood) {
      case VoxMood.greeting || VoxMood.celebrating:
        _happyArcEye(canvas, const Offset(39, 32));
        _happyArcEye(canvas, const Offset(61, 32));
      case VoxMood.tip:
        _ledEye(canvas, const Offset(39, 31), pupilShift: Offset.zero);
        // Wink: the right screen shows a single closed line.
        canvas.drawLine(
          const Offset(57.5, 32),
          const Offset(64.5, 32),
          Paint()
            ..color = _dark
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
      case VoxMood.thinking:
        const up = Offset(-1.4, -1.7);
        _ledEye(canvas, const Offset(39, 31), pupilShift: up);
        _ledEye(canvas, const Offset(61, 31), pupilShift: up);
      case VoxMood.listening:
        _ledEye(canvas, const Offset(39, 31),
            pupilShift: Offset.zero, pupilScale: 1.3);
        _ledEye(canvas, const Offset(61, 31),
            pupilShift: Offset.zero, pupilScale: 1.3);
      default:
        _ledEye(canvas, const Offset(39, 31), pupilShift: Offset.zero);
        _ledEye(canvas, const Offset(61, 31), pupilShift: Offset.zero);
    }
  }

  /// An LED screen eye: dark rounded square, glowing lime pupil, tiny white
  /// specular. Blinks by squashing, like a display power-saving flicker.
  void _ledEye(Canvas canvas, Offset c,
      {required Offset pupilShift, double pupilScale = 1.0}) {
    final blink = _wave > 0.95 ? 0.25 : 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 11, height: 11 * blink),
        const Radius.circular(3),
      ),
      Paint()..color = _dark,
    );
    if (blink == 1.0) {
      final pupil = 5.4 * pupilScale;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c + pupilShift, width: pupil, height: pupil),
          const Radius.circular(1.4),
        ),
        Paint()..color = t.lime,
      );
      canvas.drawCircle(
        c + pupilShift + const Offset(-1.1, -1.1),
        0.9,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  void _happyArcEye(Canvas canvas, Offset c) {
    canvas.drawArc(
      Rect.fromCircle(center: c + const Offset(0, 1.5), radius: 5.2),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = _dark,
    );
  }

  void _beak(Canvas canvas) {
    // How far the beak is open, 0..1.
    final open = switch (mood) {
      VoxMood.speaking => (0.55 + 0.45 * math.sin(tick * 2 * math.pi * 3))
          .abs()
          .clamp(0.0, 1.0),
      VoxMood.greeting || VoxMood.celebrating => 0.35,
      VoxMood.tip => 0.2,
      _ => 0.0,
    };
    final gap = open * 4;

    // Dark mouth opening + a small lower mandible when talking.
    if (gap > 0.2) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50, 48 + gap / 2), width: 11, height: gap + 2),
        Paint()..color = _dark,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(50, 49.5 + gap), width: 9, height: 3.4),
          const Radius.circular(1.7),
        ),
        Paint()..color = Color.lerp(t.star, Colors.black, 0.25)!,
      );
    }

    // Upper beak: the hooked parrot profile, nudged up as it opens.
    canvas.save();
    canvas.translate(0, -open * 1.5);
    final beak = Path()
      ..moveTo(43.5, 41.5)
      ..quadraticBezierTo(50, 39.6, 56.5, 41.5)
      ..quadraticBezierTo(56.8, 48.5, 50, 52.5)
      ..quadraticBezierTo(43.2, 48.5, 43.5, 41.5)
      ..close();
    canvas.drawPath(beak, Paint()..color = t.star);
    // Shaded tip gives the hook its curl.
    canvas.drawPath(
      Path()
        ..moveTo(46, 48)
        ..quadraticBezierTo(50, 51.5, 54, 48)
        ..quadraticBezierTo(52, 51.5, 50, 52.5)
        ..quadraticBezierTo(48, 51.5, 46, 48)
        ..close(),
      Paint()..color = Color.lerp(t.star, Colors.black, 0.22)!,
    );
    // Hinge pins — the beak is articulated, one more quiet robot cue.
    final pin = Paint()..color = _dark.withValues(alpha: 0.45);
    canvas.drawCircle(const Offset(44.2, 42.4), 0.9, pin);
    canvas.drawCircle(const Offset(55.8, 42.4), 0.9, pin);
    canvas.restore();
  }

  // ── Chest panel: the isotype come alive ───────────────────────────────────

  void _chestPanel(Canvas canvas) {
    final panel = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(50, 65.5), width: 23, height: 17),
      const Radius.circular(4),
    );
    canvas.drawRRect(panel, Paint()..color = _dark);
    canvas.drawRRect(
      panel.deflate(1.0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = t.lime.withValues(alpha: 0.35),
    );
    // Corner rivets.
    final rivet = Paint()..color = t.lime.withValues(alpha: 0.4);
    for (final d in const [
      Offset(41.2, 59.7),
      Offset(58.8, 59.7),
      Offset(41.2, 71.3),
      Offset(58.8, 71.3),
    ]) {
      canvas.drawCircle(d, 0.7, rivet);
    }
    // Five equalizer bars — the OratorIA isotype, inverted (lime on dark) and
    // dancing with whatever Vox is doing.
    final heights = _barHeights();
    for (var i = 0; i < 5; i++) {
      final h = 3 + heights[i] * 9;
      final x = 41.6 + i * 3.6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 71.5 - h, 2.4, h),
          const Radius.circular(1.2),
        ),
        Paint()..color = t.lime,
      );
    }
  }

  List<double> _barHeights() {
    double bounce(int i, double speed, double base, double amp) =>
        base + amp * math.sin(tick * 2 * math.pi * speed + i * 1.1).abs();
    switch (mood) {
      case VoxMood.listening:
        return [for (var i = 0; i < 5; i++) bounce(i, 2, 0.25, 0.6)];
      case VoxMood.speaking:
        return [for (var i = 0; i < 5; i++) bounce(i, 3, 0.35, 0.6)];
      case VoxMood.celebrating:
        return [for (var i = 0; i < 5; i++) bounce(i, 2, 0.5, 0.5)];
      case VoxMood.greeting:
        return [for (var i = 0; i < 5; i++) bounce(i, 1, 0.3, 0.35)];
      case VoxMood.thinking:
        // A single pulse sweeping left→right: processing.
        final head = (tick * 2 % 1.0) * 5;
        return [
          for (var i = 0; i < 5; i++)
            0.15 + 0.7 * (1 - (i - head).abs()).clamp(0.0, 1.0),
        ];
      case VoxMood.tip:
        // A steady "signal peak" — confident, not busy.
        return const [0.25, 0.5, 0.8, 0.5, 0.25];
      case VoxMood.idle:
        final breathe = 0.85 + 0.15 * _wave;
        return [for (final h in const [0.25, 0.4, 0.3, 0.45, 0.25]) h * breathe];
    }
  }

  // ── Per-mood decorations around the bird ──────────────────────────────────

  void _moodExtras(Canvas canvas) {
    switch (mood) {
      case VoxMood.listening:
        _soundArcs(canvas);
      case VoxMood.thinking:
        _thoughtDots(canvas);
      case VoxMood.celebrating:
        _sparkles(canvas);
      case VoxMood.tip:
        _ideaSpark(canvas);
      default:
        break;
    }
  }

  void _soundArcs(Canvas canvas) {
    // Two arcs by the "ear", pulsing with the antenna: I can hear you.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = t.accent.withValues(alpha: 0.45 + 0.4 * _wave.abs());
    for (final r in [5.5, 9.5]) {
      paint.strokeWidth = 1.8;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(69, 19), radius: r),
        -math.pi / 4 - 0.55,
        1.1,
        false,
        paint,
      );
    }
  }

  void _thoughtDots(Canvas canvas) {
    // Three dots trailing up and away, pulsing in sequence — kept from the
    // original Vox because children already read it as "está pensando".
    const dots = [Offset(64, 13), Offset(72, 9), Offset(80, 5)];
    for (var i = 0; i < dots.length; i++) {
      final phase = (tick * 3 - i) % 1.0;
      final a = math.sin(phase * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        dots[i],
        1.8 + i * 0.5,
        Paint()..color = t.accent.withValues(alpha: 0.35 + a * 0.65),
      );
    }
  }

  void _sparkles(Canvas canvas) {
    // Little plus-sparks popping in staggered rhythm around the bird.
    const points = [
      Offset(18, 18),
      Offset(82, 14),
      Offset(13, 56),
      Offset(87, 50),
      Offset(70, 6),
    ];
    for (var i = 0; i < points.length; i++) {
      final phase = (tick * 2 - i * 0.2) % 1.0;
      final a = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final paint = Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = (i.isEven ? t.accent : t.star).withValues(alpha: a);
      final c = points[i];
      final s = 2.4 + a * 0.8;
      canvas.drawLine(c - Offset(s, 0), c + Offset(s, 0), paint);
      canvas.drawLine(c - Offset(0, s), c + Offset(0, s), paint);
    }
  }

  void _ideaSpark(Canvas canvas) {
    // A four-point star above the raised wing: "here's the tip".
    final a = 0.6 + 0.4 * _wave.abs();
    final paint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = t.star.withValues(alpha: a);
    const c = Offset(84, 20);
    canvas.drawLine(c - const Offset(3.4, 0), c + const Offset(3.4, 0), paint);
    canvas.drawLine(c - const Offset(0, 3.4), c + const Offset(0, 3.4), paint);
    canvas.drawCircle(c, 1.1, Paint()..color = t.star.withValues(alpha: a));
  }

  @override
  bool shouldRepaint(_VoxPainter old) =>
      old.tick != tick || old.mood != mood || old.t != t;
}
