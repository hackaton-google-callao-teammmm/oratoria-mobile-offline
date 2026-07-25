import 'package:oratoria_core/oratoria_core.dart';

import 'gemma_service.dart';

/// Produces the audience's follow-up question — the wow: an on-device AI that
/// listened and asks the child to keep talking.
///
/// Gemma writes the question from the exercise TOPIC (not the transcript), so
/// it still works when STT fails or is absent (golden rule). Every path has a
/// fallback: if Gemma is unavailable or slow, a hand-written question bank per
/// topic stands in, and the child never notices a broken beat.
class AudienceQuestion {
  final GemmaService gemma;

  const AudienceQuestion({required this.gemma});

  Future<AskedQuestion> forExercise(Exercise exercise) async {
    final topic = _topicOf(exercise);

    final prompt =
        'Eres un niño curioso del público. El expositor habló sobre: $topic. '
        'Hazle UNA pregunta corta y amable en español para que siga hablando. '
        'Máximo 12 palabras. Solo la pregunta, sin comillas.';

    final raw = await gemma.ask(prompt, maxTokens: 48);
    final cleaned = _clean(raw);

    if (cleaned != null) {
      return AskedQuestion(text: cleaned, source: QuestionSource.gemma);
    }
    return AskedQuestion(
      text: _bank(exercise),
      source: QuestionSource.bank,
    );
  }

  /// The exercise's subject in words Gemma can prompt on.
  String _topicOf(Exercise e) => switch (e.id) {
        'e-presentate' => 'quién es y qué le gusta hacer',
        'e-animal' => 'su animal favorito',
        'e-pitch' => 'una idea que quiere defender',
        'e-cuento' => 'un cuento que está contando',
        _ => 'el tema que eligió',
      };

  /// Per-topic fallback. Warm, short, always a real question.
  String _bank(Exercise e) => switch (e.id) {
        'e-presentate' => '¿Y qué es lo que más te gusta hacer?',
        'e-animal' => '¿Por qué te gusta tanto ese animal?',
        'e-pitch' => '¿Y por qué crees que tu idea es importante?',
        'e-cuento' => '¿Qué pasó después en tu cuento?',
        _ => '¿Me puedes contar un poco más?',
      };

  /// Keep only the first line, trim quotes/markdown, reject empty or non-question
  /// junk. A small model sometimes adds a preamble — take the last sentence
  /// ending in "?".
  String? _clean(String? raw) {
    if (raw == null) return null;
    var s = raw
        .replaceAll(r'\n', ' ') // literal backslash-n the model sometimes emits
        .replaceAll(r'\t', ' ')
        .replaceAll('"', '')
        .replaceAll('*', '')
        .trim();
    if (s.isEmpty) return null;
    // Prefer a line that actually ends in a question mark.
    final lines = s
        .split(RegExp(r'[\n\r]'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    for (final l in lines) {
      if (l.endsWith('?')) {
        s = l;
        break;
      }
    }
    // Collapse any leftover whitespace runs.
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length < 4 || s.length > 120) return null;
    if (!s.contains('?')) s = '$s?';
    return s;
  }
}

enum QuestionSource { gemma, bank }

class AskedQuestion {
  final String text;
  final QuestionSource source;
  const AskedQuestion({required this.text, required this.source});
}
