import '../entities/paraverbal_metrics.dart';
import 'spanish_fillers.dart';

/// Turns a transcript plus a pause list into voice metrics.
///
/// Tier 0: pure arithmetic, no model, no I/O. Runs anywhere and is fully
/// unit-testable with `dart test` — no emulator, no device.
class ParaverbalAnalyzer {
  final SpanishFillers fillers;

  /// A silence at or above this reads as a break in the thread rather than a
  /// breath. 1.5 s matches the backend's pause detection.
  final Duration awkwardPauseThreshold;

  const ParaverbalAnalyzer({
    this.fillers = const SpanishFillers(),
    this.awkwardPauseThreshold = const Duration(milliseconds: 1500),
  });

  ParaverbalMetrics analyze({
    required String transcript,
    required Duration speakingDuration,
    List<Duration> pauses = const [],
    Duration? transcriptionWindow,
  }) {
    final fillerCount = fillers.totalCount(transcript);
    final totalWords = _tokens(transcript).length;

    // Fillers are not content: a child who says "este" forty times did not
    // speak forty more words, and counting them would inflate the pace.
    final contentWords = (totalWords - fillerCount).clamp(0, totalWords);

    // The transcript may only cover the first [transcriptionWindow] of speech —
    // Whisper, for instance, processes at most 30 s and discards the rest. WPM
    // and filler rate are per-minute *rates*, so the honest denominator is the
    // window the words actually came from. Dividing 30 s of words by a full
    // 60 s clip would report a wrong-low pace with the face of a real number.
    final rateDuration =
        (transcriptionWindow != null && transcriptionWindow < speakingDuration)
            ? transcriptionWindow
            : speakingDuration;
    final windowCapped = rateDuration < speakingDuration;

    final minutes = rateDuration.inMilliseconds / 60000.0;
    final wpm = minutes > 0 ? contentWords / minutes : 0.0;
    final fillerRate = minutes > 0 ? fillerCount / minutes : 0.0;

    var longest = Duration.zero;
    var awkward = 0;
    for (final pause in pauses) {
      if (pause > longest) longest = pause;
      if (pause >= awkwardPauseThreshold) awkward++;
    }

    return ParaverbalMetrics(
      wordCount: contentWords,
      fillerCount: fillerCount,
      wordsPerMinute: wpm,
      fillerRate: fillerRate,
      longestPause: longest,
      awkwardPauseCount: awkward,
      speakingDuration: speakingDuration,
      rateWindowCapped: windowCapped,
    );
  }

  List<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[.,;:!¡¿?"()\[\]]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
}
