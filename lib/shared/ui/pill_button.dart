import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import 'morphing_text.dart';

/// The hero call-to-action — a gradient "pill" with a soft coloured glow and a
/// tactile press-scale. Used for the big Practicar button; more expressive
/// than a flat FilledButton, still calm enough for kids.
///
/// Pass [labels] (2+ entries) instead of a single [label] to have the text
/// morph between them (see [MorphingText]) — used to keep "Practicar" feeling
/// alive with rotating calls to action.
class PillButton extends StatefulWidget {
  final String label;
  final List<String>? labels;
  final IconData? icon;
  final VoidCallback onPressed;
  final double height;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.labels,
    this.icon,
    this.height = 68,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // A lime→olive gradient reads as depth and energy without leaving the brand.
    final g1 = t.lime;
    final g2 = Color.lerp(t.accent, t.lime, 0.35)!;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [g1, g2],
            ),
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: t.lime.withValues(alpha: 0.45),
                blurRadius: 26,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: (widget.labels != null && widget.labels!.length > 1)
              ? MorphingText(
                  texts: widget.labels!,
                  icon: widget.icon,
                  iconColor: t.onLime,
                  style: TextStyle(
                    color: t.onLime,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: t.onLime, size: 24),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: t.onLime,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
