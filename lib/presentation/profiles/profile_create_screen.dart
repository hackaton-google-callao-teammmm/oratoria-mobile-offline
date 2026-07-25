import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/local_store.dart';
import '../../shared/avatars.dart';

/// Crear o editar perfil — name + avatar, nothing else. Deliberately not a
/// sign-up: no password, no email. Returns the created/updated [Profile] to
/// the picker. Pass [initial] to edit an existing profile in place instead
/// of creating a new one.
class ProfileCreateScreen extends StatefulWidget {
  final LocalStore store;
  final Profile? initial;

  const ProfileCreateScreen({super.key, required this.store, this.initial});

  @override
  State<ProfileCreateScreen> createState() => _ProfileCreateScreenState();
}

class _ProfileCreateScreenState extends State<ProfileCreateScreen> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late String _avatar = widget.initial?.avatarKey ?? Avatars.first;
  bool _saving = false;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final Profile result;
    if (_editing) {
      final id = widget.initial!.id;
      await widget.store.updateProfile(id: id, name: name, avatarKey: _avatar);
      result = Profile(id: id, name: name, avatarKey: _avatar);
    } else {
      // A stable, unique id without wall-clock access: microsecond monotonic
      // tick plus the name. Good enough for a per-device profile list.
      final id = 'p_${DateTime.timestamp().microsecondsSinceEpoch}';
      result = await widget.store.addProfile(
        id: id,
        name: name,
        avatarKey: _avatar,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar perfil' : 'Tu perfil')),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Cómo te llamas?', style: text.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Tu nombre'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 28),
                Text('Elige tu avatar', style: text.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final emoji in Avatars.all)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _avatar = emoji);
                        },
                        child: AvatarBubble(
                          emoji: emoji,
                          size: 64,
                          selected: _avatar == emoji,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed:
                      _name.text.trim().isEmpty || _saving ? null : _save,
                  child: Text(_editing ? 'Guardar' : '¡Empezar!'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
