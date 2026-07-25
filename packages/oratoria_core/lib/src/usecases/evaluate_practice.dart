import '../analysis/paraverbal_analyzer.dart';
import '../analysis/scoring.dart';
import '../coach/rule_based_coach.dart';
import '../entities/body_metrics.dart';
import '../entities/coach_feedback.dart';
import '../entities/exercise.dart';
import '../entities/paraverbal_metrics.dart';
import '../entities/practice_result.dart';
import '../ports/ports.dart';

/// Turns one finished practice run into a [PracticeResult].
///
/// Knows only ports. It never learns whether the transcript came from
/// sherpa-onnx or a LAN host, nor whether the prose came from Gemma or
/// templates — that binding happens in the composition root.
class EvaluatePractice {
  final ParaverbalAnalyzer analyzer;
  final Scoring scoring;

  /// Whatever the capability resolver selected.
  final CoachFeedbackGenerator coach;

  /// Always present, always the last resort.
  final RuleBasedCoach fallbackCoach;

  EvaluatePractice({
    required this.coach,
    this.analyzer = const ParaverbalAnalyzer(),
    this.scoring = const Scoring(),
    this.fallbackCoach = const RuleBasedCoach(),
  });

  /// [transcriptTrusted] is false when [transcript] is the sample fallback
  /// rather than real STT output — pace and fillers are then neither scored nor
  /// reported. [pausesTrusted] is false when [pauses] were not measured from
  /// the audio. [transcriptionWindow], when set, caps the per-minute rate
  /// denominator to the stretch the transcript actually covers (e.g. Whisper's
  /// 30 s limit), so pace isn't dragged low by words the STT never saw. The
  /// golden rule: honest signals only, never invented ones.
  Future<PracticeResult> call({
    required String transcript,
    required Duration speakingDuration,
    List<Duration> pauses = const [],
    BodyMetrics body = BodyMetrics.none,
    Exercise exercise = Exercise.free,
    bool transcriptTrusted = true,
    bool pausesTrusted = true,
    Duration? transcriptionWindow,
  }) async {
    final voice = analyzer.analyze(
      transcript: transcript,
      speakingDuration: speakingDuration,
      pauses: pauses,
      transcriptionWindow: transcriptionWindow,
    );

    final score = scoring.score(
      voice,
      body: body,
      voiceTrusted: transcriptTrusted,
      pausesTrusted: pausesTrusted,
    );
    final stars = scoring.stars(score);

    // The selected coach may be an on-device model that runs out of memory or
    // a LAN host that vanished mid-session. Neither is allowed to cost the
    // child their feedback, so we always have the templates behind us.
    final feedback = await _generateFeedback(
      voice,
      body,
      exercise,
      transcriptTrusted,
      pausesTrusted,
    );

    return PracticeResult(
      exercise: exercise,
      voice: voice,
      body: body,
      feedback: feedback,
      score: score,
      stars: stars,
      levelLabel: scoring.level(stars),
      voiceTextTrusted: transcriptTrusted,
      pausesTrusted: pausesTrusted,
      transcript: transcript,
    );
  }

  Future<CoachFeedback> _generateFeedback(
    ParaverbalMetrics voice,
    BodyMetrics body,
    Exercise exercise,
    bool voiceTrusted,
    bool pausesTrusted,
  ) async {
    try {
      return await coach.generate(
        voice: voice,
        body: body,
        exercise: exercise,
        voiceTrusted: voiceTrusted,
        pausesTrusted: pausesTrusted,
      );
    } catch (_) {
      return fallbackCoach.generate(
        voice: voice,
        body: body,
        exercise: exercise,
        voiceTrusted: voiceTrusted,
        pausesTrusted: pausesTrusted,
      );
    }
  }
}
