import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/avatars.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/characters/vox.dart';
import '../../shared/ui/pill_button.dart';
import '../benchmark/benchmark_screen.dart';
import '../home/home_screen.dart';
import '../progress/progress_screen.dart';

/// INICIO — the hub (Flujo, mapa). Vox welcomes the child by name; one big
/// "Practicar" button leads into the session, plus "Mi progreso". The dev
/// benchmark is reachable only by long-pressing Vox — hidden from the child's
/// journey. An offline badge because nothing here touches the network.
class HubScreen extends StatelessWidget {
  final Profile profile;
  final LocalStore store;
  final ThemeController themeController;

  const HubScreen({
    super.key,
    required this.profile,
    required this.store,
    required this.themeController,
  });

  void _practice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(profile: profile, store: store),
      ),
    );
  }

  void _progress(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgressScreen(profile: profile, store: store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    AvatarBubble(emoji: profile.avatarKey, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        profile.name,
                        style: text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const _OfflineBadge(),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeController,
                      builder: (context, mode, _) => IconButton(
                        tooltip: 'Cambiar tema',
                        icon: Icon(
                          themeController.isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          themeController.toggle();
                        },
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Long-press Vox opens the hidden dev benchmark.
                GestureDetector(
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BenchmarkScreen(),
                      ),
                    );
                  },
                  child: const Vox(mood: VoxMood.greeting, size: 132),
                ),
                const SizedBox(height: 24),
                Text(
                  '¿Practicamos,\n${profile.name}?',
                  style: text.displaySmall?.copyWith(height: 1.15),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                PillButton(
                  label: 'Practicar',
                  icon: Icons.mic_rounded,
                  onPressed: () => _practice(context),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _progress(context);
                  },
                  icon: const Icon(Icons.insights_rounded, size: 20),
                  label: const Text('Mi progreso'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // Reframed as a feature, not a lack: on-device AI is the headline.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 14, color: t.accent),
          const SizedBox(width: 5),
          Text(
            'En tu dispositivo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.accent,
            ),
          ),
        ],
      ),
    );
  }
}
