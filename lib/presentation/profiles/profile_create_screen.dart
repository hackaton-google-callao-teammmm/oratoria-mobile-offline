import 'package:flutter/material.dart';

import '../../data/local_store.dart';
import '../../shared/avatars.dart';

/// Crear perfil — name + avatar, nothing else. Deliberately not a sign-up: no
/// password, no email. Returns the created [Profile] to the picker.
class ProfileCreateScreen extends StatefulWidget {
  final LocalStore store;

  const ProfileCreateScreen({super.key, required this.store});

  @override
  State<ProfileCreateScreen> createState() => _ProfileCreateScreenState();
}

class _ProfileCreateScreenState extends State<ProfileCreateScreen> {
  final _name = TextEditingController();
  String _avatar = Avatars.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    // A stable, unique id without wall-clock access: microsecond monotonic
    // tick plus the name. Good enough for a per-device profile list.
    final id = 'p_${DateTime.timestamp().microsecondsSinceEpoch}';
    final created = await widget.store.addProfile(
      id: id,
      name: name,
      avatarKey: _avatar,
    );
    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu perfil')),
      body: SafeArea(
        child: Padding(
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
                      onTap: () => setState(() => _avatar = emoji),
                      child: AvatarBubble(
                        emoji: emoji,
                        size: 64,
                        selected: _avatar == emoji,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
                child: const Text('¡Empezar!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
