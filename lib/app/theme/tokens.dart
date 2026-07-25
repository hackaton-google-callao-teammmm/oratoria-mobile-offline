import 'package:flutter/material.dart';

/// The "Spotlight" palette, ported verbatim from the web frontend
/// (`apps/web/src/index.css`). Editorial cream + lime/olive accent, high
/// contrast, with matching light and dark schemes.
///
/// One record per theme so a widget can read `AppTokens.light.accent` without
/// caring which mode is active — the [AppTokens.of] helper resolves it from
/// context.
class AppTokens {
  final Color stage; // page background
  final Color surface; // card background
  final Color surface2; // inset / muted surface
  final Color line; // hairline border
  final Color lineStrong; // stronger border
  final Color ink; // primary text
  final Color inkSoft; // secondary text
  final Color inkFaint; // tertiary text
  final Color accent; // brand accent (olive in light, lime in dark)
  final Color lime; // the signature lime, constant across modes
  final Color limeDim;
  final Color onLime; // text/icon over a lime fill
  final Color star; // earned-star amber, tokenised so it works in both themes
  final Color improve; // "para la próxima" amber — never red

  const AppTokens({
    required this.stage,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.accent,
    required this.lime,
    required this.limeDim,
    required this.onLime,
    required this.star,
    required this.improve,
  });

  static const light = AppTokens(
    stage: Color(0xFFF6F5F1),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFEEE8),
    line: Color(0xFFE6E4DA),
    lineStrong: Color(0xFFD4D2C6),
    ink: Color(0xFF1A1A16),
    inkSoft: Color(0xFF5C5B52),
    inkFaint: Color(0xFF8D8B80),
    accent: Color(0xFF4D7C0F),
    lime: Color(0xFFC6FF3D),
    limeDim: Color(0xFFAEE029),
    onLime: Color(0xFF0F0F0D),
    star: Color(0xFFE8A33D),
    improve: Color(0xFFB4761F),
  );

  static const dark = AppTokens(
    stage: Color(0xFF0A0B08),
    surface: Color(0xFF14150F),
    surface2: Color(0xFF1C1E16),
    line: Color(0xFF2B2D23),
    lineStrong: Color(0xFF3B3E30),
    ink: Color(0xFFF3F4EC),
    inkSoft: Color(0xFFA4A698),
    inkFaint: Color(0xFF6C6E60),
    accent: Color(0xFFC6FF3D),
    lime: Color(0xFFC6FF3D),
    limeDim: Color(0xFFAEE029),
    onLime: Color(0xFF0F0F0D),
    star: Color(0xFFF0B84E),
    improve: Color(0xFFE0A83D),
  );

  /// Resolve the active palette from the current theme brightness.
  static AppTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Font families. The `.ttf` files live in `assets/fonts/` and are declared in
/// `pubspec.yaml`. Material Symbols (the web icon font) is intentionally NOT
/// bundled — Flutter's built-in `Icons.*` cover the same glyphs natively and
/// weigh nothing extra.
abstract final class AppFonts {
  static const sans = 'Inter';
  static const mono = 'JetBrainsMono';
}

/// Corner radii used across the web UI.
abstract final class AppRadius {
  static const card = 20.0;
  static const button = 16.0;
  static const chip = 12.0;
  static const pill = 999.0;
}
