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

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: results.isEmpty
              ? _Empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                    const SizedBox(height: 16),
                    _Summary(sessions: results.length, stars: totalStars),
                    const SizedBox(height: 24),
                    const Eyebrow('Tus prácticas'),
                    const SizedBox(height: 12),
                    for (final r in results) _ResultRow(result: r),
                  ],
                ),
        ),
      ),
    );
  }
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
    final exercise = ExerciseCatalog.byId(result.exerciseId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.chip + 4),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              exercise?.title ?? 'Práctica',
              style: Theme.of(context).textTheme.titleMedium,
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

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The brand isotype instead of a generic emoji.
            Image.asset(
              dark
                  ? 'assets/brand/OratorIA-isotype-inverted-1024.png'
                  : 'assets/brand/OratorIA-isotype-1024.png',
              width: 84,
              height: 84,
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no has practicado.\n¡Tu primera práctica aparecerá aquí!',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
