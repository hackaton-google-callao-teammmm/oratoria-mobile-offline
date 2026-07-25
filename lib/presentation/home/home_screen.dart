import 'package:flutter/material.dart';
import 'package:oratoria_core/oratoria_core.dart';

import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/ui/eyebrow.dart';
import '../../shared/ui/glass_card.dart';
import '../practice/session_screen.dart';

/// Exercise picker — reached from the hub's "Practicar". Choosing a challenge
/// starts the real session (countdown → live audience → Vox thinks → report),
/// which saves its result to the active profile.
class HomeScreen extends StatelessWidget {
  final Profile profile;
  final LocalStore store;

  /// Hidden when embedded with no route to pop back to; shown (the default)
  /// when pushed as its own route.
  final bool showBack;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.store,
    this.showBack = true,
  });

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

  /// Overlays a cached personalized title/prompt/hint onto [exercise] by id
  /// — never onto "Práctica libre", which is never rewritten. `id`,
  /// `targetSkill` and `targetDuration` always stay the original's.
  Exercise _personalize(
    Exercise exercise,
    Map<String, PersonalizedExercise> overrides,
  ) {
    if (exercise.id == 'e-libre') return exercise;
    final override = overrides[exercise.id];
    if (override == null) return exercise;
    return Exercise(
      id: exercise.id,
      title: override.title,
      prompt: override.prompt,
      targetDuration: exercise.targetDuration,
      targetSkill: exercise.targetSkill,
      targetHint: override.hint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final overrides = store.getAllPersonalizedExercises(profile.id);
    final exercises = [
      for (final e in ExerciseCatalog.all) _personalize(e, overrides),
    ];
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  if (showBack) ...[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    'Elige un reto',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Eyebrow('Tus retos · 5'),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < exercises.length; i++) ...[
                _ExerciseCard(
                  exercise: exercises[i],
                  index: i + 1,
                  onTap: () => _runPractice(context, exercises[i]),
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

/// The skill a challenge trains, as a mono eyebrow label — an editorial brand
/// device instead of a colour-coded chip. One confident accent, no rainbow.
String _skillLabel(TargetSkill s) => switch (s) {
      TargetSkill.pace => 'Ritmo',
      TargetSkill.fillers => 'Muletillas',
      TargetSkill.eyeContact => 'Mirada',
      TargetSkill.posture => 'Postura',
      TargetSkill.none => 'Libre',
    };

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final int index;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Editorial index in mono — distinguishes challenges by
              // typography, not by a colour-coded chip.
              Text(
                index.toString().padLeft(2, '0'),
                style: monoFigure(color: t.accent, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(_skillLabel(exercise.targetSkill)),
                    const SizedBox(height: 2),
                    Text(exercise.title, style: text.titleLarge),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Duration as tabular data, not a pill badge.
              Text(
                '${exercise.targetDuration.inSeconds}s',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 13,
                  color: t.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(exercise.prompt, style: text.bodyMedium),
          const SizedBox(height: 12),
          // A quiet accent rule + the hint, upright (no italic) for contrast.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 2, color: t.accent.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    exercise.targetHint,
                    style: TextStyle(fontSize: 13, color: t.inkSoft, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
