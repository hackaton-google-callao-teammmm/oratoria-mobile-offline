import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// The OratorIA voice-equalizer motif — five bars echoing the brand isotype
/// (heights 24/44/60/44/24). This is the connective brand tissue the UI audit
/// asked for: a loading pulse, the splash shimmer, and — when [energy] is
/// supplied — a live visualizer of the child's own voice while speaking.
///
/// Pure [CustomPaint] (transform/opacity only), so it's cheap on the A12.
class EqWaveform extends StatefulWidget {
  /// 0..1 live level (mic amplitude). Null = idle sine pulse.
  final double? energy;
  final double height;
  final double barWidth;
  final Color? color;

  const EqWaveform({
    super.key,
    this.energy,
    this.height = 44,
    this.barWidth = 6,
    this.color,
  });

  @override
  State<EqWaveform> createState() => _EqWaveformState();
}

class _EqWaveformState extends State<EqWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTokens.of(context).accent;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size(widget.barWidth * 9, widget.height),
          painter: _EqPainter(
            tick: _c.value,
            energy: widget.energy,
            color: color,
            barWidth: widget.barWidth,
          ),
        ),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  final double tick; // 0..1 loop
  final double? energy; // 0..1 or null
  final Color color;
  final double barWidth;

  // Relative resting heights, from the isotype (24/44/60/44/24).
  static const _base = [0.4, 0.73, 1.0, 0.73, 0.4];

  _EqPainter({
    required this.tick,
    required this.energy,
    required this.color,
    required this.barWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gap = barWidth * 0.7;
    final totalW = _base.length * barWidth + (_base.length - 1) * gap;
    var x = (size.width - totalW) / 2;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < _base.length; i++) {
      final phase = tick * 2 * math.pi + i * 0.8;
      // Idle: gentle sine breathing. Speaking: amplitude drives height, with a
      // little per-bar variation so it dances rather than pumps uniformly.
      final wobble = 0.5 + 0.5 * math.sin(phase);
      final h = energy == null
          ? size.height * _base[i] * (0.6 + 0.4 * wobble)
          : size.height *
              (0.18 + (_base[i] * 0.82) * energy!.clamp(0, 1) * (0.7 + 0.3 * wobble));
      final cx = x + barWidth / 2;
      final cy = size.height / 2;
      canvas.drawLine(
        Offset(cx, cy - h / 2),
        Offset(cx, cy + h / 2),
        paint,
      );
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_EqPainter old) =>
      old.tick != tick || old.energy != energy || old.color != color;
}
