import 'package:oratoria_core/oratoria_core.dart';

/// What this device can actually do, probed once at startup.
///
/// Downgrades are permanent for the session on purpose: swapping the coach
/// mid-session would produce two reports scored by different engines, and a
/// child comparing them would be comparing noise.
class Capabilities {
  /// Tier 1 — an STT model is installed and loadable.
  final bool canTranscribe;

  /// Tier 0 (camera) — a camera exists and permission was granted.
  final bool canSeeBody;

  /// Tier 2 — an on-device LLM is downloaded and the device has the headroom.
  final bool canRunLlm;

  /// Tier 2 (remote) — a LAN host answered the probe.
  final bool hasLanHost;

  const Capabilities({
    required this.canTranscribe,
    required this.canSeeBody,
    required this.canRunLlm,
    required this.hasLanHost,
  });

  /// The floor: metrics and templates only. Always achievable — this is the
  /// configuration the app must remain useful in.
  static const minimal = Capabilities(
    canTranscribe: false,
    canSeeBody: false,
    canRunLlm: false,
    hasLanHost: false,
  );

  /// Which engine will write the prose, given what is available.
  FeedbackSource get feedbackSource {
    if (canRunLlm) return FeedbackSource.onDeviceLlm;
    if (hasLanHost) return FeedbackSource.remoteLlm;
    return FeedbackSource.ruleBased;
  }

  /// Child-facing badge text. Never phrased as a failure — a device without a
  /// model is normal, not broken.
  String get modeLabel => switch (feedbackSource) {
        FeedbackSource.onDeviceLlm => 'Modo completo · sin conexión',
        FeedbackSource.remoteLlm => 'Modo aula · red local',
        FeedbackSource.ruleBased => 'Modo básico · sin conexión',
      };
}

/// Probes the device once and reports what is available.
///
/// Phase 1 answers "nothing beyond Tier 0", which is correct: no models ship
/// yet. Each later phase fills in one probe without touching callers.
class CapabilityResolver {
  const CapabilityResolver();

  Future<Capabilities> resolve() async {
    // Phase 2: check the STT asset pack is unpacked and loadable.
    // Phase 3: check camera availability and permission.
    // Phase 4: probe free RAM, then whether the Gemma model was downloaded;
    //          ping the LAN host with a 300 ms budget.
    return Capabilities.minimal;
  }
}
