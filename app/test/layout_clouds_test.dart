import 'package:clouds/features/sky/domain/usecases/layout_clouds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unitSlot', () {
    for (final basis in [1, 6, 12, 18]) {
      test('keeps every cloud inside the sky (capacity $basis)', () {
        for (var i = 0; i < 500; i++) {
          final c = unitSlot(i, basis);
          expect(c.dx, inInclusiveRange(0.02, 0.98), reason: 'slot $i x');
          expect(c.dy, inInclusiveRange(0.02, 0.98), reason: 'slot $i y');
        }
      });
    }

    test('a normal month keeps the original spiral', () {
      // Hand-computed from the Vogel spiral: r = sqrt((i + 0.5) / 12), angle
      // i x 2.39996, radii 0.46 across and 0.40 down around (0.5, 0.46).
      final first = unitSlot(0, 12);
      expect(first.dx, closeTo(0.5939, 1e-3));
      expect(first.dy, closeTo(0.46, 1e-3));

      final second = unitSlot(1, 12);
      expect(second.dx, closeTo(0.3801, 1e-3));
      expect(second.dy, closeTo(0.5555, 1e-3));
    });

    test('stacked layers interleave rather than hiding clouds behind others',
        () {
      const basis = 12;
      final spots = [for (var i = 0; i < 3 * basis; i++) unitSlot(i, basis)];
      for (var a = 0; a < spots.length; a++) {
        for (var b = a + 1; b < spots.length; b++) {
          expect(
            (spots[a] - spots[b]).distance,
            greaterThan(0.02),
            reason: 'slots $a and $b',
          );
        }
      }
    });

    test('past three layers, extra clouds share spots already in use', () {
      const basis = 12;
      for (var i = 0; i < 3 * basis; i++) {
        expect(
          (unitSlot(i + 3 * basis, basis) - unitSlot(i, basis)).distance,
          lessThan(0.03),
          reason: 'slot ${i + 3 * basis}',
        );
      }
    });
  });
}
