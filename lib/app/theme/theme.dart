import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

/// Builds the app's [ThemeData] from the Spotlight [AppTokens], matching the
/// web frontend. Both light and dark are first-class — the web ships both and
/// so do we.
abstract final class AppTheme {
  /// Feedback semantics. Never red: a child's practice is coaching, not an
  /// error. Strength = the lime/olive accent; improvement = a warm amber.
  static const improvementLight = Color(0xFFB4761F);
  static const improvementDark = Color(0xFFE0A83D);

  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.onLime,
      secondary: t.lime,
      onSecondary: t.onLime,
      surface: t.surface,
      onSurface: t.ink,
      surfaceContainerHighest: t.surface2,
      outline: t.line,
      outlineVariant: t.lineStrong,
      error: const Color(0xFFB4761F),
      onError: Colors.white,
    );

    final text = _textTheme(t);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.stage,
      fontFamily: AppFonts.sans,
      textTheme: text,
      cardTheme: CardThemeData(
        elevation: 0,
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: t.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onLime,
          // 56 px min: a 9-year-old's tap is less precise than an adult's.
          minimumSize: const Size.fromHeight(56),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: t.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface2,
        hintStyle: TextStyle(color: t.inkFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: t.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: t.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: t.accent, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      iconTheme: IconThemeData(color: t.ink),
    );
  }

  static TextTheme _textTheme(AppTokens t) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
        color: t.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: t.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: t.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: t.ink,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: t.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: t.inkSoft),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: t.inkSoft,
      ),
    );
  }
}
