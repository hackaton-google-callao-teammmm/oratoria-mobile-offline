import 'package:flutter/material.dart';

import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/avatars.dart';
import '../shell/main_shell.dart';
import 'profile_create_screen.dart';

/// Elegir perfil (Flujo 1) — the beautiful auth-style entry, but LOCAL: no
/// password, no email, no server. Picks or creates a profile so each child on
/// a shared tablet keeps their own progress.
class ProfilePickerScreen extends StatefulWidget {
  final LocalStore store;
  final ThemeController themeController;

  const ProfilePickerScreen({
    super.key,
    required this.store,
    required this.themeController,
  });

  @override
  State<ProfilePickerScreen> createState() => _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends State<ProfilePickerScreen> {
  late List<Profile> _profiles = widget.store.profiles();

  void _open(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MainShell(
          profile: profile,
          store: widget.store,
          themeController: widget.themeController,
        ),
      ),
    );
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Profile>(
      MaterialPageRoute<Profile>(
        builder: (_) => ProfileCreateScreen(store: widget.store),
      ),
    );
    if (created == null) return;
    setState(() => _profiles = widget.store.profiles());
    if (mounted) _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Quién va a practicar?', style: text.displaySmall),
              const SizedBox(height: 24),
              Expanded(
                child: _profiles.isEmpty
                    ? _EmptyHint(onCreate: _create)
                    : GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        // Cells a touch taller than wide so the avatar + name
                        // fit without overflowing.
                        childAspectRatio: 0.82,
                        children: [
                          for (final p in _profiles)
                            _ProfileTile(profile: p, onTap: () => _open(p)),
                          _AddTile(onTap: _create),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;

  const _ProfileTile({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarBubble(emoji: profile.avatarKey, size: 76),
          const SizedBox(height: 8),
          Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: t.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: t.line, width: 1.5),
            ),
            child: Icon(Icons.add, color: t.accent, size: 34),
          ),
          const SizedBox(height: 8),
          Text('Nuevo', style: text.titleMedium),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyHint({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AvatarBubble(emoji: '🦊', size: 96),
          const SizedBox(height: 20),
          Text('Crea tu perfil para empezar', style: text.titleMedium),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onCreate,
            child: const Text('Crear mi perfil'),
          ),
        ],
      ),
    );
  }
}
