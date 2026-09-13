import 'package:cloud_payments/features/sky/domain/entities/cloud_sprite.dart';
import 'package:cloud_payments/features/sky/presentation/painters/cloud_pose.dart';
import 'package:flutter_test/flutter_test.dart';

CloudSprite sprite({
  double entry = 1,
  CloudEntry style = CloudEntry.drop,
  Offset? origin,
}) =>
    CloudSprite(
      slot: 0,
      unitCenter: const Offset(0.4, 0.3),
      distanceFromSun: 0.1,
      entry: entry,
      entryStyle: style,
      origin: origin,
    );

void expectOffset(Offset actual, Offset want) {
  expect(actual.dx, closeTo(want.dx, 1e-9));
  expect(actual.dy, closeTo(want.dy, 1e-9));
}

/// Walks [t] from 0 to 1 and fails on any frame-to-frame jump — the thing a
/// badly joined piecewise curve produces.
void expectContinuous(CloudPose Function(double t) at) {
  var prev = at(0);
  for (var i = 1; i <= 1000; i++) {
    final next = at(i / 1000);
    expect((next.center - prev.center).distance, lessThan(0.02), reason: 't=${i / 1000}');
    expect((next.sx - prev.sx).abs(), lessThan(0.05), reason: 't=${i / 1000}');
    expect((next.sy - prev.sy).abs(), lessThan(0.05), reason: 't=${i / 1000}');
    expect((next.dy - prev.dy).abs(), lessThan(2), reason: 't=${i / 1000}');
    expect((next.alpha - prev.alpha).abs(), lessThan(0.05), reason: 't=${i / 1000}');
    prev = next;
  }
}

void main() {
  test('a resting cloud sits on its slot at full size', () {
    final p = poseOf(sprite(), time: 3);
    expectOffset(p.center, const Offset(0.4, 0.3));
    expect([p.sx, p.sy, p.alpha, p.dy], [1, 1, 1, 0]);
  });

  group('evaporate', () {
    test('ends invisible', () {
      final s = sprite()
        ..exiting = true
        ..t = 1;
      expect(poseOf(s, time: 0).alpha, 0);
    });

    test('has no jumps between its phases', () {
      expectContinuous((t) {
        final s = sprite()
          ..exiting = true
          ..t = t;
        return poseOf(s, time: 0);
      });
    });

    test('squashes before it swells', () {
      final s = sprite()
        ..exiting = true
        ..t = 0.2;
      expect(poseOf(s, time: 0).sy, lessThan(0.9));
    });
  });

  group('launch', () {
    const origin = Offset(0.9, 1.05);

    test('starts at the add button', () {
      final p = poseOf(
        sprite(entry: 0, style: CloudEntry.launch, origin: origin),
        time: 0,
      );
      expectOffset(p.center, origin);
    });

    test('lands exactly on its slot', () {
      final p = poseOf(
        sprite(entry: 1, style: CloudEntry.launch, origin: origin),
        time: 0,
      );
      expectOffset(p.center, const Offset(0.4, 0.3));
      expect([p.sx, p.sy, p.alpha], [1, 1, 1]);
    });

    test('flies without jumps', () {
      expectContinuous(
        (t) => poseOf(
          sprite(entry: t, style: CloudEntry.launch, origin: origin),
          time: 0,
        ),
      );
    });
  });

  group('condense', () {
    test('starts invisible and re-forms in place', () {
      final start = poseOf(sprite(entry: 0, style: CloudEntry.condense), time: 0);
      expect(start.alpha, 0);
      expectOffset(start.center, const Offset(0.4, 0.3));
    });

    test('re-forms without jumps', () {
      expectContinuous(
        (t) => poseOf(sprite(entry: t, style: CloudEntry.condense), time: 0),
      );
    });
  });

  group('gather', () {
    const into = Offset(0.6, 0.5);

    CloudSprite gathering(double t) => sprite()
      ..exiting = true
      ..mergeInto = into
      ..t = t;

    test('a small cloud starts from its own spot', () {
      final p = poseOf(gathering(0), time: 0);
      expectOffset(p.center, const Offset(0.4, 0.3));
      expect(p.alpha, 1);
    });

    test('and vanishes into the big cloud', () {
      final p = poseOf(gathering(1), time: 0);
      expectOffset(p.center, into);
      expect(p.alpha, 0);
    });

    test('flies there without jumps', () {
      expectContinuous((t) => poseOf(gathering(t), time: 0));
    });

    test('the big cloud forms in place without jumps', () {
      expectContinuous(
        (t) => poseOf(sprite(entry: t, style: CloudEntry.gather), time: 0),
      );
    });
  });

  test('a big cloud is drawn larger than a small one', () {
    final big = CloudSprite(
      slot: 0,
      unitCenter: const Offset(0.4, 0.3),
      distanceFromSun: 0.1,
      units: 5,
    );
    final small = poseOf(sprite(), time: 0);
    expect(poseOf(big, time: 0).sx, greaterThan(small.sx));
    expect(poseOf(big, time: 0).sy, greaterThan(small.sy));
  });

  test('drop-in has no jumps', () {
    expectContinuous(
      (t) => poseOf(sprite(entry: t, style: CloudEntry.drop), time: 0),
    );
  });

  group('tension', () {
    test('a calm cloud never moves', () {
      for (final time in [0.0, 0.13, 0.5, 1.7]) {
        expectOffset(poseOf(sprite(), time: time).center, const Offset(0.4, 0.3));
      }
    });

    test('a tense cloud trembles, but stays near its slot', () {
      final s = sprite()..tension = 1;
      final offsets = [
        for (var i = 0; i < 60; i++)
          poseOf(s, time: i / 60).center - const Offset(0.4, 0.3),
      ];
      expect(offsets.any((o) => o.distance > 0.002), isTrue);
      expect(offsets.every((o) => o.distance < 0.02), isTrue);
    });
  });
}
