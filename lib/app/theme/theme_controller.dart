import 'package:flutter/material.dart';

/// Holds the active theme mode and lets any widget flip it, mirroring the
/// web's theme toggle. Defaults to light (the web's default) and follows the
/// system otherwise.
///
/// Kept deliberately tiny — a single [ValueNotifier] wired at the app root.
/// A real preference store lands with drift in a later phase.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.mode = ThemeMode.light]);

  bool get isDark => value == ThemeMode.dark;

  void toggle() =>
      value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}
