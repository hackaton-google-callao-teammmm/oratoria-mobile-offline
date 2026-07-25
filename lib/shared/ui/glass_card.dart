import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// A frosted card that sits over the aurora backdrop. On the A12 we skip the
/// real backdrop blur (too costly on the Exynos GPU) and instead use a
/// translucent surface + hairline + soft shadow, so the aurora glows faintly
/// through — the glass look without the GPU cost.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accentEdge;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.accentEdge,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: dark ? 0.62 : 0.72),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: accentEdge ?? t.ink.withValues(alpha: dark ? 0.10 : 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: card,
      ),
    );
  }
}
