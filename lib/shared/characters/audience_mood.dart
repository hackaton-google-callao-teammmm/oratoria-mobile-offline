import 'dart:math' as math;

/// How a single audience face reacts to the child's live voice. Pure Dart (no
/// Flutter, no I/O) so it unit-tests device-free with synthetic energy
/// sequences — the ballistics of an animation, kept out of the domain core
/// (which stays purely pedagogical). The painter that reads it is "dumb": it
/// only draws [engage] and [boredom].
///
/// Two time-scales, because a first-order envelope physically cannot tell a
/// 0.8 s breath from 4 s of dead air (both are "input low, decaying to rest"):
///  - [engage] (E): a fast-attack / slow-decay envelope of the mic level. Rises
///    quickly when the child projects; falls slowly so a DELIBERATE PAUSE holds
///    the smile — pauses are good oratory and must never be punished.
///  - [boredom] (B): a slow accumulator that only grows after SUSTAINED dead air
///    (or mumbling), and clears over ~0.5 s of sustained projection — so a lone
///    strong syllable can't re-engage the room, but genuinely picking the speech
///    back up recovers it almost at once.
///
/// The "dead air" floor is checked against the RAW (un-gained) level, identical
/// for every personality — so a soft-spoken child is never falsely bored. A
/// [personality] only changes how easily a face SMILES ([AudiencePersonality.engageGain])
/// and how fast it gets bored once below the floor ([AudiencePersonality.boredomRate]).
class AudienceMood {
  final AudiencePersonality personality;

  AudienceMood({this.personality = AudiencePersonality.neutral});

  // --- Tunables (calibrate on the real presentation phone; the mic level is
  // `(rms * 3.2).clamp(0,1)`, so speech typically sits ~0.2–0.5). ---

  /// Envelope attack time constant (s) — how fast a face lights up.
  static const _attack = 0.12;

  /// Envelope decay time constant (s) — slow, so a pause HOLDS the smile.
  static const _decay = 1.2;

  /// Raw level below which the room reads "dead air / mumbling". Conservative
  /// on purpose (kindness floor): better to under-bore than falsely bore a shy,
  /// soft-spoken child. Identical for all personalities.
  static const _deadAirFloor = 0.12;

  /// Boredom growth per second at [AudiencePersonality.boredomRate] == 1. With
  /// the envelope decay, a neutral face reaches a clear frown ~2.5 s into dead
  /// air.
  static const _boreGrow = 0.40;

  /// Boredom clear-out per second while present — ~0.5 s to fully recover. Being
  /// gradual (not a single frame) is what forces SUSTAINED projection to win the
  /// room back rather than one stray peak.
  static const _boreReset = 2.0;

  /// A stalled frame (GC, or returning from background) can hand the ticker a
  /// huge dt and jump the boredom integrator. Clamp it so a hitch never makes a
  /// face lurch to bored on resume.
  static const _maxDt = 0.05;

  double _presence = 0; // un-gained envelope of the mic level (0..1)
  double _boredom = 0; // 0 = rapt, 1 = fully checked out

  /// Advance the mood by [dt] seconds given the current mic level [energy]
  /// (0..1). Drive this from the render ticker (regular ~16 ms frames), NOT the
  /// jittery audio-chunk callback — steady dt keeps the integrator stable and in
  /// step with what the eye sees.
  void advance(double energy, double dt) {
    dt = dt.clamp(0.0, _maxDt);
    if (dt <= 0) return;

    final level = energy.clamp(0.0, 1.0);
    // Fast up, slow down — the audio-meter envelope (drives the smile; its slow
    // decay is what lets a pause hold it).
    final tau = level > _presence ? _attack : _decay;
    _presence += (level - _presence) * (1 - math.exp(-dt / tau));

    if (level >= _deadAirFloor) {
      // Projecting RIGHT NOW → recover, but gradually: recovery is gated on the
      // RAW level (this instant), not the slow envelope, so a lone syllable only
      // nibbles at boredom while genuinely sustained projection clears it. (If
      // we gated on the envelope, one blip would prop it above the floor for
      // ~1.7 s and hand back the room for free.)
      _boredom = (_boredom - _boreReset * dt).clamp(0.0, 1.0);
    } else if (_presence < _deadAirFloor) {
      // Sustained dead air / mumbling — the slow envelope has fallen below the
      // KIND, un-gained floor too → the room drifts.
      _boredom =
          (_boredom + personality.boredomRate * _boreGrow * dt).clamp(0.0, 1.0);
    }
    // else: a BRIEF pause — raw quiet, but the envelope is still up → hold
    // steady. Good oratory pauses are never punished.
  }

  /// Engagement 0..1 — drives the smile, the bob, the warm tint. Gained by the
  /// personality: a warm face smiles with less, a tough one demands more. (A
  /// linear envelope commutes with the constant gain, so this is the same as
  /// enveloping a pre-gained input.)
  double get engage => (_presence * personality.engageGain).clamp(0.0, 1.0);

  /// Boredom 0..1 — drives the gaze drifting away and a mild frown. Ungated by
  /// gain, so the kindness floor is the same for everyone.
  double get boredom => _boredom;
}

/// A face's fixed disposition. Data, not a switch, so tests can assert the
/// PROPERTY ("more boredomRate → frowns sooner") across arbitrary values, not
/// just three presets.
class AudiencePersonality {
  /// >1 smiles with less effort, <1 demands more. Clamp-bounded so even the
  /// tough face is WINNABLE: strong sustained projection must still cross into a
  /// smile — a face that can never be pleased teaches learned helplessness.
  final double engageGain;

  /// How fast boredom accumulates once below the floor. Higher = bores first.
  final double boredomRate;

  /// Idle-bob phase offset (radians) so the row doesn't bob in lockstep — kills
  /// the "Christmas tree" effect while the room is quiet.
  final double phaseSeed;

  const AudiencePersonality({
    required this.engageGain,
    required this.boredomRate,
    required this.phaseSeed,
  });

  /// Easy to win, slow to lose — give a timid child one clearly-engaged face
  /// early ("someone IS following me"). Seated first (leftmost).
  static const warm = AudiencePersonality(
    engageGain: 1.35,
    boredomRate: 0.6,
    phaseSeed: 0.0,
  );

  static const neutral = AudiencePersonality(
    engageGain: 1.0,
    boredomRate: 1.0,
    phaseSeed: 0.6,
  );

  /// Demanding but FAIR: harder to please and quicker to drift, yet still
  /// winnable with strong, sustained projection. Never cruel.
  static const tough = AudiencePersonality(
    engageGain: 0.72,
    boredomRate: 1.55,
    phaseSeed: 1.3,
  );

  /// The row, left → right. Warm first is deliberate (early positive feedback
  /// for the anxious). Deterministic: reproducible tests, no free randomness.
  static const row = <AudiencePersonality>[warm, neutral, tough];

  /// The personality for tile [i], wrapping if there are more tiles than presets.
  static AudiencePersonality forIndex(int i) => row[i % row.length];
}
