import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/adapters/audio/pause_detector.dart';

const _sampleRate = 16000;

/// Builds little-endian PCM16 from a list of segments, each described by an
/// amplitude (0..1) and a duration in milliseconds. Speech is a mid-amplitude
/// tone; silence is amplitude 0.
Uint8List _pcm(List<(double amp, int ms)> segments) {
  final bytes = BytesBuilder();
  for (final (amp, ms) in segments) {
    final n = _sampleRate * ms ~/ 1000;
    for (var i = 0; i < n; i++) {
      // A tone so successive frames have stable energy.
      final s = (amp * math.sin(2 * math.pi * 220 * i / _sampleRate));
      var v = (s * 32767).round().clamp(-32768, 32767);
      if (v < 0) v += 0x10000;
      bytes.addByte(v & 0xff);
      bytes.addByte((v >> 8) & 0xff);
    }
  }
  return bytes.toBytes();
}

void main() {
  const detector = PauseDetector();

  test('a silent clip is untrusted — no pauses invented', () {
    final analysis = detector.detect(_pcm([(0.0, 6000)]));
    expect(analysis.trusted, isFalse);
    expect(analysis.pauses, isEmpty);
  });

  test('a clip too short to judge is untrusted', () {
    final analysis = detector.detect(_pcm([(0.3, 1000)]));
    expect(analysis.trusted, isFalse);
  });

  test('continuous speech with no gaps reports zero pauses but is trusted', () {
    final analysis = detector.detect(_pcm([(0.3, 6000)]));
    expect(analysis.trusted, isTrue);
    expect(analysis.pauses, isEmpty);
  });

  test('finds a single long internal pause between two speech runs', () {
    final analysis = detector.detect(_pcm([
      (0.3, 2000), // speech
      (0.0, 1500), // silence → one awkward pause
      (0.3, 2000), // speech
    ]));

    expect(analysis.trusted, isTrue);
    expect(analysis.pauses.length, 1);
    expect(
      analysis.pauses.first.inMilliseconds,
      closeTo(1500, 90), // within a frame or two of the injected gap
    );
  });

  test('ignores leading and trailing silence', () {
    final analysis = detector.detect(_pcm([
      (0.0, 2000), // lead-in silence — not a pause
      (0.3, 2000),
      (0.0, 2000), // trailing silence — not a pause
    ]));

    expect(analysis.trusted, isTrue);
    expect(analysis.pauses, isEmpty);
  });

  test('a short between-word gap is not counted as a pause', () {
    final analysis = detector.detect(_pcm([
      (0.3, 2000),
      (0.0, 300), // natural gap, below the pause threshold
      (0.3, 2000),
    ]));

    expect(analysis.trusted, isTrue);
    expect(analysis.pauses, isEmpty);
  });

  group('trimSilenceEdges (Whisper input only)', () {
    test('trims leading and trailing silence, keeps the speech', () {
      final full = _pcm([
        (0.0, 2000), // lead-in silence Whisper would hallucinate over
        (0.3, 3000), // real speech
        (0.0, 2000), // trailing silence
      ]);
      final trimmed = detector.trimSilenceEdges(full);

      expect(trimmed.length, lessThan(full.length));
      expect(trimmed, isNotEmpty);
      // ~3 s of speech + ~2×150 ms padding, well under the 7 s original.
      final ms = trimmed.lengthInBytes * 1000 ~/ (_sampleRate * 2);
      expect(ms, closeTo(3300, 250));
    });

    test('returns the ORIGINAL buffer for a near-silent clip', () {
      final silent = _pcm([(0.0, 4000)]);
      final out = detector.trimSilenceEdges(silent);
      // Anti-empty guard: identical instance, never a zero-length buffer.
      expect(identical(out, silent), isTrue);
    });

    test('returns the ORIGINAL when detected speech is below the minimum', () {
      // A 200 ms blip (< 500 ms minSpeechMs) ringed by silence must not be
      // trimmed down to almost nothing.
      final blip = _pcm([(0.0, 2000), (0.3, 200), (0.0, 2000)]);
      final out = detector.trimSilenceEdges(blip);
      expect(identical(out, blip), isTrue);
    });

    test('leaves a clip too short to analyse untouched', () {
      final tiny = _pcm([(0.3, 40)]); // < 3 frames
      final out = detector.trimSilenceEdges(tiny);
      expect(identical(out, tiny), isTrue);
    });

    test('trimmed PCM stays 16-bit aligned (even byte length)', () {
      final full = _pcm([(0.0, 1500), (0.3, 3000), (0.0, 1500)]);
      final trimmed = detector.trimSilenceEdges(full);
      expect(trimmed.lengthInBytes.isEven, isTrue);
    });
  });
}
