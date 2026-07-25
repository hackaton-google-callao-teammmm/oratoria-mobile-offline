/// Voice signals derived from a practice run.
///
/// Every field here is computed with plain arithmetic over the transcript and
/// the pause list — no model is involved. This is the Tier 0 contract: it must
/// remain constructible on the humblest device the app supports.
class ParaverbalMetrics {
  /// Words the child actually said, excluding detected fillers.
  final int wordCount;

  /// Total filler occurrences found in the transcript.
  final int fillerCount;

  /// Content words per minute of speaking time.
  final double wordsPerMinute;

  /// Fillers per minute — the rate is what matters, not the raw count:
  /// six fillers in ten seconds is a very different problem from six in
  /// three minutes.
  final double fillerRate;

  /// Longest single silence detected.
  final Duration longestPause;

  /// Silences at or above the "awkward" threshold.
  final int awkwardPauseCount;

  /// How long the child spoke.
  final Duration speakingDuration;

  /// True when [wordsPerMinute] and [fillerRate] were computed over a window
  /// shorter than [speakingDuration] — the transcript only covered the start
  /// of the clip (e.g. Whisper's 30 s cap). The rates are then honest estimates
  /// of that opening stretch, and the UI should say so rather than imply they
  /// cover the whole run.
  final bool rateWindowCapped;

  const ParaverbalMetrics({
    required this.wordCount,
    required this.fillerCount,
    required this.wordsPerMinute,
    required this.fillerRate,
    required this.longestPause,
    required this.awkwardPauseCount,
    required this.speakingDuration,
    this.rateWindowCapped = false,
  });

  /// Result of a run with no usable audio — keeps callers total.
  static const empty = ParaverbalMetrics(
    wordCount: 0,
    fillerCount: 0,
    wordsPerMinute: 0,
    fillerRate: 0,
    longestPause: Duration.zero,
    awkwardPauseCount: 0,
    speakingDuration: Duration.zero,
  );

  /// True when the child spoke long enough for the numbers to mean anything.
  ///
  /// Below this, WPM and filler rate swing wildly on a couple of words and
  /// would produce confident-sounding nonsense.
  bool get isMeaningful =>
      speakingDuration.inSeconds >= 5 && wordCount >= 5;
}
