import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/avatars.dart';
import '../hub/hub_screen.dart';
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
        builder: (_) => HubScreen(
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

  Future<void> _edit(Profile profile) async {
    await Navigator.of(context).push<Profile>(
      MaterialPageRoute<Profile>(
        builder: (_) =>
            ProfileCreateScreen(store: widget.store, initial: profile),
      ),
    );
    if (mounted) setState(() => _profiles = widget.store.profiles());
  }

  Future<void> _delete(Profile profile) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final text = Theme.of(sheetContext).textTheme;
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Eliminar a ${profile.name}?', style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Se perderá su progreso guardado.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(true),
                        child: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
    await widget.store.deleteProfile(profile.id);
    if (mounted) setState(() => _profiles = widget.store.profiles());
  }

  Future<void> _showActions(Profile profile) async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<_ProfileAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar perfil'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ProfileAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar perfil'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ProfileAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ProfileAction.edit:
        await _edit(profile);
      case _ProfileAction.delete:
        await _delete(profile);
    }
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
                            _ProfileTile(
                              profile: p,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _open(p);
                              },
                              onLongPress: () => _showActions(p),
                            ),
                          _AddTile(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _create();
                            },
                          ),
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
  final VoidCallback onLongPress;

  const _ProfileTile({
    required this.profile,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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

enum _ProfileAction { edit, delete }
