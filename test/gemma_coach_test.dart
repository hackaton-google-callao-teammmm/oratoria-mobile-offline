import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_core/oratoria_core.dart';
import 'package:oratoria_kids/adapters/coach/gemma_coach.dart';

ParaverbalMetrics _voice({
  double wpm = 130,
  int fillerCount = 8,
  double fillerRate = 8,
  int awkwardPauses = 0,
  int wordCount = 80,
  Duration duration = const Duration(seconds: 40),
}) =>
    ParaverbalMetrics(
      wordCount: wordCount,
      fillerCount: fillerCount,
      wordsPerMinute: wpm,
      fillerRate: fillerRate,
      longestPause: Duration.zero,
      awkwardPauseCount: awkwardPauses,
      speakingDuration: duration,
    );

void main() {
  const rule = RuleBasedCoach();

  test('rephrases the bodies but keeps the rule-based verdict verbatim',
      () async {
    final base = await rule.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );

    final coach = GemmaCoach(
      rewrite: (_) async =>
          'FORTALEZA: Tu voz fluyó clarita, ¡se te entendió todo!\n'
          'MEJORA: Suelta menos "este" y tus ideas van a brillar más.',
    );
    final out = await coach.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );

    // Wording changed...
    expect(out.strengthBody, contains('clarita'));
    expect(out.improvementBody, contains('brillar'));
    expect(out.source, FeedbackSource.onDeviceLlm);
    // ...but the VERDICT (dimensions, titles, goal) is exactly the rule coach's.
    expect(out.strengthDimension, base.strengthDimension);
    expect(out.improvementDimension, base.improvementDimension);
    expect(out.strengthTitle, base.strengthTitle);
    expect(out.improvementTitle, base.improvementTitle);
    expect(out.goalMet, base.goalMet);
  });

  test('parses markdown-bolded labels cleanly, no leaked label or asterisks',
      () async {
    // The exact shape a small instruction-tuned model emits even when told not
    // to — this used to make the strength body swallow the whole MEJORA line.
    final coach = GemmaCoach(
      rewrite: (_) async =>
          '**FORTALEZA:** Tu voz fluyó clara, se te entendió todo.\n'
          '**MEJORA:** Suelta menos muletillas y tus ideas brillan más.',
    );
    final out = await coach.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );

    expect(out.source, FeedbackSource.onDeviceLlm);
    expect(out.strengthBody, 'Tu voz fluyó clara, se te entendió todo.');
    expect(out.improvementBody, 'Suelta menos muletillas y tus ideas brillan más.');
    // No leaked label or markdown into the child-facing text.
    expect(out.strengthBody, isNot(contains('MEJORA')));
    expect(out.strengthBody, isNot(contains('*')));
  });

  test('parses a reply with a preamble line', () async {
    final coach = GemmaCoach(
      rewrite: (_) async => 'Claro, aquí va:\n'
          'FORTALEZA: Hablaste con calma.\n'
          'MEJORA: Mira más al frente.',
    );
    final out = await coach.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );
    expect(out.source, FeedbackSource.onDeviceLlm);
    expect(out.strengthBody, 'Hablaste con calma.');
    expect(out.improvementBody, 'Mira más al frente.');
  });

  test('falls back when both labels collapse onto a single ambiguous line',
      () async {
    final coach = GemmaCoach(
      rewrite: (_) async => 'FORTALEZA: Bien. MEJORA: Mejor.',
    );
    final out = await coach.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );
    // Ambiguous split → rule-based, not a garbled body.
    expect(out.source, FeedbackSource.ruleBased);
  });

  test('falls back to the exact rule-based text when Gemma returns null',
      () async {
    final base = await rule.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );
    final coach = GemmaCoach(rewrite: (_) async => null);
    final out = await coach.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );

    expect(out.strengthBody, base.strengthBody);
    expect(out.improvementBody, base.improvementBody);
    expect(out.source, FeedbackSource.ruleBased);
  });

  test('falls back when the model reply is unparseable', () async {
    final coach = GemmaCoach(
      rewrite: (_) async => 'sure! here is some text without the format',
    );
    final out = await coach.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );
    expect(out.source, FeedbackSource.ruleBased);
  });

  test('never throws even if the rewrite throws', () async {
    final coach = GemmaCoach(rewrite: (_) async => throw StateError('oom'));
    final out = await coach.generate(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );
    expect(out.source, FeedbackSource.ruleBased);
  });

  test('does not call Gemma for an untrusted transcript', () async {
    var called = false;
    final coach = GemmaCoach(rewrite: (_) async {
      called = true;
      return 'FORTALEZA: x\nMEJORA: y';
    });
    await coach.generate(
      voice: _voice(),
      body: const BodyMetrics(
        eyeContactRatio: 0.9,
        smileRatio: 0.5,
        uprightRatio: 0.8,
        framesAnalyzed: 400,
      ),
      exercise: Exercise.free,
      voiceTrusted: false,
    );
    expect(called, isFalse);
  });

  test('does not call Gemma when the child barely spoke', () async {
    var called = false;
    final coach = GemmaCoach(rewrite: (_) async {
      called = true;
      return 'FORTALEZA: x\nMEJORA: y';
    });
    await coach.generate(
      voice: _voice(wordCount: 2, duration: const Duration(seconds: 2)),
      body: BodyMetrics.none,
      exercise: Exercise.free,
    );
    expect(called, isFalse);
  });

  test('generateInitialChallenge uses profile or fallback icebreaker', () async {
    final coach = GemmaCoach(rewrite: (prompt) async {
      if (prompt.contains('dinosaurio')) {
        return '¡Hola! Hablemos sobre tu dinosaurio favorito.';
      }
      return '¡Hola! ¿Cómo te llamas?';
    });

    final emptyChallenge = await coach.generateInitialChallenge(null);
    expect(emptyChallenge, contains('¿Cómo te llamas?'));

    final profileChallenge = await coach.generateInitialChallenge('{"interests":["dinosaurio"]}');
    expect(profileChallenge, contains('dinosaurio'));
  });

  test('generateWithProfile extracts updated profile JSON', () async {
    final coach = GemmaCoach(rewrite: (prompt) async {
      if (prompt.contains('FORTALEZA')) {
        return 'FORTALEZA: x\nMEJORA: y';
      }
      return '```json\n{"name":"Ana","age":"10","interests":["space"]}\n```';
    });

    final (fb, updated) = await coach.generateWithProfile(
      voice: _voice(),
      body: BodyMetrics.none,
      exercise: Exercise.free,
      aiProfile: '{}',
      transcript: 'Me gusta el espacio exterior',
    );

    expect(fb.strengthBody, isNotEmpty);
    expect(updated, contains('space'));
  });

  group('GemmaCoach — deterministic profile baseline (new contract)', () {
    // The rule-based ProfileUpdater baseline is always computed first via
    // RuleBasedCoach.generateWithProfile; Gemma may only enrich it. On any
    // failure the caller must get that baseline back — never the untouched
    // input aiProfile.
    const existingProfile = '{"interests":["dinosaurios"]}';

    test('rewrite returning null yields the deterministic baseline, not the input aiProfile',
        () async {
      final coach = GemmaCoach(rewrite: (_) async => null);

      final (_, expectedBase) = await rule.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: existingProfile,
        transcript: 'Me gusta el fútbol.',
      );
      final (_, updated) = await coach.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: existingProfile,
        transcript: 'Me gusta el fútbol.',
      );

      expect(updated, isNot(existingProfile));
      expect(jsonDecode(updated!), jsonDecode(expectedBase!));
    });

    test('rewrite throwing yields the deterministic baseline, not the input aiProfile',
        () async {
      final coach =
          GemmaCoach(rewrite: (_) async => throw StateError('model crashed'));

      final (_, expectedBase) = await rule.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: existingProfile,
        transcript: 'Me gusta el fútbol.',
      );
      final (_, updated) = await coach.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: existingProfile,
        transcript: 'Me gusta el fútbol.',
      );

      expect(updated, isNot(existingProfile));
      expect(jsonDecode(updated!), jsonDecode(expectedBase!));
    });

    test('a valid Gemma JSON reply merges its interests onto the baseline, keeping both',
        () async {
      final coach = GemmaCoach(rewrite: (prompt) async {
        if (prompt.contains('FORTALEZA')) {
          return 'FORTALEZA: x\nMEJORA: y';
        }
        return '{"interests":["Espacio"]}';
      });

      final (_, updated) = await coach.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: existingProfile,
        transcript: 'Hoy quiero hablar de otra cosa.',
      );

      final interests =
          (jsonDecode(updated!) as Map<String, dynamic>)['interests'] as List;
      // Base interest carried over from the deterministic profile...
      expect(interests, contains('dinosaurios'));
      // ...and Gemma's own addition is folded in, not swallowed.
      expect(interests, contains('Espacio'));
    });

    test('an empty transcript short-circuits to the baseline without invoking the profile rewrite',
        () async {
      var profileRewriteCalled = false;
      final coach = GemmaCoach(rewrite: (prompt) async {
        if (prompt.contains('FORTALEZA')) {
          return 'FORTALEZA: x\nMEJORA: y';
        }
        profileRewriteCalled = true;
        return '{"interests":["Espacio"]}';
      });

      final (_, expectedBase) = await rule.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: existingProfile,
      );
      final (_, updated) = await coach.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: existingProfile,
        transcript: '',
      );

      expect(jsonDecode(updated!), jsonDecode(expectedBase!));
      expect(profileRewriteCalled, isFalse);
    });
  });

  group('GemmaCoach — profile trust gates and merge cap (regression)', () {
    const existingProfile = '{"interests":["dinosaurios"]}';

    test(
        'voiceTrusted=false with a non-empty transcript never invokes the '
        'rewrite at all, and returns the deterministic baseline', () async {
      var rewriteCallCount = 0;
      final coach = GemmaCoach(rewrite: (prompt) async {
        rewriteCallCount++;
        return '{"interests":["Espacio"]}';
      });

      final expectedBase = rule.profileUpdater.update(
        currentJson: existingProfile,
        voice: _voice(),
        body: BodyMetrics.none,
        voiceTrusted: false,
        transcript: 'Me gusta el fútbol.',
      );

      final (_, updated) = await coach.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        voiceTrusted: false,
        aiProfile: existingProfile,
        transcript: 'Me gusta el fútbol.',
      );

      expect(rewriteCallCount, 0);
      expect(jsonDecode(updated!), jsonDecode(expectedBase));
    });

    test(
        'a run too short to be meaningful never invokes the rewrite either, '
        'and returns the deterministic baseline', () async {
      var rewriteCallCount = 0;
      final coach = GemmaCoach(rewrite: (prompt) async {
        rewriteCallCount++;
        return '{"interests":["Espacio"]}';
      });

      final tooShort =
          _voice(wordCount: 2, duration: const Duration(seconds: 2));
      final expectedBase = rule.profileUpdater.update(
        currentJson: existingProfile,
        voice: tooShort,
        body: BodyMetrics.none,
        transcript: 'Me gusta el fútbol.',
      );

      final (_, updated) = await coach.generateWithProfile(
        voice: tooShort,
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: existingProfile,
        transcript: 'Me gusta el fútbol.',
      );

      expect(rewriteCallCount, 0);
      expect(jsonDecode(updated!), jsonDecode(expectedBase));
    });

    test(
        'merging strengths caps the union at 6, keeping the deterministic '
        'base entries first', () async {
      // Neutral voice metrics so ProfileUpdater's own canonical strengths
      // never enter the mix — only the 4 pre-existing, non-canonical
      // strengths from aiProfile make up the base.
      final neutralVoice = _voice(wpm: 165, fillerRate: 3.5, awkwardPauses: 3);
      const profileWithFour = '{"strengths":["S1","S2","S3","S4"]}';

      final coach = GemmaCoach(rewrite: (prompt) async {
        if (prompt.contains('FORTALEZA')) return null;
        return '{"strengths":["G1","G2","G3","G4","G5"]}';
      });

      final (_, updated) = await coach.generateWithProfile(
        voice: neutralVoice,
        body: BodyMetrics.none,
        exercise: Exercise.free,
        aiProfile: profileWithFour,
        transcript: 'Cuento algo sin relación con mis fortalezas.',
      );

      final strengths =
          (jsonDecode(updated!) as Map<String, dynamic>)['strengths'] as List;
      expect(strengths.length, 6);
      expect(strengths, ['S1', 'S2', 'S3', 'S4', 'G1', 'G2']);
    });

    test(
        'merging interests dedupes accents: base "Fútbol" + Gemma "futbol" '
        'collapse to a single entry (the base one)', () async {
      // Regression: _union used to dedupe with a plain toLowerCase(), which
      // let Gemma's untidy unaccented "futbol" survive next to
      // ProfileUpdater's canonical "Fútbol" as two separate chips.
      final coach = GemmaCoach(rewrite: (prompt) async {
        if (prompt.contains('FORTALEZA')) return null;
        return '{"interests":["futbol"]}';
      });

      final (_, updated) = await coach.generateWithProfile(
        voice: _voice(),
        body: BodyMetrics.none,
        exercise: Exercise.free,
        transcript: 'Me gusta el fútbol.',
      );

      final profile = jsonDecode(updated!) as Map<String, dynamic>;
      // The deterministic base must have actually produced "Fútbol" for this
      // to be a meaningful regression check.
      expect(profile['interests'], ['Fútbol']);
    });
  });
}
