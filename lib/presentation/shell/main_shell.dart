import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme_controller.dart';
import '../../data/local_store.dart';
import '../../shared/avatars.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/characters/vox.dart';
import '../../shared/ui/liquid_glass_nav_bar.dart';
import '../hub/hub_screen.dart';
import '../home/home_screen.dart';
import '../progress/progress_screen.dart';

/// The app shell: the four main sections (Inicio · Retos · Progreso · Perfil)
/// hosted in an [IndexedStack] — so each keeps its scroll/state — with the
/// floating [LiquidGlassNavBar] on top. The active section is the lime circle.
///
/// The bar floats OVER the sections; a [MediaQuery] bottom inset makes each
/// section's own [SafeArea] keep its content clear of the bar, so nothing hides
/// behind it and the sections don't need to know the bar exists.
class MainShell extends StatefulWidget {
  final Profile profile;
  final LocalStore store;
  final ThemeController themeController;

  const MainShell({
    super.key,
    required this.profile,
    required this.store,
    required this.themeController,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _items = [
    NavItem(icon: Icons.cottage_rounded, label: 'Inicio'),
    NavItem(icon: Icons.bolt_rounded, label: 'Retos'),
    NavItem(icon: Icons.insights_rounded, label: 'Progreso'),
    NavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Reserve room at the bottom so each section's SafeArea keeps content above
    // the floating bar (bar height + its offset).
    const barReserve = 88.0;

    final sections = [
      HubScreen(
        profile: widget.profile,
        store: widget.store,
        themeController: widget.themeController,
        onPractice: () => _select(1), // "Practicar" jumps to Retos
        onProgress: () => _select(2),
      ),
      HomeScreen(profile: widget.profile, store: widget.store, showBack: false),
      ProgressScreen(
        profile: widget.profile,
        store: widget.store,
        showBack: false,
      ),
      _PerfilTab(
        profile: widget.profile,
        themeController: widget.themeController,
        onChangeProfile: () => Navigator.of(context).maybePop(),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: mq.padding.bottom + barReserve),
            ),
            child: IndexedStack(index: _index, children: sections),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 14 + mq.padding.bottom,
            child: LiquidGlassNavBar(
              items: _items,
              currentIndex: _index,
              onSelect: _select,
            ),
          ),
        ],
      ),
    );
  }
}

/// PERFIL — a quiet settings tab: who's playing, the light/dark toggle, and a
/// way back to the profile picker. Deliberately small; the real journey lives
/// in the other three tabs.
class _PerfilTab extends StatelessWidget {
  final Profile profile;
  final ThemeController themeController;
  final VoidCallback onChangeProfile;

  const _PerfilTab({
    required this.profile,
    required this.themeController,
    required this.onChangeProfile,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Perfil', style: text.headlineMedium),
                const SizedBox(height: 28),
                Row(
                  children: [
                    AvatarBubble(emoji: profile.avatarKey, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        profile.name,
                        style: text.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Spacer(),
                const Center(child: Vox(mood: VoxMood.idle, size: 96)),
                const Spacer(),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeController,
                  builder: (context, mode, _) => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      themeController.isDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                    ),
                    title: const Text('Modo oscuro'),
                    value: themeController.isDark,
                    onChanged: (_) {
                      HapticFeedback.selectionClick();
                      themeController.toggle();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onChangeProfile();
                  },
                  icon: const Icon(Icons.switch_account_rounded, size: 20),
                  label: const Text('Cambiar perfil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
