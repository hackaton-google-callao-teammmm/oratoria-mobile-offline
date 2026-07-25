import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/local_store.dart';
import '../../../shared/avatars.dart';

/// A particle emitted during the chaotic bounce animation.
class _Sparkle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  Color color;

  _Sparkle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

class _SparkleParticlePainter extends CustomPainter {
  final List<_Sparkle> sparkles;

  _SparkleParticlePainter(this.sparkles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      if (s.opacity <= 0) continue;
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.opacity)
        ..style = PaintingStyle.fill;

      // Draw a 4-point star / sparkle
      final path = Path();
      final r = s.size;
      final cx = s.x;
      final cy = s.y;

      path.moveTo(cx, cy - r);
      path.quadraticBezierTo(cx, cy, cx + r, cy);
      path.quadraticBezierTo(cx, cy, cx, cy + r);
      path.quadraticBezierTo(cx, cy, cx - r, cy);
      path.quadraticBezierTo(cx, cy, cx, cy - r);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleParticlePainter oldDelegate) => true;
}

/// Header tile displaying profile avatar and name with interactive, playful hold gesture.
class PlayfulHoldHeader extends StatefulWidget {
  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback onLongPressComplete;

  const PlayfulHoldHeader({
    super.key,
    required this.profile,
    required this.onTap,
    required this.onLongPressComplete,
  });

  @override
  State<PlayfulHoldHeader> createState() => _PlayfulHoldHeaderState();
}

class _PlayfulHoldHeaderState extends State<PlayfulHoldHeader>
    with TickerProviderStateMixin {
  late final AnimationController _chargeController;
  late final AnimationController _jumpController;
  Timer? _chargeTimer;

  bool _isCharging = false;
  bool _isJumping = false;
  final math.Random _random = math.Random();

  // Jump animation trajectory points
  double _jumpDx = 0;
  double _jumpDy = 0;
  double _jumpAngle = 0;
  double _jumpScale = 1.0;

  // Sparkles
  final List<_Sparkle> _sparkles = [];

  // Colors for sparkles
  static const _sparkleColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFFF69B4), // Hot pink
    Color(0xFF00E5FF), // Cyan
    Color(0xFF7C4DFF), // Purple
    Color(0xFFFFAB40), // Amber
  ];

  @override
  void initState() {
    super.initState();

    // 1. Charge / Tremble controller (repeats rapidly during hold)
    _chargeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    )..addListener(_onChargeTick);

    // 2. Jump sequence controller
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )
      ..addListener(_onJumpTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finishJumping();
        }
      });
  }

  void _onChargeTick() {
    if (_isCharging) {
      if (_chargeController.value > 0.8) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _spawnSparkles(double x, double y) {
    for (int i = 0; i < 6; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 20.0 + _random.nextDouble() * 40.0;
      _sparkles.add(
        _Sparkle(
          x: x,
          y: y,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 15,
          size: 6.0 + _random.nextDouble() * 6.0,
          opacity: 1.0,
          color: _sparkleColors[_random.nextInt(_sparkleColors.length)],
        ),
      );
    }
  }

  void _onJumpTick() {
    final t = _jumpController.value;

    // Update particles physics
    for (final s in _sparkles) {
      s.x += s.vx * 0.016;
      s.y += s.vy * 0.016 + 0.5; // Gravity
      s.opacity = (s.opacity - 0.025).clamp(0.0, 1.0);
    }

    // 3 jumps within the t: [0..0.33], [0.33..0.66], [0.66..1.0]
    double jumpPhase;
    if (t < 0.33) {
      jumpPhase = t / 0.33;
    } else if (t < 0.66) {
      jumpPhase = (t - 0.33) / 0.33;
    } else {
      jumpPhase = (t - 0.66) / 0.34;
    }

    // Parabola height for bounce
    final bounceHeight = math.sin(jumpPhase * math.pi) * 32.0;

    // Progressive trajectory towards next profile screen position (down & right)
    const targetDx = 60.0;
    const targetDy = 120.0;

    _jumpDx = t * targetDx + math.sin(t * math.pi * 4) * 12.0;
    _jumpDy = t * targetDy - bounceHeight;
    _jumpAngle = math.sin(t * math.pi * 6) * 0.2;
    _jumpScale = 1.0 + (t * 0.3) + (bounceHeight / 100.0);

    // Trigger sparkles and haptics at jump peaks/impacts
    if ((jumpPhase > 0.45 && jumpPhase < 0.55) || jumpPhase > 0.9) {
      HapticFeedback.lightImpact();
      if (_random.nextDouble() < 0.3) {
        _spawnSparkles(60 + _jumpDx, 20 + _jumpDy);
      }
    }

    setState(() {});
  }

  void _startCharge() {
    if (_isJumping) return;
    _chargeTimer?.cancel();
    setState(() {
      _isCharging = true;
    });
    HapticFeedback.lightImpact();
    _chargeController.repeat(reverse: true);

    // Charge timeout threshold (500ms)
    _chargeTimer = Timer(const Duration(milliseconds: 500), () {
      if (_isCharging && mounted && !_isJumping) {
        _startChaosJumps();
      }
    });
  }

  void _stopCharge() {
    _chargeTimer?.cancel();
    _chargeTimer = null;
    if (!_isCharging) return;
    _chargeController.stop();
    _chargeController.reset();
    setState(() {
      _isCharging = false;
    });
  }

  void _startChaosJumps() {
    _stopCharge();
    setState(() {
      _isJumping = true;
      _sparkles.clear();
    });
    HapticFeedback.mediumImpact();
    _spawnSparkles(40, 20);
    _jumpController.forward(from: 0.0);
  }

  void _finishJumping() {
    HapticFeedback.heavyImpact();
    widget.onLongPressComplete();
  }

  @override
  void dispose() {
    _chargeTimer?.cancel();
    _chargeController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Compute transformation
    double scale = 1.0;
    double dx = 0.0;
    double dy = 0.0;
    double rotation = 0.0;

    if (_isCharging) {
      scale = 0.94;
      dx = (_random.nextDouble() - 0.5) * 6.0;
      dy = (_random.nextDouble() - 0.5) * 2.0;
    } else if (_isJumping) {
      scale = _jumpScale;
      dx = _jumpDx;
      dy = _jumpDy;
      rotation = _jumpAngle;
    }

    return GestureDetector(
      onTapDown: (_) => _startCharge(),
      onTapUp: (_) {
        if (!_isJumping) {
          final wasCharging = _isCharging;
          _stopCharge();
          if (wasCharging) {
            widget.onTap();
          }
        }
      },
      onTapCancel: () => _stopCharge(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sparkles canvas overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SparkleParticlePainter(_sparkles),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Row(
                  children: [
                    AvatarHero(
                      tag: widget.profile.id,
                      emoji: widget.profile.avatarKey,
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.profile.name,
                        style: text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
