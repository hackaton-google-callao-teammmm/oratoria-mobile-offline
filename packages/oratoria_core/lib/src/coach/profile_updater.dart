import 'dart:convert';

import '../analysis/scoring.dart';
import '../entities/body_metrics.dart';
import '../entities/paraverbal_metrics.dart';

/// Canonical strength/weakness copy for one measured dimension. Exactly one
/// of the two ever describes a dimension in the profile at a time.
class _DimensionLabels {
  final String strength;
  final String weakness;
  const _DimensionLabels(this.strength, this.weakness);
}

/// Deterministic child-profile extraction — the terminal fallback when Gemma
/// is unavailable, and the baseline [GemmaCoach] merges its own output onto.
///
/// This is what makes "conociéndote" fill in on any device: it turns the
/// exact scores [RuleBasedCoach.generate] already computes into durable
/// strengths/weaknesses, and mines the transcript for interests with a small
/// rule-based matcher. Same honesty rules as the coach — a dimension is only
/// judged when it was actually measured, and only a meaningful, trusted
/// transcript is ever mined for interests.
class ProfileUpdater {
  final Scoring scoring;

  const ProfileUpdater({this.scoring = const Scoring()});

  static const _paceLabels =
      _DimensionLabels('Habla con buen ritmo', 'Controlar la velocidad al hablar');
  static const _fillerLabels =
      _DimensionLabels('Habla claro, sin muletillas', 'Reducir las muletillas');
  static const _pauseLabels = _DimensionLabels(
    'Mantiene el hilo sin silencios largos',
    'Evitar los silencios largos',
  );
  static const _eyeContactLabels =
      _DimensionLabels('Mira al público con confianza', 'Mirar más al público');
  static const _postureLabels =
      _DimensionLabels('Se para firme al hablar', 'Mantener el cuerpo derecho');

  /// Small dictionary of topics a child might mention, matched as whole words.
  /// Keys are the literal forms searched for; values are the canonical,
  /// display-ready form saved to the profile. Accented and unaccented
  /// spellings are listed separately for readability; matching itself is
  /// accent-insensitive (see [_topicPatterns]), so either spelling resolves
  /// to the same canonical entry.
  static const _topicDictionary = <String, String>{
    'futbol': 'Fútbol',
    'fútbol': 'Fútbol',
    'dinosaurios': 'Dinosaurios',
    'videojuegos': 'Videojuegos',
    'musica': 'Música',
    'música': 'Música',
    'dibujar': 'Dibujar',
    'perros': 'Perros',
    'gatos': 'Gatos',
    'animales': 'Animales',
    'robots': 'Robots',
    'espacio': 'Espacio',
    'autos': 'Autos',
    'carros': 'Autos',
    'coches': 'Autos',
    'bailar': 'Bailar',
    'cantar': 'Cantar',
    'leer': 'Leer',
    'ciencia': 'Ciencia',
    'naturaleza': 'Naturaleza',
  };

  /// Precompiled once (not per call): normalised dictionary key -> whole-word
  /// regex, matched against an already-[normalizeForComparison]d
  /// transcript/phrase so "futbol" and "fútbol" hit the same pattern.
  static final Map<RegExp, String> _topicPatterns = () {
    final normalized = <String, String>{};
    for (final entry in _topicDictionary.entries) {
      normalized[normalizeForComparison(entry.key)] = entry.value;
    }
    return {
      for (final entry in normalized.entries)
        RegExp(r'\b' + RegExp.escape(entry.key) + r'\b'): entry.value,
    };
  }();

  static const _leadingArticles = {
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'mi',
    'mis',
  };

  /// Adverbs/fillers that mean nothing as an interest by themselves
  /// ("mucho comer caca" is noise, not a topic). Normalised forms (no
  /// accents) since comparisons always go through [normalizeForComparison].
  static const _leadingStopwords = {
    'mucho',
    'mucha',
    'muchos',
    'muchas',
    'mas',
    'tambien',
    'muy',
    'algo',
    'todo',
    'toda',
  };

  // "sintagma tras el disparador": capture up to ~4 words after the trigger;
  // the exact cap (and the clause-boundary cut) happens afterwards in
  // [_cleanCandidate].
  static final _meGusta = RegExp(
    r'\bme\s+(?:gusta|gustan|encanta|encantan)\s+((?:\S+\s+){0,3}\S+)',
    caseSensitive: false,
  );
  static final _miFavoritoEs = RegExp(
    r'\bmi\s+(?:\S+\s+){1,3}?favorit[oa]\s+es\s+((?:\S+\s+){0,3}\S+)',
    caseSensitive: false,
  );
  static final _esMiFavorito = RegExp(
    r'((?:\S+\s+){0,3}\S+)\s+es\s+mi\s+favorit[oa]\b',
    caseSensitive: false,
  );
  static final _quieroSer = RegExp(
    r'\bquiero\s+ser\s+((?:\S+\s+){0,3}\S+)',
    caseSensitive: false,
  );

