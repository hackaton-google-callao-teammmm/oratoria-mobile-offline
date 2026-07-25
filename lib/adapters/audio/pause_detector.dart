import 'dart:math' as math;
import 'dart:typed_data';

/// Result of scanning a captured clip for long silences.
///
/// [trusted] is false when there was too little audio, or too little actual
/// speech, to judge pauses honestly — the report then hides the pauses metric
/// instead of showing a fabricated value.
class PauseAnalysis {
  final List<Duration> pauses;
  final bool trusted;

  const PauseAnalysis(this.pauses, {required this.trusted});

  static const PauseAnalysis untrusted =
      PauseAnalysis(<Duration>[], trusted: false);
}

/// Finds the long silences inside a PCM16 clip so the report can speak of real
/// pauses instead of a hardcoded value.
///
/// Deliberately cheap: one O(n) pass computing per-frame energy plus a linear
/// scan for silence runs. No FFT, no model. Runs on the UI isolate in the
/// "Vox thinks" beat, before Gemma, so it never competes with the LLM for RAM
/// or time.
class PauseDetector {
  const PauseDetector({
    this.sampleRate = 16000,
    this.frameMs = 30,
    this.minPauseMs = 900,
    this.silenceFactor = 0.15,
    this.absoluteFloor = 0.012,
    this.minClipMs = 3000,
  });

  /// Audio sample rate. The capture path records 16 kHz mono PCM16.
  final int sampleRate;

  /// Analysis window. 30 ms is short enough to place a pause edge precisely and
  /// long enough for a stable energy estimate.
  final int frameMs;

  /// A silence must last at least this long to count as a pause rather than the
  /// natural gap between words.
  final int minPauseMs;

  /// A frame quieter than [silenceFactor] of the clip's speech peak is silence.
  final double silenceFactor;

  /// Absolute RMS floor (0..1). A clip whose peak sits below roughly this level
  /// carried no real speech (a silent room), so pauses can't be judged.
  final double absoluteFloor;

  /// Clips shorter than this are too brief to read pauses from honestly.
  final int minClipMs;

  /// Scans little-endian PCM16 [pcm] for internal silence runs.
  ///
  /// Leading and trailing silence are ignored: a child who takes a breath
  /// before starting, or trails off at the end, is not marked down for it. Each
  /// returned [Duration] is one internal silence at or above [minPauseMs]; the
  /// core decides which are "awkward".
  PauseAnalysis detect(Uint8List pcm) {
    final totalSamples = pcm.lengthInBytes ~/ 2;
    final clipMs = totalSamples * 1000 ~/ sampleRate;
    if (clipMs < minClipMs) return PauseAnalysis.untrusted;

    final frameSamples = sampleRate * frameMs ~/ 1000; // 480 at 16 kHz/30 ms
    if (frameSamples == 0) return PauseAnalysis.untrusted;

    // Per-frame RMS in a single pass over the PCM bytes. Read by byte pairs
    // because chunk boundaries can leave the buffer at an odd offset.
    final frames = <double>[];
    var peak = 0.0;
    var sumSq = 0.0;
    var count = 0;
    for (var i = 0; i + 1 < pcm.lengthInBytes; i += 2) {
      var v = (pcm[i + 1] << 8) | pcm[i];
      if (v >= 0x8000) v -= 0x10000; // to signed
      final f = v / 32768.0;
      sumSq += f * f;
      if (++count == frameSamples) {
        final rms = math.sqrt(sumSq / frameSamples);
        frames.add(rms);
        if (rms > peak) peak = rms;
        sumSq = 0.0;
        count = 0;
      }
    }
    if (frames.length < 3) return PauseAnalysis.untrusted;

    // A peak below the floor means the clip carried no real speech.
    if (peak < absoluteFloor) return PauseAnalysis.untrusted;

    final threshold = math.max(absoluteFloor, peak * silenceFactor);

    // Trim leading/trailing silence: pauses only count between the first and
    // last frame that actually contained speech.
    var firstSpeech = -1;
    var lastSpeech = -1;
    for (var i = 0; i < frames.length; i++) {
      if (frames[i] >= threshold) {
        if (firstSpeech < 0) firstSpeech = i;
        lastSpeech = i;
      }
    }
    if (firstSpeech < 0) return PauseAnalysis.untrusted; // no speech at all

    final minPauseFrames = (minPauseMs / frameMs).ceil();
    final pauses = <Duration>[];
    var run = 0;
    for (var i = firstSpeech; i <= lastSpeech; i++) {
      if (frames[i] < threshold) {
        run++;
      } else {
        if (run >= minPauseFrames) {
          pauses.add(Duration(milliseconds: run * frameMs));
        }
        run = 0;
      }
    }

    return PauseAnalysis(pauses, trusted: true);
  }

