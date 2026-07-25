/// Body-language signals aggregated from camera frames.
///
/// These are deliberately *proxies*, not psychometric measurements:
/// "eye contact" is really "head oriented towards the camera", read from face
/// landmark angles. That is honest enough for formative feedback to a child,
/// and the wording in the report must never overstate it.
///
/// Lives in the core (not the ML Kit adapter) so the pure domain can reason
/// about body language without depending on Flutter or any vision SDK.
class BodyMetrics {
  /// Fraction of analysed frames where the face pointed at the camera (0..1).
  final double eyeContactRatio;

  /// Fraction of analysed frames showing an open, smiling expression (0..1).
  final double smileRatio;

  /// Fraction of analysed frames with an upright posture (0..1).
  final double uprightRatio;

  /// How many frames actually contributed. Zero means the camera was off,
  /// denied, or unsupported — never "the child did badly".
  final int framesAnalyzed;

  const BodyMetrics({
    required this.eyeContactRatio,
    required this.smileRatio,
    required this.uprightRatio,
    required this.framesAnalyzed,
  });

  /// Audio-only practice: no camera, no judgement.
  static const none = BodyMetrics(
    eyeContactRatio: 0,
    smileRatio: 0,
    uprightRatio: 0,
    framesAnalyzed: 0,
  );

  /// Whether there is enough camera data to say anything at all.
  ///
  /// The threshold guards against a camera that opened for a fraction of a
  /// second: a ratio built from three frames is noise, and feeding it to the
  /// coach would produce a confident and wrong "no miraste al público".
  bool get hasData => framesAnalyzed >= 30;
}