  /// Cuts a captured phrase at the first clause-ending punctuation or the
  /// first coordinating/subordinating conjunction — whichever comes first —
  /// BEFORE any further cleaning/truncation happens. This must run before
  /// punctuation is stripped, otherwise the sentence boundary it marks is
  /// lost: "la ciencia. Quiero ser veterinaria" would collapse into one
  /// run-on phrase instead of stopping at "la ciencia".
  static final _clauseBoundary = RegExp(
    r'[.,;:!?¡¿()"]|\b(?:y|o|pero|porque|que)\b',
    caseSensitive: false,
  );

  static final _nonWordChars = RegExp(r'[^\wáéíóúñÁÉÍÓÚÑ ]');

  /// Folds this run's measured metrics — and, when trusted, its transcript —
  /// onto [currentJson]. Always returns a non-empty, valid JSON object
  /// string; never throws.
  String update({
    String? currentJson,
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
    String? transcript,
  }) {
    try {
      final profile = _parse(currentJson);

      final strengths = _stringList(profile['strengths']);
      final weaknesses = _stringList(profile['weaknesses']);

      // Mirrors RuleBasedCoach.generate's global short-circuit: when the run
      // was too short to mean anything, the coach refuses to judge ANY
      // dimension — not just pace/fillers — so the profile must not
      // silently disagree with the feedback the child just received by
      // crediting a 3-word run with a permanent "no pauses" strength.
      // Existing strengths/weaknesses are left exactly as they were;
      // interests have their own isMeaningful gate below.
      if (voice.isMeaningful) {
        // Pace and fillers come from the transcript, so they're judged only
        // when the STT was trusted.
        if (voiceTrusted) {
          _applyDimension(strengths, weaknesses, _paceLabels,
              scoring.paceScore(voice.wordsPerMinute));
          _applyDimension(strengths, weaknesses, _fillerLabels,
              scoring.fillerScore(voice.fillerRate));
        }
        // Pauses come from the audio VAD directly, independent of the
        // transcript, so they only need their own trust flag.
        if (pausesTrusted) {
          _applyDimension(strengths, weaknesses, _pauseLabels,
              scoring.pauseScore(voice.awkwardPauseCount));
        }
        // Body dimensions only when the camera actually saw enough frames.
        if (body.hasData) {
          _applyDimension(strengths, weaknesses, _eyeContactLabels,
              body.eyeContactRatio * 100);
          _applyDimension(strengths, weaknesses, _postureLabels,
              body.uprightRatio * 100);
        }
      }

      profile['strengths'] = strengths;
      profile['weaknesses'] = weaknesses;

      if (voiceTrusted &&
          voice.isMeaningful &&
          transcript != null &&
          transcript.trim().isNotEmpty) {
        final interests = _stringList(profile['interests']);
        _mergeInterests(interests, transcript);
        profile['interests'] = interests;
      }

      return jsonEncode(profile);
    } catch (_) {
      // Whatever went wrong, the caller must still get a valid, non-empty
      // profile back — never a thrown exception, never null/empty.
      return '{}';
    }
  }

  // ------------------------------------------------------------ dimensions

  /// Re-evaluates one dimension: both of its canonical labels are removed
  /// from both lists first — a weakness that got fixed must migrate to a
  /// strength, not linger — then the one the current score earns is
  /// re-added. A middling score earns neither, so the dimension simply goes
  /// unmentioned this round rather than keeping a stale verdict.
  void _applyDimension(
    List<String> strengths,
    List<String> weaknesses,
    _DimensionLabels labels,
    double score,
  ) {
    strengths.removeWhere(
        (s) => _ciEquals(s, labels.strength) || _ciEquals(s, labels.weakness));
    weaknesses.removeWhere(
        (s) => _ciEquals(s, labels.strength) || _ciEquals(s, labels.weakness));

    if (score >= 70) {
      _addUnique(strengths, labels.strength);
    } else if (score < 50) {
      _addUnique(weaknesses, labels.weakness);
    }
  }

  /// Case- and diacritic-insensitive equality, so "Matemáticas" and
  /// "Matematicas" — or a re-typed canonical label — are treated as the
  /// same entry.
  bool _ciEquals(String a, String b) =>
      normalizeForComparison(a) == normalizeForComparison(b);

  void _addUnique(List<String> list, String value) {
    if (list.any((e) => _ciEquals(e, value))) return;
    list.add(value);
  }

  // ------------------------------------------------------------- interests

