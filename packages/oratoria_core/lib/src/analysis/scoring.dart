import '../entities/body_metrics.dart';
import '../entities/paraverbal_metrics.dart';

/// Converts metrics into an internal score and the child-facing star rating.
///
/// Bands are tuned for 9–15 year olds, not for adult keynote speakers.
class Scoring {
  const Scoring();

  /// Internal 0..100. Stored for progress tracking, never shown raw.
  ///
  /// Only dimensions with real data contribute: a run with the camera off is
  /// scored on voice alone rather than being punished for missing body
  /// signals it was never asked to produce. Likewise, pace and fillers count
  /// only when the transcript is trusted ([voiceTrusted]) and pauses only when
  /// they were actually measured from the audio ([pausesTrusted]) — a failed
  /// STT must not manufacture a score.
  int score(
    ParaverbalMetrics voice, {
    BodyMetrics body = BodyMetrics.none,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
  }) {
    final parts = <double>[
      if (voiceTrusted) ...[
        paceScore(voice.wordsPerMinute),
        fillerScore(voice.fillerRate),
      ],
      if (pausesTrusted) pauseScore(voice.awkwardPauseCount),
      if (body.hasData) body.eyeContactRatio * 100,
      if (body.hasData) body.uprightRatio * 100,
    ];

    // Too little speech to judge, or no trusted signal at all. Returning a low
    // score here would tell a shy child that being brief is a failure; a
    // neutral score is honest.
    if ((voiceTrusted && !voice.isMeaningful) || parts.isEmpty) return 50;

    final total = parts.reduce((a, b) => a + b) / parts.length;
    return total.round().clamp(0, 100);
  }

  /// 110–150 wpm is the comfortable band for a child audience.
  double paceScore(double wpm) => band(wpm, 110, 150, 60, 190);

  /// Under 2 fillers/min is clean; 5+/min is where they start covering ideas.
  double fillerScore(double fillerRate) =>
      (100 - fillerRate * 12).clamp(0, 100).toDouble();

  double pauseScore(int awkwardPauses) =>
      (100 - awkwardPauses * 15).clamp(0, 100).toDouble();

  int stars(int score) => (score / 20).ceil().clamp(1, 5);

  String level(int stars) => switch (stars) {
        5 => 'Vas volando',
        4 => 'Muy bien',
        3 => 'Buen despegue',
        2 => 'Vas practicando',
        _ => 'Recién empiezas',
      };

  /// 100 inside [lo..hi]; falls linearly to 0 at [min] and [max].
  double band(double x, double lo, double hi, double min, double max) {
    if (x >= lo && x <= hi) return 100;
    if (x < lo) return (((x - min) / (lo - min)) * 100).clamp(0, 100).toDouble();
    return (((max - x) / (max - hi)) * 100).clamp(0, 100).toDouble();
  }
}
