import 'package:oratoria_core/oratoria_core.dart';

import 'gemma_service.dart';

/// Rewrites a prompt to warmer prose; returns null on any failure/timeout.
typedef LlmRewrite = Future<String?> Function(String prompt);

/// A coach that keeps the deterministic VERDICT of [RuleBasedCoach] but lets
/// Gemma rephrase the two prose bodies, so the feedback stops sounding like a
/// template.
///
/// Why not let Gemma decide? Because then a child would get a different verdict
/// on identical performance every run. The rule-based coach owns *what* is the
/// strength, the improvement, the numbers and the goal result; Gemma only
/// changes *how it is worded*. And it is fenced hard:
/// - only the trusted, meaningful case is personalised (never invents metrics
///   from an untrusted transcript);
/// - the titles, dimensions and goal are untouched;
/// - null / unparseable / thrown → the exact rule-based text is returned.
class GemmaCoach implements CoachFeedbackGenerator {
  final RuleBasedCoach _base;
  final LlmRewrite _rewrite;

  const GemmaCoach({
    RuleBasedCoach base = const RuleBasedCoach(),
    required LlmRewrite rewrite,
  })  : _base = base,
        _rewrite = rewrite;

  /// Production wiring: rephrase via the on-device Gemma singleton. A tight
  /// timeout keeps the "Vox piensa" beat bounded; on timeout it falls back.
  factory GemmaCoach.gemma() => GemmaCoach(
        rewrite: (prompt) => GemmaService.instance.ask(
          prompt,
          maxTokens: 220,
          timeout: const Duration(seconds: 10),
        ),
      );

  @override
  Future<CoachFeedback> generate({
    required ParaverbalMetrics voice,
    required BodyMetrics body,
    required Exercise exercise,
    bool voiceTrusted = true,
    bool pausesTrusted = true,
  }) async {
    final base = await _base.generate(
      voice: voice,
      body: body,
      exercise: exercise,
      voiceTrusted: voiceTrusted,
      pausesTrusted: pausesTrusted,
    );

    // Only personalise honest, substantial runs. For an untrusted or too-short
    // run the rule coach already returned an encouragement — leave it exactly.
    if (!voiceTrusted || !voice.isMeaningful) return base;

    try {
      final raw = await _rewrite(_prompt(exercise, base));
      final parsed = _parse(raw);
      if (parsed == null) return base;

      return CoachFeedback(
        strengthDimension: base.strengthDimension,
        strengthTitle: base.strengthTitle,
        strengthBody: parsed.$1,
        improvementDimension: base.improvementDimension,
        improvementTitle: base.improvementTitle,
        improvementBody: parsed.$2,
        goalMet: base.goalMet,
        goalMessage: base.goalMessage,
        source: FeedbackSource.onDeviceLlm,
      );
    } catch (_) {
      return base;
    }
  }

  String _prompt(Exercise exercise, CoachFeedback base) =>
      'Eres Vox, un entrenador de oratoria cálido para niños de 9 a 15 años. '
      'Reescribe estos dos mensajes con tus propias palabras, en español neutro, '
      'cercano y alentador. NO cambies el significado ni los números, y no '
      'regañes. Cada mensaje: 2 frases cortas.\n\n'
      'Reto: ${exercise.title}\n'
      'FORTALEZA (original): ${base.strengthBody}\n'
      'MEJORA (original): ${base.improvementBody}\n\n'
      'Responde EXACTAMENTE en este formato, sin nada más:\n'
      'FORTALEZA: <texto>\n'
      'MEJORA: <texto>';

  /// Pulls the two rewritten bodies out of the model's reply. Returns null (→
  /// rule-based fallback) when either is missing/empty, or when a body still
  /// carries the other label — a sign the split was ambiguous (e.g. everything
  /// on one line). Honesty over a fancy-but-garbled rewrite.
  (String, String)? _parse(String? raw) {
    if (raw == null) return null;
    final strength = _field(raw, 'FORTALEZA');
    final improvement = _field(raw, 'MEJORA');
    if (strength == null || improvement == null) return null;
    if (strength.isEmpty || improvement.isEmpty) return null;
    if (_hasLabel(strength) || _hasLabel(improvement)) return null;
    return (strength, improvement);
  }

  // Matches a label line even when a small model bolds or bullets it
  // (**MEJORA:**, - MEJORA:, "  MEJORA:") — the exact shapes that defeat a
  // naive regex and leak one field into the other.
  static final _anyLabel =
      RegExp(r'^[\s*_>#\-]*(?:FORTALEZA|MEJORA)\s*:', caseSensitive: false);

  /// Line-based, decoration-tolerant extraction of one label's body.
  String? _field(String raw, String label) {
    final labelLine =
        RegExp('^[\\s*_>#\\-]*$label\\s*:\\s*(.*)\$', caseSensitive: false);
    final buf = <String>[];
    var capturing = false;
    for (final line in raw.split('\n')) {
      final m = labelLine.firstMatch(line);
      if (m != null) {
        capturing = true;
        final rest = m.group(1)!.trim();
        if (rest.isNotEmpty) buf.add(rest);
        continue;
      }
      if (capturing) {
        if (_anyLabel.hasMatch(line)) break; // the next label starts here
        buf.add(line.trim());
      }
    }
    if (!capturing) return null;
    return _stripMarkdown(buf.join(' '));
  }

  bool _hasLabel(String s) {
    final upper = s.toUpperCase();
    return upper.contains('FORTALEZA') || upper.contains('MEJORA');
  }

  String _stripMarkdown(String s) => s
      .replaceAll(RegExp(r'[*_`#]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