  void _mergeInterests(List<String> interests, String transcript) {
    final found = <String>[];

    void addFound(String? candidate) {
      if (candidate == null || candidate.isEmpty) return;
      if (found.any((e) => _ciEquals(e, candidate))) return;
      found.add(candidate);
    }

    // Dictionary hits first: precise and curated, so they must not be
    // crowded out of the 6-interest cap below by noisier free-form regex
    // candidates.
    final normalizedTranscript = normalizeForComparison(transcript);
    for (final entry in _topicPatterns.entries) {
      if (entry.key.hasMatch(normalizedTranscript)) addFound(entry.value);
    }

    for (final m in _meGusta.allMatches(transcript)) {
      addFound(_cleanCandidate(m.group(1)));
    }
    for (final m in _miFavoritoEs.allMatches(transcript)) {
      addFound(_cleanCandidate(m.group(1)));
    }
    for (final m in _esMiFavorito.allMatches(transcript)) {
      addFound(_cleanCandidate(m.group(1)));
    }
    for (final m in _quieroSer.allMatches(transcript)) {
      addFound(_cleanCandidate(m.group(1)));
    }

    for (final candidate in found) {
      if (interests.length >= 6) break;
      if (interests.any((e) => _ciEquals(e, candidate))) continue;
      interests.add(candidate);
    }
  }

  /// Normalises one free-form captured phrase: cuts it at the first
  /// clause-ending punctuation or conjunction (so a regex capture that
  /// crossed a sentence/period boundary is trimmed back to just its own
  /// clause), strips remaining punctuation and drops a leading article/
  /// possessive. From there:
  /// - a candidate that collapses to nothing but a bare article/possessive
  ///   ("la", "mi"...) is noise, not an interest — discarded outright (a
  ///   truncated clause like "Mi comida favorita es la." must not become
  ///   the interest "La");
  /// - if the remaining words name a known topic, the dictionary's
  ///   canonical form wins outright (rescues e.g. "mucho futbol");
  /// - otherwise a leading filler adverb ("mucho", "también"...) discards
  ///   the whole candidate as noise;
  /// - otherwise the phrase must be 1-2 words — anything longer is more
  ///   likely a stray clause fragment than a real interest, so it is
  ///   discarded rather than blindly truncated (which used to produce
  ///   nonsense like "Futbol con mis").
  String? _cleanCandidate(String? raw) {
    if (raw == null) return null;

    final boundary = _clauseBoundary.firstMatch(raw);
    var text =
        (boundary == null ? raw : raw.substring(0, boundary.start)).trim();
    text = text.replaceAll(_nonWordChars, '').trim();
    if (text.isEmpty) return null;

    var words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return null;

    if (words.length > 1 &&
        _leadingArticles.contains(normalizeForComparison(words.first))) {
      words = words.sublist(1);
    }
    if (words.isEmpty) return null;

    // A lone article/possessive — whether it started that way or is all
    // that's left after the strip above — is not a topic by itself.
    if (words.length == 1 &&
        _leadingArticles.contains(normalizeForComparison(words.first))) {
      return null;
    }

    final dictionaryHit = _dictionaryMatchIn(words.join(' '));
    if (dictionaryHit != null) return dictionaryHit;

    if (_leadingStopwords.contains(normalizeForComparison(words.first))) {
      return null;
    }
    if (words.length > 2) return null;

    final joined = words.join(' ').toLowerCase();
    if (joined.isEmpty) return null;

    return joined[0].toUpperCase() + joined.substring(1);
  }

  String? _dictionaryMatchIn(String phrase) {
    final normalized = normalizeForComparison(phrase);
    for (final entry in _topicPatterns.entries) {
      if (entry.key.hasMatch(normalized)) return entry.value;
    }
    return null;
  }

  // ------------------------------------------------------------------ json

  Map<String, dynamic> _parse(String? currentJson) {
    if (currentJson == null || currentJson.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(currentJson);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  /// Trim, lowercase, and strip the common Spanish diacritics (á/é/í/ó/ú/ü);
  /// "ñ" is deliberately left alone since "n" would be a different word.
  ///
  /// This is the single source of truth for "same entry, different
  /// spelling" across the whole profile pipeline: every dedupe and
  /// dictionary match in this class goes through it, and it is public
  /// specifically so callers merging a profile from elsewhere (e.g.
  /// [GemmaCoach]'s union of Gemma's strengths/weaknesses/interests onto
  /// this class's output) compare with the exact same rule instead of a
  /// plain `toLowerCase()` that would let "Fútbol" and "futbol" survive as
  /// two separate chips.
  static String normalizeForComparison(String s) {
    var out = s.trim().toLowerCase();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
    };
    for (final entry in replacements.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }
}
