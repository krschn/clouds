import 'dart:math' as math;

import 'package:cloud_payments/features/sky/presentation/painters/sky_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final steps = [for (var i = 0; i <= 40; i++) i / 40];

  group('gloomFor', () {
    test('a clear sky has no gloom', () {
      expect(gloomFor(0, 12), 0);
    });

    test('is full at one and a half times capacity', () {
      expect(gloomFor(18, 12), 1);
      expect(gloomFor(17, 12), lessThan(1));
    });

    test('is proportional below that', () {
      expect(gloomFor(9, 12), closeTo(0.5, 1e-9));
      expect(gloomFor(4.5, 12), closeTo(0.25, 1e-9));
    });

    test('overflow months stay at full gloom', () {
      expect(gloomFor(40, 12), 1);
    });
  });

  group('paletteFor', () {
    test('a clear sky has pure white clouds', () {
      expect(paletteFor(0).cloud, const Color(0xFFFFFFFF));
    });

    test('more gloom never makes any surface lighter', () {
      final surfaces = <String, Color Function(SkyPalette)>{
        'skyTop': (p) => p.skyTop,
        'skyBottom': (p) => p.skyBottom,
        'cloud': (p) => p.cloud,
        'page': (p) => p.page,
        'sunCore': (p) => p.sunCore,
        'sunRay': (p) => p.sunRay,
      };
      for (var i = 1; i < steps.length; i++) {
        final lighter = paletteFor(steps[i - 1]);
        final darker = paletteFor(steps[i]);
        surfaces.forEach((name, pick) {
          expect(
            pick(darker).computeLuminance(),
            lessThanOrEqualTo(pick(lighter).computeLuminance() + 1e-9),
            reason: '$name got lighter between ${steps[i - 1]} and ${steps[i]}',
          );
        });
      }
    });

    test('a stormy sky is far darker than a clear one', () {
      expect(
        paletteFor(1).skyTop.computeLuminance(),
        lessThan(paletteFor(0).skyTop.computeLuminance() * 0.3),
      );
    });

    test('clouds stay lighter than the sky behind them', () {
      for (final g in steps) {
        final p = paletteFor(g);
        final cloud = p.cloud.computeLuminance();
        expect(cloud, greaterThan(p.skyTop.computeLuminance()), reason: '$g');
        expect(cloud, greaterThan(p.skyBottom.computeLuminance()), reason: '$g');
      }
    });

    test('the menu icon stays visible against the sky', () {
      for (final g in steps) {
        final p = paletteFor(g);
        expect(_contrast(p.ink, p.skyTop), greaterThanOrEqualTo(3), reason: '$g');
      }
    });

    test('the caption stays readable on its chip', () {
      for (final g in steps) {
        final p = paletteFor(g);
        expect(_contrast(p.ink, p.chip), greaterThanOrEqualTo(4.5), reason: '$g');
      }
    });
  });
}
