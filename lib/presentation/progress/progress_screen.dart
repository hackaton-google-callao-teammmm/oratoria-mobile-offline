import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Hidden when embedded as a tab in [MainShell]; shown when pushed standalone.
  final bool showBack;

  const ProgressScreen({
    super.key,
    required this.profile,
    required this.store,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final results = store.resultsFor(profile.id);
    final totalStars = results.fold<int>(0, (s, r) => s + r.stars);

    // One scroll view for every state — a ListView always lays out under the
    // aurora's loose constraints, so the screen is never a blank canvas.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  if (showBack) ...[
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text('Mi progreso', style: text.headlineMedium),
                ],
              ),
              if (results.isEmpty) ...[
                const SizedBox(height: 72),
                _EmptyBlock(
                  onPractice: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
              ] else ...[
                const SizedBox(height: 16),
                _Summary(sessions: results.length, stars: totalStars),
                const SizedBox(height: 24),
                const Eyebrow('Tu evolución'),
                const SizedBox(height: 12),
                _ProgressEvolutionChart(results: results),
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
    // IntrinsicHeight calculates bounded cross-axis height for Row inside ListView.
    return IntrinsicHeight(
      child: Row(
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
      ),
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

class _ResultRow extends StatefulWidget {
  final SavedResult result;

  const _ResultRow({required this.result});

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final exercise = ExerciseCatalog.byId(widget.result.exerciseId);

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: _isPressed ? 0.8 : 0.6),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: _isPressed ? t.accent.withValues(alpha: 0.5) : t.line,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: t.accent.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise?.title ?? 'Práctica', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      _relativeDay(widget.result.atMillis),
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
                    i < widget.result.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20,
                    color: i < widget.result.stars ? t.star : t.line,
                  ),
                ),
              ),
            ],
          ),
        ),
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
          onPressed: () {
            HapticFeedback.lightImpact();
            onPractice();
          },
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Empezar a practicar'),
        ),
      ],
    );
  }
}

/// Visual star evolution chart showing progress across practice sessions.
/// Designed according to Caravaggio anti-slop rules: custom painter, smooth
/// gradient area fill, tactile point feedback, and clear typography.
class _ProgressEvolutionChart extends StatefulWidget {
  final List<SavedResult> results;

  const _ProgressEvolutionChart({required this.results});

  @override
  State<_ProgressEvolutionChart> createState() =>
      _ProgressEvolutionChartState();
}

class _ProgressEvolutionChartState extends State<_ProgressEvolutionChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    // Sort results chronologically (oldest to newest) for plotting evolution
    final chronological = widget.results.reversed.toList();
    final selectedIdx = (_selectedIndex != null &&
            _selectedIndex! < chronological.length)
        ? _selectedIndex!
        : chronological.length - 1;
    final selected = chronological[selectedIdx];
    final selectedExercise = ExerciseCatalog.byId(selected.exerciseId);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Evolución de aprendizaje', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${chronological.length} ${chronological.length == 1 ? "sesión registrada" : "sesiones registradas"}',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      color: t.inkFaint,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: t.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: t.star),
                    const SizedBox(width: 4),
                    Text(
                      '${selected.stars}/5',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(details.globalPosition);
                final w = box.size.width;
                final n = chronological.length;
                if (n == 0) return;
                final step = n > 1 ? w / (n - 1) : w;
                final idx = (local.dx / step).round().clamp(0, n - 1);
                HapticFeedback.selectionClick();
                setState(() => _selectedIndex = idx);
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: _EvolutionChartPainter(
                  results: chronological,
                  selectedIndex: selectedIdx,
                  accentColor: t.accent,
                  starColor: t.star,
                  lineColor: t.line,
                  surfaceColor: t.surface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: t.surface2.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: t.inkFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${selectedExercise?.title ?? "Práctica"}: ${selected.stars} ★ (${_relativeDay(selected.atMillis)})',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      color: t.inkSoft,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _EvolutionChartPainter extends CustomPainter {
  final List<SavedResult> results;
  final int selectedIndex;
  final Color accentColor;
  final Color starColor;
  final Color lineColor;
  final Color surfaceColor;

  _EvolutionChartPainter({
    required this.results,
    required this.selectedIndex,
    required this.accentColor,
    required this.starColor,
    required this.lineColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;

    const padLeft = 16.0;
    const padRight = 16.0;
    const padTop = 16.0;
    const padBottom = 16.0;

    final chartWidth = size.width - padLeft - padRight;
    final chartHeight = size.height - padTop - padBottom;

    // Draw background horizontal grid lines (for 1, 3, 5 stars)
    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    for (var i = 0; i < 3; i++) {
      final y = padTop + (chartHeight / 2) * i;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(size.width - padRight, y),
        gridPaint,
      );
    }

    // Compute point coordinates
    final points = <Offset>[];
    final n = results.length;

    for (var i = 0; i < n; i++) {
      final x = n == 1
          ? padLeft + chartWidth / 2
          : padLeft + (i / (n - 1)) * chartWidth;
      // Map 1..5 stars to Y (5 top, 1 bottom)
      final norm = ((results[i].stars - 1) / 4.0).clamp(0.0, 1.0);
      final y = padTop + (1.0 - norm) * chartHeight;
      points.add(Offset(x, y));
    }

    // Gradient fill under the curve
    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.lineTo(points.last.dx, padTop + chartHeight);
      fillPath.lineTo(points.first.dx, padTop + chartHeight);
      fillPath.close();

      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.28),
          accentColor.withValues(alpha: 0.0),
        ],
      );

      final fillPaint = Paint()
        ..shader = fillGradient.createShader(
          Rect.fromLTWH(0, padTop, size.width, chartHeight),
        );
      canvas.drawPath(fillPath, fillPaint);

      // Stroke line
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      final linePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(linePath, linePaint);
    } else if (points.length == 1) {
      // Horizontal baseline for single point
      final baselinePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(padLeft, points[0].dy),
        Offset(size.width - padRight, points[0].dy),
        baselinePaint,
      );
    }

    // Draw data points
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final isSelected = i == selectedIndex;

      if (isSelected) {
        // Outer glow halo
        canvas.drawCircle(
          p,
          9.0,
          Paint()..color = starColor.withValues(alpha: 0.3),
        );
        // Inner circle
        canvas.drawCircle(p, 6.0, Paint()..color = starColor);
        canvas.drawCircle(
          p,
          6.0,
          Paint()
            ..color = surfaceColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      } else {
        canvas.drawCircle(p, 4.0, Paint()..color = accentColor);
        canvas.drawCircle(
          p,
          4.0,
          Paint()
            ..color = surfaceColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EvolutionChartPainter old) =>
      old.selectedIndex != selectedIndex || old.results != results;
}


