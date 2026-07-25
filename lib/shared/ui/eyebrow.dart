import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// A small uppercase, letter-spaced label set in the brand mono — the
/// editorial "eyebrow" the web uses for section headers and data labels.
/// Instantly reads as crafted rather than "Inter everything".
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;

  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: color ?? t.inkFaint,
      ),
    );
  }
}

/// A number set in the brand mono with tabular figures, so it doesn't jitter
/// as digits change (timers, WPM, counts).
TextStyle monoFigure({
  required Color color,
  double size = 20,
  FontWeight weight = FontWeight.w700,
}) =>
    TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: 0.5,
    );
