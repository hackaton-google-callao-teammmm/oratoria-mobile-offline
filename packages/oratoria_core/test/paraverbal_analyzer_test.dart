import 'package:oratoria_core/oratoria_core.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = ParaverbalAnalyzer();

  group('ParaverbalAnalyzer', () {
    test('computes words per minute from content words', () {
      // 10 words in 30 s -> 20 wpm.
      final metrics = analyzer.analyze(
        transcript: 'uno dos tres cuatro cinco seis siete ocho nueve diez',
        speakingDuration: const Duration(seconds: 30),
      );

      expect(metrics.wordCount, 10);
      expect(metrics.wordsPerMinute, closeTo(20, 0.01));
    });

    test('excludes fillers from the word count', () {
      // Fillers are not content: counting them would inflate the pace and
      // reward a child for padding.
      final metrics = analyzer.analyze(
        transcript: 'hola este mundo eh bonito',
        speakingDuration: const Duration(seconds: 60),
      );

      expect(metrics.fillerCount, 2);
      expect(metrics.wordCount, 3);
      expect(metrics.wordsPerMinute, closeTo(3, 0.01));
    });

    test('computes filler rate per minute', () {
      final metrics = analyzer.analyze(
        transcript: 'este eh este mmm',
        speakingDuration: const Duration(seconds: 120),
      );

      expect(metrics.fillerCount, 4);
      expect(metrics.fillerRate, closeTo(2, 0.01));
    });

    test('flags only pauses at or above the threshold', () {
      final metrics = analyzer.analyze(
        transcript: 'hola mundo bonito grande alto',
        speakingDuration: const Duration(seconds: 30),
        pauses: const [
          Duration(milliseconds: 400),
          Duration(milliseconds: 1500), // exactly at the threshold — counts
          Duration(milliseconds: 3000),
        ],
      );

      expect(metrics.awkwardPauseCount, 2);
      expect(metrics.longestPause, const Duration(seconds: 3));
    });

    test('never divides by zero on an empty run', () {
      final metrics = analyzer.analyze(
        transcript: '',
        speakingDuration: Duration.zero,
      );

      expect(metrics.wordsPerMinute, 0);
      expect(metrics.fillerRate, 0);
      expect(metrics.isMeaningful, isFalse);
    });

    test('marks a very short run as not meaningful', () {
      final metrics = analyzer.analyze(
        transcript: 'hola',
        speakingDuration: const Duration(seconds: 2),
      );

      expect(metrics.isMeaningful, isFalse);
    });

    test('marks a normal run as meaningful', () {
      final metrics = analyzer.analyze(
        transcript: 'hola a todos hoy quiero contarles algo importante',
        speakingDuration: const Duration(seconds: 20),
      );

      expect(metrics.isMeaningful, isTrue);
    });
  });

  group('ParaverbalAnalyzer — rate window (Whisper 30 s cap)', () {
    // 30 content words that were transcribed from only the first 30 s of a
    // 60 s clip. Over the full minute the pace would read a wrong-low 30 wpm;
    // over the honest 30 s window it is 60 wpm.
    final thirtyWords =
        List.generate(30, (i) => 'palabra$i').join(' ');

    test('caps the WPM denominator to the transcription window', () {
      final metrics = analyzer.analyze(
        transcript: thirtyWords,
        speakingDuration: const Duration(seconds: 60),
        transcriptionWindow: const Duration(seconds: 30),
      );

      expect(metrics.wordCount, 30);
      expect(metrics.wordsPerMinute, closeTo(60, 0.01)); // not 30
      expect(metrics.rateWindowCapped, isTrue);
    });

    test('caps the filler rate the same way', () {
      // 4 fillers heard in the first 30 s of a 60 s clip -> 8/min, not 4/min.
      final metrics = analyzer.analyze(
        transcript: 'este eh este mmm',
        speakingDuration: const Duration(seconds: 60),
        transcriptionWindow: const Duration(seconds: 30),
      );

      expect(metrics.fillerCount, 4);
      expect(metrics.fillerRate, closeTo(8, 0.01));
      expect(metrics.rateWindowCapped, isTrue);
    });

    test('does not cap when the clip is shorter than the window', () {
      // A 20 s clip never hit Whisper's 30 s limit, so nothing is truncated.
      final metrics = analyzer.analyze(
        transcript: 'uno dos tres cuatro cinco seis siete ocho nueve diez',
        speakingDuration: const Duration(seconds: 20),
        transcriptionWindow: const Duration(seconds: 30),
      );

      expect(metrics.wordsPerMinute, closeTo(30, 0.01)); // 10 words / (20/60)
      expect(metrics.rateWindowCapped, isFalse);
    });

    test('does not cap at exactly the window boundary', () {
      final metrics = analyzer.analyze(
        transcript: 'uno dos tres cuatro cinco',
        speakingDuration: const Duration(seconds: 30),
        transcriptionWindow: const Duration(seconds: 30),
      );

      expect(metrics.rateWindowCapped, isFalse);
      expect(metrics.wordsPerMinute, closeTo(10, 0.01)); // 5 words / (30/60)
    });

    test('leaves rates unchanged and uncapped when no window is given', () {
      final metrics = analyzer.analyze(
        transcript: thirtyWords,
        speakingDuration: const Duration(seconds: 60),
      );

      expect(metrics.wordsPerMinute, closeTo(30, 0.01)); // full-clip behaviour
      expect(metrics.rateWindowCapped, isFalse);
    });
  });
}
