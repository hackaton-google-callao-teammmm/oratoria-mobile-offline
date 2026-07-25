/// One filler term and how many times it appeared.
class FillerHit {
  final String term;
  final int count;
  const FillerHit(this.term, this.count);
}

/// Spanish filler detection (Peruvian school bias) by pure rules.
///
/// Deliberately conservative: we would rather miss a filler than flag a
/// legitimate word. Telling a child they said "este" when they were pointing
/// at "este libro" destroys trust in every other number the app shows.
class SpanishFillers {
  static const List<String> terms = [
    'o sea',
    'como que',
    'este',
    'esteee',
    'eh',
    'ehh',
    'ehhh',
    'em',
    'emm',
    'mmm',
    'aja',
    'ajá',
    'pucha',
    'digamos',
  ];

  /// Words that turn a following "este" into a demonstrative rather than a
  /// filler ("de este modo", "en este caso"). Cheap guard, big trust win.
  static const _demonstrativeLead = {'de', 'en', 'con', 'por', 'para', 'a'};

  const SpanishFillers();

  List<FillerHit> detect(String transcript) {
    final normalized = _normalize(transcript);
    final counts = <String, int>{};

    for (final term in terms) {
      for (final match in _pattern(term).allMatches(normalized)) {
        if (term.startsWith('este') && _isDemonstrative(normalized, match)) {
          continue;
        }
        final key = _base(term);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final hits = counts.entries.map((e) => FillerHit(e.key, e.value)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return hits;
  }

  int totalCount(String transcript) =>
      detect(transcript).fold(0, (sum, hit) => sum + hit.count);

  /// The single most frequent filler, or null when there were none. The coach
  /// quotes this so the feedback is about a real word the child said.
  String? dominant(String transcript) {
    final hits = detect(transcript);
    return hits.isEmpty ? null : hits.first.term;
  }

  /// "este" preceded by a preposition is almost always a demonstrative
  /// ("de este modo"), and followed directly by a noun it usually is too.
  bool _isDemonstrative(String text, Match match) {
    final before = text.substring(0, match.start).trimRight();
    if (before.isEmpty) return false;
    final lastWord = before.split(' ').last;
    return _demonstrativeLead.contains(lastWord);
  }

  /// Collapse spelling variants so the report says "eh" once, not
  /// "eh", "ehh" and "ehhh" as three separate problems.
  String _base(String term) {
    if (term.startsWith('eh')) return 'eh';
    if (term.startsWith('este')) return 'este';
    if (term.startsWith('em')) return 'em';
    if (term == 'aja' || term == 'ajá') return 'ajá';
    return term;
  }

  RegExp _pattern(String term) {
    final escaped = RegExp.escape(term).replaceAll(r'\ ', r'\s+');
    return RegExp(
      '(?<![a-záéíóúñü])$escaped(?![a-záéíóúñü])',
      caseSensitive: false,
    );
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[.,;:!¡¿?"()\[\]]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
