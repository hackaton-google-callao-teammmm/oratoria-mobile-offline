import 'package:flutter/material.dart';
import 'package:oratoria_core/oratoria_core.dart';

import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/ui/glass_card.dart';
import '../practice/session_screen.dart';

/// Exercise picker — reached from the hub's "Practicar". Choosing a challenge
/// starts the real session (countdown → live audience → Vox thinks → report),
/// which saves its result to the active profile.
class HomeScreen extends StatelessWidget {
  final Profile profile;
  final LocalStore store;

  const HomeScreen({super.key, required this.profile, required this.store});

  void _runPractice(BuildContext context, Exercise exercise) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScreen(
          exercise: exercise,
          profile: profile,
          store: store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    'Elige un reto',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final exercise in ExerciseCatalog.all) ...[
                _ExerciseCard(
                  exercise: exercise,
                  onTap: () => _runPractice(context, exercise),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + accent per target skill, so the list reads like a colourful set of
/// distinct challenges rather than five identical rows.
({IconData icon, Color color}) _skillStyle(TargetSkill s, AppTokens t) {
  return switch (s) {
    TargetSkill.pace => (icon: Icons.speed_rounded, color: t.accent),
    TargetSkill.fillers => (icon: Icons.air_rounded, color: const Color(0xFF2DD4BF)),
    TargetSkill.eyeContact => (icon: Icons.visibility_rounded, color: const Color(0xFF6C8CFF)),
    TargetSkill.posture => (icon: Icons.accessibility_new_rounded, color: const Color(0xFFB4761F)),
    TargetSkill.none => (icon: Icons.auto_awesome_rounded, color: const Color(0xFFA78BFA)),
  };
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final skill = _skillStyle(exercise.targetSkill, t);

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: skill.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(skill.icon, color: skill.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(exercise.title, style: text.titleLarge),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${exercise.targetDuration.inSeconds}s',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(exercise.prompt, style: text.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, size: 16, color: skill.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exercise.targetHint,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: t.inkFaint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
