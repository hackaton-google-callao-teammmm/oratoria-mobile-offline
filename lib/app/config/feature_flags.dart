/// Compile-time feature flags.
///
/// With no git branches available, this file is how experimental work stays
/// isolated: a feature ships dark (flag `false`) until it is proven on the
/// target device, so the stable demo path is never affected by half-finished
/// code. The frozen release APK remains the real safety net.
abstract final class FeatureFlags {
  /// Live speech caption during EXPONIENDO — shows the child's words as they
  /// speak, via on-device Vosk streaming STT (offline).
  ///
  /// OFF by default: it must not ship until the RAM cost of running Vosk
  /// alongside a resident Gemma and the camera has been measured on the A12.
  /// The caption is purely cosmetic — it NEVER feeds the report, which stays on
  /// the final Whisper pass and the trust flags.
  static const bool liveCaption = false;

  /// Let Gemma rewrite the WORDING of the coach feedback so it stops sounding
  /// like a template. The rule-based coach still OWNS the verdict (which
  /// dimension is the strength/improvement, the numbers, the goal result) — the
  /// model only rephrases the two prose bodies. Any failure/timeout falls back
  /// to the exact rule-based text.
  ///
  /// OFF by default: it adds a second Gemma call to the "Vox piensa" beat, so
  /// its latency and RAM cost on the A12 must be measured before it ships.
  static const bool gemmaFeedback = false;
}
