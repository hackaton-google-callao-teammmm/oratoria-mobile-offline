import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/adapters/speech/transcript_hygiene.dart';

void main() {
  group('cleanTranscript', () {
    test('drops a pure non-speech tag to empty', () {
      expect(cleanTranscript('[Música]'), isEmpty);
      expect(cleanTranscript('[MÚSICA]'), isEmpty);
      expect(cleanTranscript('(aplausos)'), isEmpty);
      expect(cleanTranscript('♪♪'), isEmpty);
    });

    test('treats a known stock hallucination phrase as empty', () {
      expect(cleanTranscript('Subtítulos realizados por la comunidad'), isEmpty);
      expect(cleanTranscript('Gracias por ver el video'), isEmpty);
      expect(cleanTranscript('¡Suscríbete al canal!'), isEmpty);
    });

    test('keeps real speech, stripping only embedded tags', () {
      expect(
        cleanTranscript('Hola, [Música] me llamo Ana'),
        'Hola,  me llamo Ana'.replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
      expect(
        cleanTranscript('Mi animal favorito es el perro'),
        'Mi animal favorito es el perro',
      );
    });

    test('collapses whitespace left behind', () {
      expect(cleanTranscript('  hola    mundo  '), 'hola mundo');
    });
  });

  group('isLikelyHallucination', () {
    test('flags silence artifacts', () {
      expect(isLikelyHallucination('[Música]'), isTrue);
      expect(isLikelyHallucination('Gracias por ver el video'), isTrue);
      expect(isLikelyHallucination('   '), isTrue);
    });

    test('does not flag real speech', () {
      expect(isLikelyHallucination('Hoy quiero contarles sobre mi perro'), isFalse);
    });
  });
}
