import 'dart:convert';

import 'package:oratoria_core/oratoria_core.dart';
import 'package:test/test.dart';

void main() {
  const updater = ProfileUpdater();

  ParaverbalMetrics voice({
    double wpm = 130,
    int fillerCount = 0,
    double fillerRate = 0,
    int awkwardPauses = 0,
    Duration duration = const Duration(seconds: 40),
    int wordCount = 80,
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

  const goodBody = BodyMetrics(
    eyeContactRatio: 0.9,
    smileRatio: 0.5,
    uprightRatio: 0.8,
    framesAnalyzed: 400,
  );
  const badBody = BodyMetrics(
    eyeContactRatio: 0.1,
    smileRatio: 0.5,
    uprightRatio: 0.05,
    framesAnalyzed: 400,
  );

  Map<String, dynamic> decode(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

  List<String> stringsAt(Map<String, dynamic> profile, String key) =>
      (profile[key] as List).cast<String>();

  group('ProfileUpdater — robustness of currentJson', () {
    test('null currentJson never throws and yields a valid non-empty profile',
        () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
      );

      expect(updated, isNotEmpty);
      final profile = decode(updated);
      expect(profile, isA<Map<String, dynamic>>());
      expect(profile['strengths'], isNotEmpty);
    });

    test('a blank-string currentJson is treated the same as null', () {
      final updated = updater.update(
        currentJson: '   ',
        voice: voice(),
        body: BodyMetrics.none,
      );

      expect(updated, isNotEmpty);
      expect(decode(updated)['strengths'], isNotEmpty);
    });

    test('malformed JSON currentJson does not throw and starts a fresh profile',
        () {
      final updated = updater.update(
        currentJson: '{not valid json!!',
        voice: voice(),
        body: BodyMetrics.none,
      );

      expect(updated, isNotEmpty);
      expect(decode(updated)['strengths'], contains('Habla con buen ritmo'));
    });

    test('a JSON value that is not an object (an array) is treated as empty',
        () {
      final updated = updater.update(
        currentJson: '["not", "an", "object"]',
        voice: voice(),
        body: BodyMetrics.none,
      );

      expect(updated, isNotEmpty);
      final profile = decode(updated);
      expect(profile, isA<Map<String, dynamic>>());
      expect(profile['strengths'], contains('Habla con buen ritmo'));
    });
  });

  group('ProfileUpdater — strengths and weaknesses from real metrics', () {
    test('a clean, on-pace run earns all three voice strengths, no weaknesses',
        () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(), // wpm 130 (in-band), no fillers, no awkward pauses
        body: BodyMetrics.none,
      );

      final profile = decode(updated);
      expect(
        stringsAt(profile, 'strengths'),
        containsAll(<String>[
          'Habla con buen ritmo',
          'Habla claro, sin muletillas',
          'Mantiene el hilo sin silencios largos',
        ]),
      );
      expect(profile['weaknesses'], isEmpty);
    });

    test('bad voice metrics earn the matching weaknesses instead', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(wpm: 220, fillerRate: 10, awkwardPauses: 6),
        body: BodyMetrics.none,
      );

      final profile = decode(updated);
      expect(
        stringsAt(profile, 'weaknesses'),
        containsAll(<String>[
          'Controlar la velocidad al hablar',
          'Reducir las muletillas',
          'Evitar los silencios largos',
        ]),
      );
      expect(profile['strengths'], isEmpty);
    });

    test('good body metrics earn body strengths when the camera has enough data',
        () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: goodBody,
      );

      final profile = decode(updated);
      expect(
        stringsAt(profile, 'strengths'),
        containsAll(<String>[
          'Mira al público con confianza',
          'Se para firme al hablar',
        ]),
      );
    });

    test('bad body metrics earn body weaknesses', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: badBody,
      );

      final profile = decode(updated);
      expect(
        stringsAt(profile, 'weaknesses'),
        containsAll(<String>[
          'Mirar más al público',
          'Mantener el cuerpo derecho',
        ]),
      );
    });
  });

  group('ProfileUpdater — migration between strength and weakness', () {
    test('a stale weakness migrates to a strength once the metric improves',
        () {
      const previous = '{"weaknesses":["Controlar la velocidad al hablar"]}';
      final updated = updater.update(
        currentJson: previous,
        voice: voice(wpm: 130), // now a comfortable, in-band pace
        body: BodyMetrics.none,
      );

      final profile = decode(updated);
      expect(stringsAt(profile, 'strengths'), contains('Habla con buen ritmo'));
      expect(stringsAt(profile, 'weaknesses'),
          isNot(contains('Controlar la velocidad al hablar')));
    });

    test('a stale strength migrates to a weakness once the metric regresses',
        () {
      const previous = '{"strengths":["Habla con buen ritmo"]}';
      final updated = updater.update(
        currentJson: previous,
        voice: voice(wpm: 220), // now clearly too fast
        body: BodyMetrics.none,
      );

      final profile = decode(updated);
      expect(stringsAt(profile, 'weaknesses'),
          contains('Controlar la velocidad al hablar'));
      expect(
          stringsAt(profile, 'strengths'), isNot(contains('Habla con buen ritmo')));
    });
  });

  group('ProfileUpdater — preserves content it does not own', () {
    test('non-canonical labels (as if written by Gemma) survive a re-measure',
        () {
      const previous = '{"strengths":["Tiene una imaginación enorme"],'
          '"weaknesses":["Se pone nervioso al principio"]}';
      final updated = updater.update(
        currentJson: previous,
        voice: voice(),
        body: BodyMetrics.none,
      );

      final profile = decode(updated);
      expect(
          stringsAt(profile, 'strengths'), contains('Tiene una imaginación enorme'));
      expect(stringsAt(profile, 'weaknesses'),
          contains('Se pone nervioso al principio'));
    });

    test('unknown top-level keys are preserved untouched', () {
      const previous = '{"name":"Ana","age":"10"}';
      final updated = updater.update(
        currentJson: previous,
        voice: voice(),
        body: BodyMetrics.none,
      );

      final profile = decode(updated);
      expect(profile['name'], 'Ana');
      expect(profile['age'], '10');
    });
  });

  group('ProfileUpdater — trust gates', () {
    test('voiceTrusted=false skips pace and filler judgement entirely', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(wpm: 220, fillerRate: 10),
        body: BodyMetrics.none,
        voiceTrusted: false,
      );

      final profile = decode(updated);
      final judged = <String>[
        ...stringsAt(profile, 'strengths'),
        ...stringsAt(profile, 'weaknesses'),
      ];
      expect(judged, isNot(contains('Habla con buen ritmo')));
      expect(judged, isNot(contains('Controlar la velocidad al hablar')));
      expect(judged, isNot(contains('Habla claro, sin muletillas')));
      expect(judged, isNot(contains('Reducir las muletillas')));
    });

    test('voiceTrusted=false also skips interest mining, even with a transcript',
        () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        voiceTrusted: false,
        transcript: 'me gusta el fútbol',
      );

      final profile = decode(updated);
      expect(profile.containsKey('interests'), isFalse);
    });

    test('pausesTrusted=false skips pause judgement independent of voice trust',
        () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(awkwardPauses: 6),
        body: BodyMetrics.none,
        pausesTrusted: false,
      );

      final profile = decode(updated);
      final judged = <String>[
        ...stringsAt(profile, 'strengths'),
        ...stringsAt(profile, 'weaknesses'),
      ];
      expect(judged, isNot(contains('Evitar los silencios largos')));
      expect(judged, isNot(contains('Mantiene el hilo sin silencios largos')));
      // Voice/fillers were still trusted, so those are still judged.
      expect(judged, contains('Habla con buen ritmo'));
    });

    test('a camera with no data judges neither eyeContact nor posture', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none, // framesAnalyzed == 0
      );

      final profile = decode(updated);
      final judged = <String>[
        ...stringsAt(profile, 'strengths'),
        ...stringsAt(profile, 'weaknesses'),
      ];
      expect(judged, isNot(contains('Mira al público con confianza')));
      expect(judged, isNot(contains('Mirar más al público')));
      expect(judged, isNot(contains('Se para firme al hablar')));
      expect(judged, isNot(contains('Mantener el cuerpo derecho')));
    });
  });

  group('ProfileUpdater — interest mining patterns', () {
    test('"me gusta X y Y" is captured and cut at the conjunction', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'Me gusta el fútbol y también los videojuegos.',
      );

      expect(decode(updated)['interests'], ['Fútbol', 'Videojuegos']);
    });

    test('"mi comida favorita es X" is captured', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'Mi comida favorita es la pizza.',
      );

      expect(decode(updated)['interests'], contains('Pizza'));
    });

    test('"X es mi favorito" is captured', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'El chocolate es mi favorito.',
      );

      expect(decode(updated)['interests'], contains('Chocolate'));
    });

    test('"quiero ser X" is captured', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'Quiero ser astronauta.',
      );

      expect(decode(updated)['interests'], contains('Astronauta'));
    });

    test('accented and unaccented spellings of the same topic collapse to one',
        () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript:
            'Practico futbol todos los días, y disfruto mucho el fútbol.',
      );

      expect(decode(updated)['interests'], ['Fútbol']);
    });

    test('dedupes case-insensitively against an existing interest', () {
      const previous = '{"interests":["fútbol"]}';
      final updated = updater.update(
        currentJson: previous,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'Practico fútbol todos los días.',
      );

      // No new distinct interest — the existing casing is left as-is.
      expect(decode(updated)['interests'], ['fútbol']);
    });

    test('caps merged interests at 6, keeping existing entries first', () {
      const previous = '{"interests":["A","B","C","D","E"]}';
      final updated = updater.update(
        currentJson: previous,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'Los perros y los gatos son geniales. También los '
            'robots. Y la música me alegra mucho.',
      );

      final interests = (decode(updated)['interests'] as List).cast<String>();
      expect(interests.length, 6);
      expect(interests.sublist(0, 5), ['A', 'B', 'C', 'D', 'E']);
    });

    test('no interests are mined when the run was too short to be meaningful',
        () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(wordCount: 2, duration: const Duration(seconds: 2)),
        body: BodyMetrics.none,
        transcript: 'me gusta el fútbol',
      );

      expect(decode(updated).containsKey('interests'), isFalse);
    });
  });

  group('ProfileUpdater — regressions from the verifier/reviewer findings', () {
    test(
        'a realistic multi-clause transcript yields clean topics, never a '
        'run-on phrase across clause boundaries', () {
      // This is the exact HIGH-severity repro the verifier flagged: before
      // the clause-boundary cut ran BEFORE cleanup, "el futbol con mis
      // amigos del colegio" and "la ciencia. Quiero ser veterinaria" bled
      // into single run-on candidates like "Futbol con mis" / "Ciencia
      // quiero ser" instead of stopping at the sentence/clause boundary.
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'Hola me llamo Ana. Me gusta el futbol con mis amigos '
            'del colegio y tambien los videojuegos. Mi materia favorita es '
            'la ciencia. Quiero ser veterinaria porque me encantan los '
            'perros.',
      );

      final interests = (decode(updated)['interests'] as List).cast<String>();

      // Clean, canonical/short candidates the real implementation produces.
      expect(interests, contains('Fútbol'));
      expect(interests, contains('Videojuegos'));
      expect(interests, contains('Ciencia'));
      expect(interests, contains('Veterinaria'));
      expect(interests, contains('Perros'));

      // None of the run-on fragments the bug used to produce.
      for (final interest in interests) {
        expect(interest, isNot(contains('con mis')));
        expect(interest, isNot(matches(RegExp(r'quiero\s+ser', caseSensitive: false))));
        expect(interest.split(' ').length, lessThanOrEqualTo(2),
            reason: 'no interest should be a multi-clause run-on: "$interest"');
      }
    });

    test(
        'noisy, unrelated chatter mines no garbage interest (only a genuine '
        'dictionary hit would survive, and this transcript has none)', () {
      // "perro" here is singular; the dictionary only recognises the plural
      // "perros", so — as actually implemented — this transcript mines
      // nothing at all rather than some run-on phrase about "hermana" or
      // "comer caca".
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript:
            'me gusta mucho comer caca de perro y también odio a mi hermana',
      );

      final interests = (decode(updated)['interests'] as List).cast<String>();
      expect(interests, isEmpty);
    });

    test(
        '"mucho futbol" as a free-form candidate canonicalizes to the '
        'dictionary form instead of being discarded', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'me gusta mucho futbol',
      );

      final interests = (decode(updated)['interests'] as List).cast<String>();
      expect(interests, ['Fútbol']);
      expect(interests, isNot(contains('Mucho futbol')));
    });

    test(
        'a run too short to be meaningful judges NO dimension at all, even '
        'with pausesTrusted=true and a camera that has data', () {
      // Regression for the global short-circuit: before it existed, a
      // 2-word run could still be credited with "no awkward pauses" or good
      // eye-contact/posture strengths purely because pausesTrusted/body
      // trust flags were on, contradicting the encouragement-only feedback
      // RuleBasedCoach.generate gives for the same run.
      final updated = updater.update(
        currentJson: null,
        voice: voice(
          wordCount: 2,
          duration: const Duration(seconds: 2),
          awkwardPauses: 6, // would otherwise clearly earn a weakness
        ),
        body: const BodyMetrics(
          eyeContactRatio: 0.02, // would otherwise clearly earn a weakness
          smileRatio: 0.5,
          uprightRatio: 0.02, // would otherwise clearly earn a weakness
          framesAnalyzed: 400,
        ),
        pausesTrusted: true,
      );

      final profile = decode(updated);
      expect(profile['strengths'], isEmpty);
      expect(profile['weaknesses'], isEmpty);
    });

    test(
        'a truncated "mi comida favorita es la." never leaves a bare-article '
        'chip like "La"', () {
      // Regression: the captured phrase after "es " used to be just "la."
      // (the clause got cut off by the period), and cleaning it left the
      // lone article "la" standing in as if it were the interest itself.
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'Mi comida favorita es la.',
      );

      expect(decode(updated)['interests'], isEmpty);
    });

    test(
        'a truncated "me gusta mi." never leaves a bare-possessive chip like '
        '"Mi"', () {
      final updated = updater.update(
        currentJson: null,
        voice: voice(),
        body: BodyMetrics.none,
        transcript: 'Me gusta mi.',
      );

      expect(decode(updated)['interests'], isEmpty);
    });
  });

  group('ProfileUpdater.normalizeForComparison', () {
    test('is case- and accent-insensitive for the same word', () {
      expect(
        ProfileUpdater.normalizeForComparison('Fútbol'),
        ProfileUpdater.normalizeForComparison('futbol'),
      );
    });

    test('leaves "ñ" alone, so "año" and "ano" stay distinct words', () {
      expect(
        ProfileUpdater.normalizeForComparison('año'),
        isNot(ProfileUpdater.normalizeForComparison('ano')),
      );
    });
  });
}
