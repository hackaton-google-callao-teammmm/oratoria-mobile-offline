import '../../data/local_store.dart';

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
  /// ON: shipped directly without a prior RAM measurement (same call made
  /// for [gemmaFeedback] — confirmed working on the target device, revert if
  /// real memory problems show up running Vosk + Gemma + camera together).
  /// The caption is purely cosmetic — it NEVER feeds the report, which stays on
  /// the final Whisper pass and the trust flags.
  static const bool liveCaption = true;

  /// Let Gemma rewrite the WORDING of the coach feedback so it stops sounding
  /// like a template. The rule-based coach still OWNS the verdict (which
  /// dimension is the strength/improvement, the numbers, the goal result) — the
  /// model only rephrases the two prose bodies. Any failure/timeout falls back
  /// to the exact rule-based text.
  ///
  /// ON: Gemma is confirmed working on the target device. Adds a second Gemma
  /// call to the "Vox piensa" beat (feedback rewrite) plus the initial-
  /// challenge and profile-update calls in `session_screen.dart` — all three
  /// still fall back to the exact rule-based text/behaviour on any
  /// failure/timeout, so this never costs the child their feedback.
  static const bool gemmaFeedback = true;

  /// Rewrites the title/prompt/hint of the ONE exercise
  /// `suggestNextChallenge()` recommends on the report, using the child's AI
  /// profile — so "Tu próximo reto" (and later "Elige un reto") can reflect
  /// what the child actually likes talking about. The rewrite is triggered
  /// from `ReportScreen` in the background (never blocking the report or the
  /// "Continuar" button) and only ever affects cosmetic text — `id`,
  /// `targetSkill` and `targetDuration` never change.
  ///
  /// OFF by default: separate from [gemmaFeedback] so its own latency/RAM
  /// cost (one more call to the same singleton Gemma model) can be measured
  /// and toggled independently before it ships.
  static const bool personalizedExercises = false;

  static bool isLiveCaption([LocalStore? store]) =>
      store?.getFlag('liveCaption', defaultValue: liveCaption) ?? liveCaption;

  static bool isGemmaFeedback([LocalStore? store]) =>
      store?.getFlag('gemmaFeedback', defaultValue: gemmaFeedback) ??
      gemmaFeedback;

  static bool isPersonalizedExercises([LocalStore? store]) =>
      store?.getFlag('personalizedExercises',
          defaultValue: personalizedExercises) ??
      personalizedExercises;
}
