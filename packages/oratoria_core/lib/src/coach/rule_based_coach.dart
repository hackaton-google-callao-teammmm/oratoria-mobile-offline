import '../analysis/scoring.dart';
import '../entities/body_metrics.dart';
import '../entities/coach_feedback.dart';
import '../entities/exercise.dart';
import '../entities/paraverbal_metrics.dart';
import '../ports/ports.dart';

/// Scored dimension, used to pick the best and worst of the run.
class _Scored {
  final Dimension dimension;
  final double score;
  const _Scored(this.dimension, this.score);
}

/// Deterministic coach — the terminal fallback.
///
/// This class is what makes the whole "works on any device" claim true, so it
/// carries two hard obligations:
///
///  1. **It never throws and never returns empty.** Every branch produces a
///     strength and an improvement.
///  2. **It owns the decision, not just the prose.** When Gemma is present it
///     rewrites the *wording* of the strength and improvement this class
///     chose. If the model picked what to correct, a child would get a
///     different verdict on identical performance every run.
///
/// Text follows the O→E→E→E shape from the design doc: Observación,
/// Explicación, Ejemplo con sus palabras, Ejercicio para la próxima.
class RuleBasedCoach implements CoachFeedbackGenerator {
  final Scoring scoring;

  const RuleBasedCoach({this.scoring = const Scoring()});

  @override
  Future<CoachFeedback> generate({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
  }) async {
    // Only judge signals we actually measured. Pace and fillers come from the
    // transcript, so they're off when the STT wasn't trusted; pauses come from
    // the audio VAD. Body is included only when the camera saw enough.
    final dimensions = <_Scored>[
      if (voiceTrusted) ...[
        _Scored(Dimension.pace, scoring.paceScore(voice.wordsPerMinute)),
        _Scored(Dimension.fillers, scoring.fillerScore(voice.fillerRate)),
      ],
      if (pausesTrusted)
        _Scored(Dimension.pauses, scoring.pauseScore(voice.awkwardPauseCount)),
      if (body.hasData)
        _Scored(Dimension.eyeContact, body.eyeContactRatio * 100),
      if (body.hasData) _Scored(Dimension.posture, body.uprightRatio * 100),
    ]..sort((a, b) => b.score.compareTo(a.score));

    // Too little speech to analyse, or no trusted signal at all → encourage
    // another attempt instead of inventing a verdict.
    if (!voice.isMeaningful || dimensions.isEmpty) return _tooShort(exercise);

    final best = dimensions.first;
    final worst = dimensions.last;
    final goal = _evaluateGoal(exercise, voice, body, voiceTrusted: voiceTrusted);

    return CoachFeedback(
      strengthDimension: best.dimension,
      strengthTitle: _strengthTitle(best.dimension),
      strengthBody: _strengthBody(best.dimension, voice, body),
      improvementDimension: worst.dimension,
      improvementTitle: _improvementTitle(worst.dimension),
      improvementBody: _improvementBody(worst.dimension, voice, body),
      goalMet: goal?.$1,
      goalMessage: goal?.$2,
      source: FeedbackSource.ruleBased,
    );
  }

  @override
  Future<String> generateInitialChallenge(String? aiProfile) async {
    if (aiProfile == null || aiProfile.trim().isEmpty) {
      return '¡Hola! Soy Vox, tu entrenador de oratoria. ¿Cómo te llamas, cuántos años tienes y cuál es tu animal favorito?';
    }
    final challenges = [
      '¡Hola de nuevo! Cuéntame en voz alta cuál fue la parte más divertida de tu día.',
      '¡Hola! Si pudieras tener un superpoder por un día, ¿cuál elegirías y por qué?',
      '¡Hola! Cuéntame sobre tu juego o juguete favorito y por qué te gusta tanto.',
      '¡Hola! Platícame sobre tu comida o postre preferido como si fueras un chef.',
    ];
    final index = DateTime.now().millisecondsSinceEpoch % challenges.length;
    return challenges[index];
  }

  @override
  Future<(CoachFeedback feedback, String? updatedAiProfile)> generateWithProfile({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
    String? aiProfile,
    String? transcript,
  }) async {
    final fb = await generate(
      voice: voice,
      body: body,
      exercise: exercise,
      voiceTrusted: voiceTrusted,
      pausesTrusted: pausesTrusted,
    );
    // No real profiling without Gemma, but a null/empty profile must still
    // flip to non-empty after the first practice — otherwise
    // generateInitialChallenge() keeps taking the "first time" branch
    // forever and the child never reaches the rotating generic challenges
    // (see design.md's documented fallback behaviour).
    final profile =
        (aiProfile == null || aiProfile.trim().isEmpty) ? '{}' : aiProfile;
    return (fb, profile);
  }

  // ---------------------------------------------------------------- strengths

  String _strengthTitle(Dimension d) => switch (d) {
        Dimension.pace => 'Buen ritmo',
        Dimension.fillers => 'Hablaste limpio',
        Dimension.pauses => 'Mantuviste el hilo',
        Dimension.eyeContact => 'Miraste al público',
        Dimension.posture => 'Te paraste firme',
        Dimension.expression => 'Cara amable',
      };

