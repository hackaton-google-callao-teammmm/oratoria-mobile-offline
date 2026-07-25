import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme/tokens.dart';
import 'audience_mood.dart';

/// "La Banca" — one audience face that reacts, live, to how the child is
/// speaking. The reaction ballistics live in the pure [AudienceMood]
/// (fast-attack engagement + slow boredom), advanced here by a frame [Ticker]
/// with real dt. The face itself is an expressive EMOJI chosen from the mood and
/// crossfaded — friendly at rest (never sad), delighted when the child projects,
/// and only checked-out after sustained dead air.
///
/// [personality] biases how easily this face engages and how quickly it drifts;
/// [energy] is the raw mic level (0..1).
class LaBanca extends StatefulWidget {
  final double energy;

  /// Kept for API compatibility; a tile renders a single reacting face.
  final int faceCount;
  final double height;
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
  double _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _elapsed = elapsed.inMicroseconds / 1e6;
    _mood.advance(widget.energy, dt);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(LaBanca old) {
    super.didUpdateWidget(old);
    if (old.personality != widget.personality) {
      _mood = AudienceMood(personality: widget.personality);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Mood → face. Boredom wins when it's high (they've checked out); otherwise
  /// engagement sets the smile. The resting face is friendly (🙂), never sad —
  /// a silent room is waiting, not annoyed.
  static String _emojiFor(double engage, double boredom) {
    if (boredom > 0.78) return '😴'; // gone
    if (boredom > 0.42) return '😐'; // drifting
    if (engage > 0.72) return '🤩'; // wowed
    if (engage > 0.42) return '😄'; // into it
    return '🙂'; // listening / at rest — friendly
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final e = _mood.engage;
    final b = _mood.boredom;
    final emoji = _emojiFor(e, b);

    // Warm lime glow as the face engages; a touch dimmer as it drifts.
    final tint = Color.lerp(
      Color.lerp(t.surface2, t.lime.withValues(alpha: 0.30), e)!,
      t.surface2.withValues(alpha: 0.65),
      b * 0.5,
    )!;

    // A gentle idle float, livelier when engaged; phaseSeed desyncs the row.
    final bob =
        math.sin(_elapsed * 1.7 + widget.personality.phaseSeed) *
        (1.2 + e * 2.2);

    return Container(
      color: tint,
      alignment: Alignment.center,
      child: Transform.translate(
        offset: Offset(0, -bob),
        child: Transform.scale(
          scale: 1 + e * 0.12,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              emoji,
              key: ValueKey<String>(emoji),
              style: TextStyle(fontSize: widget.height * 0.48),
            ),
          ),
        ),
      ),
    );
  }
}
