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

  group('repetition loops (Whisper stuck)', () {
    test('drops a repeated-phrase loop to empty', () {
      // The exact failure seen on device: one phrase repeated many times.
      final loop = ('y en el momento de 50 ' * 30).trim();
      expect(cleanTranscript(loop), isEmpty);
      expect(isLikelyHallucination(loop), isTrue);
    });

    test('keeps a long, lexically diverse real transcript', () {
      const real =
          'Hola a todos, hoy quiero contarles sobre mi perro Rocky. Le encanta '
          'correr en el parque, perseguir la pelota y saludar a la gente con '
          'mucha energía cada mañana temprano.';
      expect(cleanTranscript(real), isNotEmpty);
      expect(isLikelyHallucination(real), isFalse);
    });

    test('does not flag a short natural repetition', () {
      // Short and human — must not be mistaken for a loop.
      expect(isLikelyHallucination('no no no lo sé, ya voy'), isFalse);
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