  String _strengthBody(Dimension d, ParaverbalMetrics v, BodyMetrics b) =>
      switch (d) {
        Dimension.pace =>
          'Hablaste a ${v.wordsPerMinute.round()} palabras por minuto, una '
              'velocidad fácil de seguir. Cuando el ritmo es cómodo, quien te '
              'escucha entiende sin esforzarse.',
        Dimension.fillers => v.fillerCount == 0
            ? 'No usaste ninguna muletilla. Eso hace que tus ideas se escuchen '
                'claritas, sin ruido en el medio.'
            : 'Casi no usaste muletillas: solo ${v.fillerCount} en toda tu '
                'exposición. Tus ideas llegaron sin estorbos.',
        Dimension.pauses =>
          'No dejaste silencios largos. Se notó que sabías qué venía después, '
              'y eso le da confianza a quien te escucha.',
        Dimension.eyeContact =>
          'Miraste al frente el ${(b.eyeContactRatio * 100).round()}% del '
              'tiempo. Cuando miras a tu público, tu mensaje se siente dirigido '
              'a cada persona.',
        Dimension.posture =>
          'Te mantuviste derecho el ${(b.uprightRatio * 100).round()}% del '
              'tiempo. Una postura firme hace que te escuchen con más atención.',
        Dimension.expression =>
          'Tu cara se veía abierta y amable. Eso hace que quien te escucha se '
              'sienta invitado.',
      };

  // ------------------------------------------------------------- improvements

  String _improvementTitle(Dimension d) => switch (d) {
        Dimension.pace => 'Cuida el ritmo',
        Dimension.fillers => 'Menos muletillas',
        Dimension.pauses => 'Silencios largos',
        Dimension.eyeContact => 'Levanta la mirada',
        Dimension.posture => 'Endereza el cuerpo',
        Dimension.expression => 'Suelta la cara',
      };

  String _improvementBody(Dimension d, ParaverbalMetrics v, BodyMetrics b) =>
      switch (d) {
        Dimension.pace => v.wordsPerMinute > 150
            ? 'Fuiste a ${v.wordsPerMinute.round()} palabras por minuto, un '
                'poco apurado. Cuando corres, tus ideas buenas pasan sin que '
                'nadie las agarre. La próxima vez, cuenta hasta uno en silencio '
                'después de cada idea importante.'
            : 'Fuiste a ${v.wordsPerMinute.round()} palabras por minuto, un '
                'poquito lento. Si la voz avanza, la atención te sigue. Prueba '
                'contar tu idea como si le contaras algo emocionante a un amigo.',
        Dimension.fillers =>
          'Dijiste muletillas ${v.fillerCount} veces (unas '
              '${v.fillerRate.round()} por minuto). Las muletillas tapan tus '
              'ideas sin que te des cuenta. Cuando dudes, quédate en silencio un '
              'segundo: una pausa se escucha mucho mejor que un "este".',
        Dimension.pauses =>
          'Hubo ${v.awkwardPauseCount} silencios largos que cortaron el hilo. '
              'Pasa cuando no sabemos qué sigue. Antes de empezar, di en voz '
              'alta las tres cosas que vas a contar, en orden.',
        Dimension.eyeContact =>
          'Miraste al frente solo el ${(b.eyeContactRatio * 100).round()}% del '
              'tiempo; el resto miraste hacia abajo. Cuando miras al piso, tu '
              'voz también baja. Busca un punto al fondo y cuéntaselo a ese '
              'punto.',
        Dimension.posture =>
          'Estuviste encorvado buena parte del tiempo. El cuerpo derecho deja '
              'salir más aire, y con más aire la voz suena más segura. Planta '
              'los dos pies y sube el pecho antes de empezar.',
        Dimension.expression =>
          'Se te vio la cara tensa. Es normal con nervios. Antes de empezar, '
              'suelta los hombros y respira hondo dos veces.',
      };

  // -------------------------------------------------------------------- goal

  /// Compares the exercise's declared target against its band.
  /// Null when the exercise has no target, or when the camera data needed to
  /// judge it is missing.
  (bool, String)? _evaluateGoal(
    Exercise exercise,
    ParaverbalMetrics voice,
    BodyMetrics body, {
    bool voiceTrusted = true,
  }) {
    switch (exercise.targetSkill) {
      case TargetSkill.pace:
        if (!voiceTrusted) return null; // pace needs a real transcript
        final ok = voice.wordsPerMinute >= 110 && voice.wordsPerMinute <= 150;
        return (
          ok,
          ok
              ? 'El objetivo era hablar con calma — ¡lo lograste!'
              : 'El objetivo era hablar con calma. Todavía no, pero ya casi.',
        );
      case TargetSkill.fillers:
        if (!voiceTrusted) return null; // fillers need a real transcript
        final ok = voice.fillerRate < 2;
        return (
          ok,
          ok
              ? 'El objetivo era usar menos muletillas — ¡lo lograste!'
              : 'El objetivo era usar menos muletillas. Sigue intentando.',
        );
      case TargetSkill.eyeContact:
        if (!body.hasData) return null;
        final ok = body.eyeContactRatio >= 0.6;
        return (
          ok,
          ok
              ? 'El objetivo era mirar al público — ¡lo lograste!'
              : 'El objetivo era mirar al público. La próxima levanta más la '
                  'mirada.',
        );
      case TargetSkill.posture:
        if (!body.hasData) return null;
        final ok = body.uprightRatio >= 0.7;
        return (
          ok,
          ok
              ? 'El objetivo era pararte firme — ¡lo lograste!'
              : 'El objetivo era pararte firme. Sigue practicando.',
        );
      case TargetSkill.none:
        return null;
    }
  }

  CoachFeedback _tooShort(Exercise exercise) => const CoachFeedback(
        strengthDimension: Dimension.pace,
        strengthTitle: 'Te animaste',
        strengthBody:
            'Diste el primer paso, y ese siempre es el más difícil. Ya '
            'estás frente al micrófono.',
        improvementDimension: Dimension.pace,
        improvementTitle: 'Cuéntanos un poco más',
        improvementBody:
            'Hablaste muy poquito, así que todavía no puedo darte pistas '
            'útiles. Intenta de nuevo y cuéntame al menos tres cosas sobre el '
            'tema. ¡Con eso ya tengo con qué ayudarte!',
        source: FeedbackSource.ruleBased,
      );
}
