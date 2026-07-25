/// Whisper invents text when it is fed silence or room noise. It emits
/// non-speech tags ("[Música]", "(aplausos)") and a small set of stock phrases
/// it learned from subtitle data ("Subtítulos realizados por...", "Gracias por
/// ver el video"). Taken as real speech these would fabricate a "Ritmo" and
/// "Muletillas" out of nothing, so we scrub them before deciding whether the
/// transcript can be trusted.
///
/// Pure and dependency-free so it can be unit-tested without a device.
library;

/// Bracketed / parenthesised non-speech annotations and musical notes.
final RegExp _nonSpeechTags = RegExp(r'\[[^\]]*\]|\([^\)]*\)|[♪♫]');

/// Substrings that only ever appear when Whisper hallucinates over silence.
/// Matched case-insensitively against the (accent-folded) transcript.
const List<String> _hallucinationMarkers = [
  'subtitulos',
  'subtitulado',
  'amara.org',
  'gracias por ver',
  'gracias por su atencion',
  'suscribete',
  'no olvides suscribirte',
  'nos vemos en el proximo',
];

String _foldAccents(String s) => s
    .replaceAll(RegExp(r'[áàä]'), 'a')
    .replaceAll(RegExp(r'[éèë]'), 'e')
    .replaceAll(RegExp(r'[íìï]'), 'i')
    .replaceAll(RegExp(r'[óòö]'), 'o')
    .replaceAll(RegExp(r'[úùü]'), 'u');

/// Strips non-speech tags and known hallucination phrases, then collapses
/// whitespace. Returns the cleaned transcript, which may be empty.
String cleanTranscript(String raw) {
  var s = raw.replaceAll(_nonSpeechTags, ' ');

  final folded = _foldAccents(s.toLowerCase());
  for (final marker in _hallucinationMarkers) {
    if (folded.contains(marker)) {
      // The whole utterance is a known stock phrase — drop it entirely rather
      // than trying to surgically excise part of a fabricated sentence.
      return '';
    }
  }

  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// True when nothing real survives cleaning — the transcript was almost
/// certainly Whisper talking to itself over silence.
bool isLikelyHallucination(String raw) => cleanTranscript(raw).isEmpty;
