import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// One destination in [LiquidGlassNavBar]. [label] is not painted (the bar is
/// icon-only, like the reference) but drives the accessibility semantics.
class NavItem {
  final IconData icon;
  final String label;
  const NavItem({required this.icon, required this.label});
}

/// A floating "liquid glass" bottom navigation bar: a frosted rounded pill with
/// icon-only destinations, where the ACTIVE one becomes a filled lime circle
/// (our signature `C6FF3D`) with an [AppTokens.onLime] icon, exactly like the
/// reference.
///
/// Real frosted glass here — a live [BackdropFilter] blur clipped to the bar.
/// Unlike a full-screen backdrop (which the A12's Exynos GPU can't afford, see
/// [GlassCard]), this blurs only a ~72 px strip, so the refraction is cheap even
/// on mid devices. Pass `frosted: false` to drop the blur entirely and fall back
/// to a solid translucent surface for the weakest hardware.
class LiquidGlassNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Use a live backdrop blur (true, default) or a blur-free translucent
  /// surface (false) for the weakest GPUs.
  final bool frosted;

  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    this.frosted = true,
  }) : assert(items.length >= 2, 'a nav bar needs at least two destinations');

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // The glass tint. Lower alpha when frosted so the blurred content shows
    // through; higher when not, so it still reads as a solid surface.
    final tint = t.surface.withValues(alpha: frosted ? 0.55 : 0.86);
    // The bright rim + top specular highlight are what sell "liquid glass".
    final rim = Colors.white.withValues(alpha: dark ? 0.16 : 0.55);

    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: rim, width: 1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.10 : 0.28),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < items.length; i++)
              _NavSlot(
                item: items[i],
                selected: i == currentIndex,
                tokens: t,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );

    return Container(
      // Drop shadow lives OUTSIDE the clip so it isn't cut off, and lifts the
      // bar off the content like the reference's floating pill.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.40 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: frosted
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: bar,
              )
            : bar,
      ),
    );
  }
}

/// One tappable destination. Selected → a lime circle with an [onLime] icon and
/// a soft lime glow; unselected → a plain faint icon with a generous hit box.
class _NavSlot extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final AppTokens tokens;
  final VoidCallback onTap;

  const _NavSlot({
    required this.item,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        containedInkWell: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: selected ? 54 : 48,
          height: 54,
          decoration: BoxDecoration(
            color: selected ? t.lime : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: t.lime.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            item.icon,
            size: 24,
            color: selected ? t.onLime : t.inkFaint,
          ),
        ),
      ),
    );
  }
}
