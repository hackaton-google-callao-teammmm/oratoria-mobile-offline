import 'package:flutter_test/flutter_test.dart';
import 'package:oratoria_kids/shared/characters/la_banca.dart';

void main() {
  group('haloForEnergy — the "Vox te escucha" pulse curve', () {
    test('silence still shows a faint, non-zero halo', () {
      final (scale, alpha) = haloForEnergy(0);
      expect(scale, 1.0);
      expect(alpha, greaterThan(0));
    });

    test('full energy is the largest, most opaque halo', () {
      final (scale, alpha) = haloForEnergy(1);
      final (silentScale, silentAlpha) = haloForEnergy(0);
      expect(scale, greaterThan(silentScale));
      expect(alpha, greaterThan(silentAlpha));
    });

    test('scales monotonically with energy in between', () {
      final (scaleLow, alphaLow) = haloForEnergy(0.3);
      final (scaleHigh, alphaHigh) = haloForEnergy(0.7);
      expect(scaleHigh, greaterThan(scaleLow));
      expect(alphaHigh, greaterThan(alphaLow));
    });

    test('clamps out-of-range energy instead of over/undershooting', () {
      final atMax = haloForEnergy(1.0);
      final over = haloForEnergy(5.0);
      expect(over, atMax);

      final atMin = haloForEnergy(0.0);
      final under = haloForEnergy(-2.0);
      expect(under, atMin);
    });
  });
}
