import '../entities/body_metrics.dart';
import '../entities/coach_feedback.dart';
import '../entities/exercise.dart';
import '../entities/paraverbal_metrics.dart';

/// Tier 1 — audio to Spanish text.
///
/// Adapters: sherpa-onnx (on device), LAN host, mock (development/demo).
/// Intentionally free of Flutter and SDK types so the core stays pure.
abstract class SpeechTranscriber {
  /// False when no model is installed. Callers must degrade, not throw.
  bool get isReady;

  /// Live partial text, for the HUD and running filler counts.
  Stream<String> get partials;

  Future<void> start();

  /// Final transcript. Returns an empty string when nothing was recognised —
  /// never null, so callers stay total.
  Future<String> stop();
}

/// Tier 0 (camera) — frames to body metrics.
///
/// Deterministic vision (ML Kit), not generative AI. Adapters: ML Kit,
/// and [NullBodyLanguageAnalyzer] for audio-only practice.
abstract class BodyLanguageAnalyzer {
  /// False when there is no camera, no permission, or no platform support.
  bool get isAvailable;

  Future<void> start();

  /// Incremental aggregate, for the live HUD.
  Stream<BodyMetrics> get live;

  /// Final aggregate over the whole run.
  Future<BodyMetrics> stop();
}

/// Audio-only fallback. Reports no data rather than zeroed scores, so the
/// child is never marked down for a camera that was never on.
class NullBodyLanguageAnalyzer implements BodyLanguageAnalyzer {
  const NullBodyLanguageAnalyzer();

  @override
  bool get isAvailable => false;

  @override
  Future<void> start() async {}

  @override
  Stream<BodyMetrics> get live => const Stream.empty();

  @override
  Future<BodyMetrics> stop() async => BodyMetrics.none;
}

/// Tier 2 — metrics to prose.
///
/// Adapters: Gemma on device, LAN host, and the rule-based templates that act
/// as the terminal fallback.
///
/// Contract every adapter must honour:
/// - never throws; on failure the caller substitutes the rule-based coach
/// - always returns exactly one strength and one improvement
/// - stamps [CoachFeedback.source] truthfully
abstract class CoachFeedbackGenerator {
  /// [voiceTrusted] is false when the transcript came from the fallback rather
  /// than real STT — the coach must then NOT judge pace or fillers (they'd be
  /// derived from placeholder text). [pausesTrusted] is false when pauses were
  /// not actually measured from the audio. Honest signals only.
  ///
  /// [transcript], when the run is trusted and meaningful, lets an adapter
  /// reference what the child actually said — never a reason to change the
  /// verdict (dimensions/numbers/goal stay the rule-based coach's).
  Future<CoachFeedback> generate({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
    String? transcript,
  });

  /// Generates a dynamic initial challenge message based on the user's AI profile.
  Future<String> generateInitialChallenge(String? aiProfile);

  /// Generates coach feedback and optionally extracts an updated AI profile JSON.
  Future<(CoachFeedback feedback, String? updatedAiProfile)> generateWithProfile({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
    String? aiProfile,
    String? transcript,
  }) async {
    final feedback = await generate(
      voice: voice,
      body: body,
      exercise: exercise,
      voiceTrusted: voiceTrusted,
      pausesTrusted: pausesTrusted,
      transcript: transcript,
    );
    return (feedback, aiProfile);
  }
}
