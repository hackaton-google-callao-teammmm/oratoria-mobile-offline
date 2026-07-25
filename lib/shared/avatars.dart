import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// A tiny fixed set of kid-friendly avatars. The emoji is stored as the
/// profile's `avatarKey`, so there is nothing to download and it renders the
/// same everywhere.
abstract final class Avatars {
  static const all = <String>['🦊', '🐱', '🐸', '🦉', '🐬', '🦁', '🐼', '🐧'];

  static String get first => all.first;
}

/// Renders an avatar emoji inside a soft accent-tinted circle.
class AvatarBubble extends StatelessWidget {
  final String emoji;
  final double size;
  final bool selected;

  const AvatarBubble({
    super.key,
    required this.emoji,
    this.size = 64,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.surface2,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? t.accent : t.line,
          width: selected ? 3 : 1.5,
        ),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// [AvatarBubble] wrapped in a [Hero], for the profile picker → hub
/// transition (same profile, different size). `FittedBox` in the shuttle
/// avoids the raw size-tween distortion Hero shows by default when the two
/// endpoints have different sizes.
class AvatarHero extends StatelessWidget {
  final String tag;
  final String emoji;
  final double size;
  final bool selected;

  const AvatarHero({
    super.key,
    required this.tag,
    required this.emoji,
    this.size = 64,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (_, _, direction, fromCtx, toCtx) {
        final hero =
            (direction == HeroFlightDirection.push ? toCtx.widget : fromCtx.widget)
                as Hero;
        return FittedBox(fit: BoxFit.contain, child: hero.child);
      },
      child: AvatarBubble(emoji: emoji, size: size, selected: selected),
    );
  }
}
