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
