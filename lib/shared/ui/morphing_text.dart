import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Cycles through [texts], morphing each into the next with a blur+fade
/// crossfade — the Flutter equivalent of Magic UI's web "Morphing Text".
/// `AnimatedSwitcher` already manages the two-child crossfade lifecycle (the
/// web version needs manual refs/rAF for exactly that), so this is just a
/// timer picking the next index plus a blur transitionBuilder.
///
/// Pass [icon] to have it crossfade together with the text as a single unit
/// (e.g. a mic icon next to a rotating call-to-action) instead of sitting
/// static next to it. The whole block is held at a fixed width — measured
/// from the widest string in [texts] — so nothing next to it (like a sibling
/// icon outside this widget) shifts as the label length changes.
class MorphingText extends StatefulWidget {
  final List<String> texts;
  final TextStyle? style;
  final Duration interval;
  final Duration morphDuration;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;
  final double iconGap;

  const MorphingText({
    super.key,
    required this.texts,
    this.style,
    this.interval = const Duration(seconds: 2, milliseconds: 400),
    this.morphDuration = const Duration(milliseconds: 550),
    this.icon,
    this.iconColor,
    this.iconSize = 24,
    this.iconGap = 10,
  });

  @override
  State<MorphingText> createState() => _MorphingTextState();
}

class _MorphingTextState extends State<MorphingText> {
  int _index = 0;
  Timer? _timer;
  late final double _maxWidth = _measureMaxWidth();

  double _measureMaxWidth() {
    var max = 0.0;
    for (final t in widget.texts) {
      final painter = TextPainter(
        text: TextSpan(text: t, style: widget.style),
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > max) max = painter.width;
    }
    if (widget.icon != null) max += widget.iconSize + widget.iconGap;
    // Small buffer: TextPainter can measure with a fallback font if a custom
    // font (e.g. Inter) hasn't finished loading yet, under-counting the real
    // rendered width by a few px. FittedBox below is the real safety net.
    return max + 6;
  }

  @override
  void initState() {
    super.initState();
    if (widget.texts.length > 1) {
      _timer = Timer.periodic(widget.interval, (_) {
        if (mounted) {
          setState(() => _index = (_index + 1) % widget.texts.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _maxWidth,
      child: AnimatedSwitcher(
        duration: widget.morphDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => _BlurFade(
          animation: animation,
          child: child,
        ),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.center,
          children: [...previousChildren, ?currentChild],
        ),
        // FittedBox is the real overflow safety net: if the actual rendered
        // text is ever wider than `_maxWidth` guessed (font-load race,
        // OS text-scale accessibility setting, etc.), this scales the whole
        // icon+text block down instead of throwing a RenderFlex overflow.
        child: FittedBox(
          key: ValueKey(_index),
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: widget.iconColor, size: widget.iconSize),
                SizedBox(width: widget.iconGap),
              ],
              Text(
                widget.texts[_index],
                style: widget.style,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlurFade extends AnimatedWidget {
  final Widget child;

  const _BlurFade({required Animation<double> animation, required this.child})
      : super(listenable: animation);

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final t = _animation.value;
    return Opacity(
      opacity: t,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: (1 - t) * 6,
          sigmaY: (1 - t) * 6,
        ),
        child: child,
      ),
    );
  }
}