  /// Returns [pcm] with only its LEADING and TRAILING silence trimmed (keeping
  /// [paddingMs] of headroom so word onsets/offsets aren't clipped), so Whisper
  /// is never fed the empty edges it hallucinates speech over. Internal audio is
  /// left intact — inner pauses are real signal and are measured separately on
  /// the original buffer.
  ///
  /// Anti-empty guard: returns the ORIGINAL buffer unchanged when there is too
  /// little detected speech ([minSpeechMs]) — a near-silent clip must never
  /// become a zero/sub-minimum buffer (Whisper on empty audio crashes or
  /// hallucinates outright). This only touches the *transcription* input; the
  /// pause VAD and the WPM denominator still use the original.
  Uint8List trimSilenceEdges(
    Uint8List pcm, {
    int paddingMs = 150,
    int minSpeechMs = 500,
  }) {
    final frameSamples = sampleRate * frameMs ~/ 1000;
    if (frameSamples == 0 || pcm.lengthInBytes < frameSamples * 2 * 3) {
      return pcm; // too short to analyse — leave it alone
    }

    // Per-frame RMS, one pass (same as detect()).
    final frames = <double>[];
    var peak = 0.0;
    var sumSq = 0.0;
    var count = 0;
    for (var i = 0; i + 1 < pcm.lengthInBytes; i += 2) {
      var v = (pcm[i + 1] << 8) | pcm[i];
      if (v >= 0x8000) v -= 0x10000;
      final f = v / 32768.0;
      sumSq += f * f;
      if (++count == frameSamples) {
        final rms = math.sqrt(sumSq / frameSamples);
        frames.add(rms);
        if (rms > peak) peak = rms;
        sumSq = 0.0;
        count = 0;
      }
    }
    if (peak < absoluteFloor) return pcm; // no real speech → don't trim to empty

    final threshold = math.max(absoluteFloor, peak * silenceFactor);
    var firstSpeech = -1;
    var lastSpeech = -1;
    for (var i = 0; i < frames.length; i++) {
      if (frames[i] >= threshold) {
        if (firstSpeech < 0) firstSpeech = i;
        lastSpeech = i;
      }
    }
    if (firstSpeech < 0) return pcm; // no speech at all → original

    // Anti-empty guard: too little speech to trim safely.
    if ((lastSpeech - firstSpeech + 1) * frameMs < minSpeechMs) return pcm;

    final padFrames = (paddingMs / frameMs).ceil();
    final startFrame = math.max(0, firstSpeech - padFrames);
    final endFrame = math.min(frames.length - 1, lastSpeech + padFrames);
    final startByte = startFrame * frameSamples * 2; // even (PCM16)
    final endByte =
        math.min(pcm.lengthInBytes, (endFrame + 1) * frameSamples * 2);
    if (startByte >= endByte) return pcm;
    // sublist() copies into a fresh buffer at offset 0, so a later
    // `.buffer.asInt16List(0, ...)` reads the right bytes.
    return pcm.sublist(startByte, endByte);
  }
}
