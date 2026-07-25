import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/config/feature_flags.dart';
import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/ui/eyebrow.dart';
import '../../shared/ui/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  final LocalStore store;

  const SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _liveCaption;
  late bool _gemmaFeedback;
  late bool _personalizedExercises;

  @override
  void initState() {
    super.initState();
    _liveCaption = FeatureFlags.isLiveCaption(widget.store);
    _gemmaFeedback = FeatureFlags.isGemmaFeedback(widget.store);
    _personalizedExercises = FeatureFlags.isPersonalizedExercises(widget.store);
  }

  Future<void> _toggleFlag(String key, bool value) async {
    HapticFeedback.selectionClick();
    await widget.store.setFlag(key, value);
    setState(() {
      if (key == 'liveCaption') _liveCaption = value;
      if (key == 'gemmaFeedback') _gemmaFeedback = value;
      if (key == 'personalizedExercises') _personalizedExercises = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Configuración',
                    style: text.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Eyebrow('Ajustes & Feature Flags'),
              ),
              const SizedBox(height: 20),

              _FlagTile(
                badge: 'OFFLINE STT',
                title: 'Subtítulos en vivo',
                description:
                    'Muestra las palabras del niño en tiempo real en la pantalla de exposición usando Vosk STT.',
                value: _liveCaption,
                onChanged: (val) => _toggleFlag('liveCaption', val),
                tokens: t,
              ),
              const SizedBox(height: 14),

              _FlagTile(
                badge: 'GEMMA AI',
                title: 'Coach dinámico',
                description:
                    'Permite que Gemma reescriba la retroalimentación de Vox manteniendo los veredictos exactos.',
                value: _gemmaFeedback,
                onChanged: (val) => _toggleFlag('gemmaFeedback', val),
                tokens: t,
              ),
              const SizedBox(height: 14),

              _FlagTile(
                badge: 'PERSONALIZACIÓN',
                title: 'Retos adaptativos',
                description:
                    'Adapta los títulos y enunciados de los retos basándose en los intereses aprendidos del niño.',
                value: _personalizedExercises,
                onChanged: (val) => _toggleFlag('personalizedExercises', val),
                tokens: t,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  final String badge;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppTokens tokens;

  const _FlagTile({
    required this.badge,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(badge, color: tokens.accent),
                const SizedBox(height: 4),
                Text(title, style: text.titleLarge),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: text.bodyMedium?.copyWith(color: tokens.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeColor: tokens.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
