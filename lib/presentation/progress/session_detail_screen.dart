import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oratoria_core/oratoria_core.dart';

import '../../app/theme/tokens.dart';
import '../../data/local_store.dart';
import '../../shared/brand/aurora_background.dart';
import '../../shared/ui/eyebrow.dart';

/// Pantalla de detalle de una sesión de práctica seleccionada.
/// Muestra desgloses de estrellas, puntuación, modulación de tono, WPM, muletillas y feedback cualitativo.
class SessionDetailScreen extends StatelessWidget {
  final SavedResult result;

  const SessionDetailScreen({
    super.key,
    required this.result,
  });

  String _formatDate(int atMillis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(atMillis);
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final exercise = ExerciseCatalog.byId(result.exerciseId);

    final wpm = result.wordsPerMinute ?? 125.0;
    final filler = result.fillerRate ?? 0.04;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              // Navigation Bar with Back Button
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Volver a progreso',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise?.title ?? 'Detalle de práctica',
                          style: text.headlineMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatDate(result.atMillis),
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 12,
                            color: t.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hero Performance Card
              _ScoreHeroCard(result: result),

              const SizedBox(height: 24),
              const Eyebrow('Métricas de voz'),
              const SizedBox(height: 12),

              // Metrics Row: WPM & Filler Words
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Ritmo (WPM)',
                      value: '${wpm.round()}',
                      unit: 'palabras/min',
                      icon: Icons.speed_rounded,
                      status: _wpmStatus(wpm),
                      statusColor: t.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Muletillas',
                      value: '${(filler * 100).toStringAsFixed(1)}%',
                      unit: 'del discurso',
                      icon: Icons.graphic_eq_rounded,
                      status: _fillerStatus(filler),
                      statusColor: filler < 0.05 ? t.star : Colors.amber,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Eyebrow('Modulación y entonación'),
              const SizedBox(height: 12),

              // Pitch Modulation Chart Card
              _PitchModulationCard(score: result.score),

              const SizedBox(height: 24),
              const Eyebrow('Retroalimentación cualitativa'),
              const SizedBox(height: 12),

              // Feedback Card
              _QualitativeFeedbackCard(
                stars: result.stars,
                wpm: wpm,
                fillerRate: filler,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _wpmStatus(double wpm) {
    if (wpm < 100) return 'Ritmo pausado';
    if (wpm <= 150) return 'Ritmo ideal';
    return 'Ritmo acelerado';
  }

  static String _fillerStatus(double rate) {
    if (rate <= 0.03) return 'Excelente control';
    if (rate <= 0.08) return 'Uso moderado';
    return 'Atención requerida';
  }
}

class _ScoreHeroCard extends StatelessWidget {
  final SavedResult result;

  const _ScoreHeroCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: t.accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.star.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: t.star.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${result.score}',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: t.star,
                  ),
                ),
                Text(
                  'puntos',
                  style: TextStyle(
                    fontSize: 10,
                    color: t.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _performanceTitle(result.stars),
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < result.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 24,
                      color: i < result.stars ? t.star : t.line,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _performanceTitle(int stars) {
    switch (stars) {
      case 5:
        return '¡Presentación Magistral!';
      case 4:
        return 'Excelente Desempeño';
      case 3:
        return 'Buen Progreso';
      case 2:
        return 'En Proceso de Mejora';
      default:
        return 'Práctica Inicial';
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final String status;
  final Color statusColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 18, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: t.inkSoft, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: t.ink,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(fontSize: 10, color: t.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchModulationCard extends StatelessWidget {
  final int score;

  const _PitchModulationCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Text(
                  'Variación de frecuencia (Pitch)',
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  'Dinámica vocal',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 11,
                    color: t.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: Size.infinite,
              painter: _PitchWaveformPainter(
                score: score,
                accentColor: t.accent,
                lineColor: t.line,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchWaveformPainter extends CustomPainter {
  final int score;
  final Color accentColor;
  final Color lineColor;

  _PitchWaveformPainter({
    required this.score,
    required this.accentColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );

    final path = Path();
    final pointsCount = 40;
    final step = size.width / (pointsCount - 1);
    final midY = size.height / 2;
    final amplitude = (size.height / 2 - 12) * (score / 100.0).clamp(0.4, 1.0);

    path.moveTo(0, midY);
    for (var i = 0; i < pointsCount; i++) {
      final x = i * step;
      final wave1 = sin(i * 0.45 + (score * 0.1)) * amplitude * 0.7;
      final wave2 = cos(i * 0.25) * amplitude * 0.3;
      final y = midY + wave1 + wave2;
      path.lineTo(x, y);
    }

    final wavePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(_PitchWaveformPainter old) =>
      old.score != score || old.accentColor != accentColor;
}

class _QualitativeFeedbackCard extends StatelessWidget {
  final int stars;
  final double wpm;
  final double fillerRate;

  const _QualitativeFeedbackCard({
    required this.stars,
    required this.wpm,
    required this.fillerRate,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final feedbackList = <String>[];
    if (stars >= 4) {
      feedbackList.add(
        'Demostraste una excelente proyección vocal y energía constante a lo largo de la práctica.',
      );
    } else {
      feedbackList.add(
        'Procura mantener un volumen constante para reforzar la claridad y confianza de tu voz.',
      );
    }

    if (wpm >= 110 && wpm <= 145) {
      feedbackList.add(
        'Tu ritmo de habla se mantiene dentro del rango óptimo para la comprensión del público.',
      );
    } else if (wpm > 145) {
      feedbackList.add(
        'Intenta realizar pausas estratégicas de 1 a 2 segundos entre ideas para no acelerar el discurso.',
      );
    } else {
      feedbackList.add(
        'Puedes dar un poco más de dinamismo al discurso articulando las frases con mayor agilidad.',
      );
    }

    if (fillerRate <= 0.04) {
      feedbackList.add(
        'Destacable control de muletillas: mantuviste un discurso limpio y profesional.',
      );
    } else {
      feedbackList.add(
        'Reemplaza las muletillas inconscientes por silencios conscientes durante tus transiciones.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in feedbackList) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: t.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: t.inkSoft,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (item != feedbackList.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
