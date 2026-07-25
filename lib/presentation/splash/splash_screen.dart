import 'dart:async';

import 'package:flutter/material.dart';

import '../../adapters/coach/gemma_service.dart';
import '../../app/theme/theme_controller.dart';
import '../../data/local_store.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/brand/brand_logo.dart';
import '../../shared/characters/vox.dart';
import '../profiles/profile_picker_screen.dart';

/// Splash — Vox greets for ~1.6 s. Two things hide behind this friendly beat:
/// the local store opens, and (fired from main) Gemma pre-warms — the one-time
/// ~31 s cold model load happens here in the background so the first real
/// answer during a session is the fast warm one. Fully offline, no login.
class SplashScreen extends StatefulWidget {
  final ThemeController themeController;

  const SplashScreen({super.key, required this.themeController});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the Gemma pre-warm only AFTER the first frame is on screen, so
    // the ~31 s model load never competes with rendering. There's plenty of
    // time before the first real call (the child browses profiles, picks a
    // challenge, speaks 30–90 s), so the model is warm by the time it's used.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(GemmaService.instance.warmUp());
    });
    _boot();
  }

  Future<void> _boot() async {
    final store = await LocalStore.open();
    // Let Vox say hello — a splash that flashes past feels broken to a child.
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePickerScreen(
          store: store,
          themeController: widget.themeController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Vox(mood: VoxMood.greeting, size: 128),
              const SizedBox(height: 32),
              const BrandLockup(height: 44),
              const SizedBox(height: 14),
              Text(
                '¡Hola! Soy Vox',
                style: text.titleMedium?.copyWith(letterSpacing: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
