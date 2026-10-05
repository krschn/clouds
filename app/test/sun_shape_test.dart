import 'dart:math' as math;
import 'dart:ui';

import 'package:clouds/features/sky/presentation/painters/sun_shape.dart';
import 'package:flutter_test/flutter_test.dart';

Offset polar(double r, double angle) =>
    Offset(math.cos(angle) * r, math.sin(angle) * r);

void main() {
  group('skyStage', () {
    test('starts below the top inset and runs to the bottom of the sky', () {
      final stage = skyStage(const Size(402, 446), topInset: 62);
      expect(stage, const Rect.fromLTRB(0, 62, 402, 446));
    });

    test('places unit coordinates inside the stage, not behind the notch',
        () {
      final stage = skyStage(const Size(402, 446), topInset: 62);
      expect(stagePoint(stage, const Offset(0.5, 0)), const Offset(201, 62));
      expect(stagePoint(stage, const Offset(0, 1)), const Offset(0, 446));
    });
  });

  group('sunLayout', () {
    const skies = {
      'iPhone 17 Pro': (Size(402, 446), 62.0),
      'small phone': (Size(375, 340), 47.0),
      'web': (Size(480, 470), 0.0),
    };

    skies.forEach((name, sky) {
      final (size, inset) = sky;

      test('on $name, the sun at its biggest clears the notch', () {
        final sun = sunLayout(size, topInset: inset);
        final reach = sun.radius * maxSunSwell * sunOuterReach;
        expect(sun.center.dy - reach, greaterThanOrEqualTo(inset));
      });

      test('on $name, the sun at its biggest stays inside the sides', () {
        final sun = sunLayout(size, topInset: inset);
        final reach = sun.radius * maxSunSwell * sunOuterReach;
        expect(sun.center.dx - reach, greaterThanOrEqualTo(0));
        expect(sun.center.dx + reach, lessThanOrEqualTo(size.width));
      });
    });
  });

  group('buildSunFlames', () {
    const r = 100.0;
    final flames = buildSunFlames(radius: r);
    final angles = [for (var i = 0; i < 720; i++) i * math.pi / 360];

    test('leaves a gap between the disc and the flames', () {
      expect(flames.contains(Offset.zero), isFalse);
      for (final a in angles) {
        expect(flames.contains(polar(r * 1.07, a)), isFalse, reason: '$a');
      }
    });

    test('joins the flames into one ring around the disc', () {
      for (final a in angles) {
        expect(flames.contains(polar(r * 1.2, a)), isTrue, reason: '$a');
      }
    });

    test('rises in separate curling tongues', () {
      var edges = 0;
      var inside = flames.contains(polar(r * 1.35, angles.last));
      for (final a in angles) {
        final now = flames.contains(polar(r * 1.35, a));
        if (now != inside) edges++;
        inside = now;
      }
      expect(edges, greaterThanOrEqualTo(2 * sunTongues));
    });

    test('reaches no further than its outer reach', () {
      for (final a in angles) {
        expect(
          flames.contains(polar(r * sunOuterReach * 1.02, a)),
          isFalse,
          reason: '$a',
        );
      }
    });
  });
}
