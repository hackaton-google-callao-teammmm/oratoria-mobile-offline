import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/shared/characters/audience_mood.dart';

/// Drives [m] with a constant mic [energy] for [seconds], stepping at a fixed
/// frame dt — the synthetic energy sequences the design hangs on.
void _drive(AudienceMood m, double energy, double seconds,
    {double step = 1 / 60}) {
  var t = 0.0;
  while (t < seconds) {
    m.advance(energy, step);
    t += step;
  }
}

// "Clearly" thresholds — expressed loosely so on-device tuning of the time
// constants can't break the qualitative contract.
const _smiling = 0.35; // engage above this = a visible smile
const _frowning = 0.5; // boredom above this = a visible frown

void main() {
  group('AudienceMood — pause vs dead air (the pedagogical invariant)', () {
    test('a deliberate pause holds the smile and never saddens', () {
      final m = AudienceMood(personality: AudiencePersonality.neutral);
      _drive(m, 0.8, 2.0); // project
      expect(m.engage, greaterThan(_smiling), reason: 'projecting → smiling');

      _drive(m, 0.0, 0.8); // a real speaker's breath
      expect(m.boredom, lessThan(0.1), reason: 'a short pause is not boredom');
      expect(m.engage, greaterThan(0.30), reason: 'the smile is held, not dropped');
    });

    test('sustained dead air does bore the room', () {
      final m = AudienceMood(personality: AudiencePersonality.neutral);
      _drive(m, 0.8, 2.0);
      _drive(m, 0.0, 4.0); // long silence
      expect(m.boredom, greaterThan(_frowning), reason: 'dead air → frown');
    });
  });

  group('AudienceMood — two independent time-scales', () {
    test('boredom only starts after silence is SUSTAINED (~2.5s), not at once',
        () {
      final m = AudienceMood(personality: AudiencePersonality.neutral);
      _drive(m, 0.8, 2.0);
      _drive(m, 0.0, 1.2); // still within the pause-hold window
      expect(m.boredom, lessThan(0.1), reason: 'a 1.2s gap is still a pause');
    });
  });

  group('AudienceMood — personality is a property, not a switch', () {
    test('higher boredomRate frowns sooner on identical dead air', () {
      const slow = AudiencePersonality(engageGain: 1, boredomRate: 0.5, phaseSeed: 0);
      const fast = AudiencePersonality(engageGain: 1, boredomRate: 2.0, phaseSeed: 0);
      final a = AudienceMood(personality: slow);
      final b = AudienceMood(personality: fast);

      for (final m in [a, b]) {
        _drive(m, 0.8, 2.0);
        _drive(m, 0.0, 3.0);
      }
      expect(b.boredom, greaterThan(a.boredom),
          reason: 'more boredomRate → more bored at the same moment');
    });

    test('the tough face is WINNABLE — strong sustained projection earns a smile',
        () {
      final m = AudienceMood(personality: AudiencePersonality.tough);
      _drive(m, 0.95, 2.5);
      expect(m.engage, greaterThan(_smiling),
          reason: 'demanding, but not impossible (no learned helplessness)');
    });
  });

  group('AudienceMood — the kindness floor survives every personality', () {
    test('a soft-spoken but steady speaker is never bored', () {
      // 0.16 sits just above the dead-air floor: quiet, but present.
      for (final p in AudiencePersonality.row) {
        final m = AudienceMood(personality: p);
        _drive(m, 0.16, 5.0);
        expect(m.boredom, lessThan(0.05),
            reason: 'never falsely bore a shy child (${p.boredomRate})');
      }
    });
  });

  group('AudienceMood — recovery is sustained, not gameable', () {
    test('one loud syllable barely dents boredom; sustained projection clears it',
        () {
      final m = AudienceMood(personality: AudiencePersonality.neutral);
      _drive(m, 0.0, 5.0); // fully checked out
      expect(m.boredom, greaterThan(_frowning));

      _drive(m, 0.95, 0.1); // a single stray peak
      expect(m.boredom, greaterThan(0.3), reason: 'a lone syllable cannot buy the room back');

      _drive(m, 0.0, 0.4); // the peak fades (envelope still up → holds)
      _drive(m, 0.95, 0.6); // genuinely pick the speech back up
      expect(m.boredom, lessThan(0.15), reason: 'sustained projection wins them back');
    });
  });
}
