import 'package:oratoria_core/oratoria_core.dart';
import 'package:test/test.dart';

void main() {
  const fillers = SpanishFillers();

  group('SpanishFillers', () {
    test('finds nothing in clean speech', () {
      expect(fillers.totalCount('Hola, me llamo Ana y me gusta pintar.'), 0);
    });

    test('counts repeated fillers', () {
      const transcript = 'Este, hoy quiero contarles, este, sobre mi perro.';
      expect(fillers.totalCount(transcript), 2);
    });

    test('collapses spelling variants into one term', () {
      const transcript = 'Eh, ehh, ehhh, quiero hablar.';
      final hits = fillers.detect(transcript);

      expect(hits, hasLength(1));
      expect(hits.single.term, 'eh');
      expect(hits.single.count, 3);
    });

    test('detects multi-word fillers', () {
      expect(fillers.totalCount('O sea, como que no sé.'), 2);
    });

    test('ranks the dominant filler first', () {
      const transcript = 'Este, eh, este, este, digamos.';
      expect(fillers.dominant(transcript), 'este');
    });

    test('does not match fillers inside longer words', () {
      // "estelar" and "ehecatl" must not register as "este"/"eh".
      expect(fillers.totalCount('Un evento estelar y espectacular.'), 0);
    });

    test('ignores "este" used as a demonstrative', () {
      // The trust guard: flagging a legitimate word makes a child distrust
      // every other number in the report.
      expect(fillers.totalCount('Lo hice de este modo en este caso.'), 0);
    });

    test('still counts "este" when it is a real filler', () {
      expect(fillers.totalCount('Yo, este, no sabía qué decir.'), 1);
    });

    test('is case and accent tolerant', () {
      expect(fillers.totalCount('ESTE, ajá, Ajá.'), 3);
    });

    test('handles an empty transcript', () {
      expect(fillers.totalCount(''), 0);
      expect(fillers.dominant(''), isNull);
    });
  });
}
