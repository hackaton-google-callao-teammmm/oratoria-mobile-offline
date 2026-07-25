import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/tokens.dart';
import '../../../data/local_store.dart';
import '../../../shared/avatars.dart';
import '../../../shared/characters/vox.dart';
import '../../../shared/ui/eyebrow.dart';
import '../../../shared/ui/glass_card.dart';

/// A Caravaggio-style bottom sheet showing the child's profile info and the
/// insights Vox has learned about them across practice sessions.
class ProfileSheet extends StatelessWidget {
  final Profile profile;
  final LocalStore store;
  final VoidCallback onSwitchProfile;

  const ProfileSheet({
    super.key,
    required this.profile,
    required this.store,
    required this.onSwitchProfile,
  });

  static Future<void> show({
    required BuildContext context,
    required Profile profile,
    required LocalStore store,
    required VoidCallback onSwitchProfile,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileSheet(
        profile: profile,
        store: store,
        onSwitchProfile: onSwitchProfile,
      ),
    );
  }

  ({List<String> interests, List<String> strengths, List<String> weaknesses})
      _parseProfile() {
    final raw = store.getAiProfile(profile.id);
    if (raw == null || raw.trim().isEmpty) {
      return (interests: const [], strengths: const [], weaknesses: const []);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final interests = (decoded['interests'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [];
        final strengths = (decoded['strengths'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [];
        final weaknesses = (decoded['weaknesses'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [];
        return (interests: interests, strengths: strengths, weaknesses: weaknesses);
      }
    } catch (_) {}
    return (interests: const [], strengths: const [], weaknesses: const []);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final parsed = _parseProfile();
    final hasInsights = parsed.interests.isNotEmpty ||
        parsed.strengths.isNotEmpty ||
        parsed.weaknesses.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: t.line, width: 1),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.inkFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Profile Header
            Row(
              children: [
                AvatarHero(
                  tag: 'sheet_${profile.id}',
                  emoji: profile.avatarKey,
                  size: 56,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Perfil de Oratoria'),
                      const SizedBox(height: 2),
                      Text(profile.name, style: text.headlineSmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (hasInsights) ...[
              if (parsed.interests.isNotEmpty) ...[
                const Eyebrow('Lo que le gusta a Vox de ti'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in parsed.interests)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: t.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: t.accent),
                            const SizedBox(width: 6),
                            Text(
                              item,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (parsed.strengths.isNotEmpty) ...[
                const Eyebrow('Tus superpoderes'),
                const SizedBox(height: 8),
                for (final str in parsed.strengths) ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: t.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          str,
                          style: text.bodyMedium?.copyWith(color: t.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 16),
              ],
              if (parsed.weaknesses.isNotEmpty) ...[
                const Eyebrow('Puntos por conquistar'),
                const SizedBox(height: 8),
                for (final w in parsed.weaknesses) ...[
                  Row(
                    children: [
                      Icon(Icons.flag_rounded,
                          size: 18, color: t.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          w,
                          style: text.bodyMedium?.copyWith(color: t.inkSoft),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 16),
              ],
            ] else ...[
              // Empty State
              GlassCard(
                child: Row(
                  children: [
                    const Vox(mood: VoxMood.greeting, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Aún estamos conociéndote!',
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Realiza tu primera práctica para que Vox descubra tus fortalezas e intereses.',
                            style: text.bodySmall?.copyWith(color: t.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Switch Profile Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onSwitchProfile();
              },
              icon: const Icon(Icons.switch_account_rounded, size: 20),
              label: const Text('Cambiar de perfil'),
            ),
          ],
        ),
      ),
    );
  }
}
