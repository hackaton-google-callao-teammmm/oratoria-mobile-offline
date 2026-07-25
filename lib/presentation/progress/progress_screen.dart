import 'package:flutter/material.dart';
import 'package:oratoria_core/oratoria_core.dart';

import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/ui/eyebrow.dart';

/// Mi progreso (Flujo 3) — stars earned per practice, read from the local
/// store. No raw scores, no leaderboard: the focus is "I improved vs myself",
/// not a comparison with the kid at the next desk.
class ProgressScreen extends StatelessWidget {
  final Profile profile;
  final LocalStore store;

  const ProgressScreen({super.key, required this.profile, required this.store});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final results = store.resultsFor(profile.id);
    final totalStars = results.fold<int>(0, (s, r) => s + r.stars);

    // One scroll view for every state — a ListView always lays out under the
    // aurora's loose constraints, so the screen is never a blank canvas.
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Text('Mi progreso', style: text.headlineMedium),
                ],
              ),
              if (results.isEmpty) ...[
                const SizedBox(height: 72),
                _EmptyBlock(onPractice: () => Navigator.of(context).pop()),
              ] else ...[
                const SizedBox(height: 16),
                _Summary(sessions: results.length, stars: totalStars),
                const SizedBox(height: 24),
                const Eyebrow('Tus prácticas'),
                const SizedBox(height: 12),
                for (final r in results) _ResultRow(result: r),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Relative day label for a saved result ("Hoy", "Ayer", "Hace 3 días").
String _relativeDay(int atMillis) {
  final now = DateTime.now();
  final then = DateTime.fromMillisecondsSinceEpoch(atMillis);
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(then.year, then.month, then.day))
      .inDays;
  if (days <= 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  if (days < 7) return 'Hace $days días';
  if (days < 14) return 'Hace 1 semana';
  return 'Hace ${days ~/ 7} semanas';
}

class _Summary extends StatelessWidget {
  final int sessions;
  final int stars;

  const _Summary({required this.sessions, required this.stars});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // Bento: a hero "stars" cell + a supporting "practices" cell.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _Stat(
            label: 'Estrellas ganadas',
            value: '$stars',
            color: t.star,
            icon: Icons.star_rounded,
            hero: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _Stat(label: 'Prácticas', value: '$sessions', color: t.accent),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final bool hero;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(value, style: monoFigure(color: color, size: hero ? 40 : 30)),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, color: color, size: hero ? 30 : 22),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: t.inkSoft, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final SavedResult result;

  const _ResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final exercise = ExerciseCatalog.byId(result.exerciseId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise?.title ?? 'Práctica', style: text.titleMedium),
                const SizedBox(height: 2),
                // When it happened — so "Mi progreso" reads as a timeline.
                Text(
                  _relativeDay(result.atMillis),
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 11,
                    color: t.inkFaint,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < result.stars
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 20,
                color: i < result.stars ? t.star : t.line,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state — shown when the profile has no practices yet. Built from plain
/// widgets (no Image.asset, no Expanded) so it renders reliably in-list on any
/// device, and uses the theme's own display scale for a crafted, on-brand feel.
class _EmptyBlock extends StatelessWidget {
  final VoidCallback onPractice;

  const _EmptyBlock({required this.onPractice});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = AppTokens.of(context);
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: t.accent.withValues(alpha: 0.28)),
          ),
          child: Icon(Icons.mic_none_rounded, size: 46, color: t.accent),
        ),
        const SizedBox(height: 24),
        Text(
          'Aún no hay progreso',
          textAlign: TextAlign.center,
          style: text.displaySmall,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Cuando hagas tu primera práctica, aquí verás tus estrellas '
            'y cómo vas mejorando, sesión a sesión.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.inkSoft, height: 1.45),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onPractice,
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Empezar a practicar'),
        ),
      ],
    );
  }
}
