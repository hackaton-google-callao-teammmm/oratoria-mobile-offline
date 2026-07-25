import 'package:flutter/material.dart';

import 'app/theme/theme.dart';
import 'app/theme/theme_controller.dart';
import 'presentation/splash/splash_screen.dart';

void main() {
  // No heavy work before runApp — the Gemma pre-warm is kicked off from the
  // splash AFTER the first frame, so the model load (~31 s of native work)
  // never competes with rendering the UI. Starting it here made the launch
  // take 9 s and skip 200+ frames.
  runApp(const OratoriaKidsApp());
}

class OratoriaKidsApp extends StatefulWidget {
  const OratoriaKidsApp({super.key});

  @override
  State<OratoriaKidsApp> createState() => _OratoriaKidsAppState();
}

class _OratoriaKidsAppState extends State<OratoriaKidsApp> {
  final _theme = ThemeController();

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _theme,
      builder: (context, mode, _) => MaterialApp(
        title: 'OratorIA Kids',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: SplashScreen(themeController: _theme),
      ),
    );
  }
}
