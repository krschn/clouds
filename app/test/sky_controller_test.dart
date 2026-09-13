import 'package:clouds/features/sky/domain/entities/cloud_rule.dart';
import 'package:clouds/features/sky/domain/entities/cloud_sprite.dart';
import 'package:clouds/features/sky/domain/usecases/layout_clouds.dart';
import 'package:clouds/features/sky/presentation/controllers/sky_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

int unitsOf(Iterable<CloudSprite> sprites) =>
    sprites.fold(0, (n, s) => n + s.units);

void main() {
  late RecordingHaptics haptics;
  late SkyController sky;

  setUp(() {
    haptics = RecordingHaptics();
    sky = SkyController(
      vsync: const TestVSync(),
      rule: const CloudRule(centavosPerCloud: 100000, maxClouds: 12),
      haptics: haptics,
    );
  });

  tearDown(() => sky.dispose());

  group('hold tension', () {
    testWidgets('a push charges the sun, and it eases back on letting go',
        (tester) async {
      sky.syncTo(4, animate: false);

      sky.setTension(2, 1);
      await settle(tester, seconds: 0.6);
      expect(sky.charge, closeTo(1, 0.01));

      sky.setTension(2, 0);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        sky.charge,
        inExclusiveRange(0.0, 1.0),
        reason: 'eases, not blinks',
      );

      await settle(tester, seconds: 1);
      expect(sky.charge, 0);
    });

    testWidgets('switching months drops the charge at once', (tester) async {
      sky.syncTo(4, animate: false);
      sky.setTension(2, 1);
      await settle(tester, seconds: 0.6);

      sky.syncTo(6, animate: false);

      expect(sky.charge, 0);
      await settle(tester, seconds: 1);
    });

    testWidgets('the clouds that tremble are the ones that then leave',
        (tester) async {
      sky.syncTo(4, animate: false);

      sky.setTension(2, 0.6);
      final trembling = {
        for (final s in sky.sprites)
          if (s.tension > 0) s.slot,
      };
      sky.syncTo(2);

      expect(trembling, hasLength(2));
      expect({for (final s in sky.sprites) if (s.exiting) s.slot}, trembling);
      await settle(tester);
    });

    testWidgets('trembles the clouds nearest the sun', (tester) async {
      sky.syncTo(4, animate: false);

      sky.setTension(1, 1);

      final nearest = sky.sprites.reduce(
        (a, b) => a.distanceFromSun <= b.distanceFromSun ? a : b,
      );
      expect(nearest.tension, 1);
      sky.setTension(0, 0);
      await settle(tester, seconds: 0.2);
    });

    testWidgets('letting go calms every cloud', (tester) async {
      sky.syncTo(4, animate: false);
      sky.setTension(3, 0.8);

      sky.setTension(0, 0);

      expect(sky.sprites.every((s) => s.tension == 0), isTrue);
      await settle(tester, seconds: 0.2);
    });
  });

  group('evaporating', () {
    testWidgets('each cloud bursts into puffs with a haptic tap',
        (tester) async {
      sky.syncTo(3, animate: false);

      sky.syncTo(1);
      await settle(tester, seconds: 0.6);
      final sawPuffs = sky.puffs.isNotEmpty;
      await settle(tester);

      expect(sawPuffs, isTrue);
      expect(haptics.bursts, 2);
      expect(sky.puffs, isEmpty);
      expect(sky.sprites, hasLength(1));
    });

    testWidgets('each burst kicks the sun', (tester) async {
      sky.syncTo(3, animate: false);

      sky.syncTo(2);
      while (haptics.bursts == 0) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 16));

      expect(sky.sunPulse, greaterThan(0));
      await settle(tester);
      expect(sky.sunPulse.abs(), lessThan(0.01));
    });
  });

  group('finale', () {
    testWidgets('plays once when the last cloud is cleared', (tester) async {
      sky.syncTo(2, animate: false);

      sky.syncTo(0);
      await settle(tester);

      expect(haptics.finales, 1);
      expect(sky.finale, 1);
    });

    testWidgets('does not play while clouds remain', (tester) async {
      sky.syncTo(3, animate: false);

      sky.syncTo(1);
      await settle(tester);

      expect(haptics.finales, 0);
      expect(sky.finale, 0);
    });

    testWidgets('does not play when switching to an already clear month',
        (tester) async {
      sky.syncTo(2, animate: false);

      sky.syncTo(0, animate: false);
      await settle(tester, seconds: 1);

      expect(haptics.finales, 0);
      expect(sky.finale, 0);
    });

    testWidgets('new clouds put the celebration away', (tester) async {
      sky.syncTo(1, animate: false);
      sky.syncTo(0);
      await settle(tester);

      sky.syncTo(2);

      expect(sky.finale, 0);
      await settle(tester);
    });
  });

  group('arriving clouds', () {
    testWidgets('launch from the add button and land with a tap',
        (tester) async {
      sky.launchFrom = const Offset(0.9, 1.05);

      sky.syncTo(3);

      expect(
        sky.sprites.every((s) => s.entryStyle == CloudEntry.launch),
        isTrue,
      );
      expect(
        sky.sprites.every((s) => s.origin == const Offset(0.9, 1.05)),
        isTrue,
      );
      await settle(tester);
      expect(sky.sprites.every((s) => s.entry == 1), isTrue);
      expect(haptics.landings, 3);
    });

    testWidgets('drop in from above when there is no launch point',
        (tester) async {
      sky.syncTo(2);

      expect(
        sky.sprites.every((s) => s.entryStyle == CloudEntry.drop),
        isTrue,
      );
      await settle(tester);
    });
  });

  group('big clouds', () {
    testWidgets('every five clouds draw as one big cloud', (tester) async {
      sky.syncTo(23, animate: false);

      expect(sky.sprites.where((s) => s.units == 5), hasLength(4));
      expect(sky.sprites.where((s) => s.units == 1), hasLength(3));
    });

    testWidgets('clearing into a big cloud splits it and the pieces fly out',
        (tester) async {
      sky.syncTo(23, animate: false);

      sky.syncTo(19);

      final leaving = sky.sprites.where((s) => s.exiting).toList();
      expect(leaving, hasLength(1));
      expect(leaving.single.units, 5);
      final pieces = sky.sprites.where((s) => !s.exiting && s.entry < 1);
      expect(pieces, hasLength(1));
      expect(pieces.single.entryStyle, CloudEntry.launch);
      expect(pieces.single.origin, leaving.single.unitCenter);

      await settle(tester);
      expect(sky.sprites.where((s) => s.units == 5), hasLength(3));
      expect(sky.sprites.where((s) => s.units == 1), hasLength(4));
    });

    testWidgets('the big cloud about to split is the one that trembles',
        (tester) async {
      sky.syncTo(23, animate: false);

      sky.setTension(4, 0.7);
      final trembling = {
        for (final s in sky.sprites)
          if (s.tension > 0) s.slot,
      };
      sky.syncTo(19);

      expect(trembling, hasLength(1));
      expect({for (final s in sky.sprites) if (s.exiting) s.slot}, trembling);
      await settle(tester);
    });

    testWidgets('adding past five gathers the small clouds into a big one',
        (tester) async {
      sky.syncTo(23, animate: false);

      sky.syncTo(27);

      final gathering = sky.sprites.where((s) => s.exiting).toList();
      expect(gathering, hasLength(3));
      expect(gathering.every((s) => s.units == 1), isTrue);
      final formed =
          sky.sprites.where((s) => s.entryStyle == CloudEntry.gather).toList();
      expect(formed, hasLength(1));
      expect(formed.single.units, 5);
      expect(
        gathering.every((s) => s.mergeInto == formed.single.unitCenter),
        isTrue,
      );

      await settle(tester);
      expect(sky.sprites.where((s) => s.units == 5), hasLength(5));
      expect(sky.sprites.where((s) => s.units == 1), hasLength(2));
    });

    testWidgets('gathering is not a clear: no bursts and no celebration',
        (tester) async {
      sky.syncTo(4, animate: false);

      sky.syncTo(5);
      await settle(tester);

      expect(haptics.bursts, 0);
      expect(sky.finale, 0);
      expect(sky.sprites.single.units, 5);
    });
  });

  group('heavy months', () {
    bool inSky(CloudSprite s) =>
        s.unitCenter.dx > 0 &&
        s.unitCenter.dx < 1 &&
        s.unitCenter.dy > 0 &&
        s.unitCenter.dy < 1;

    testWidgets('clearing most of an 81-cloud month leaves the rest on screen',
        (tester) async {
      sky.syncTo(81, animate: false);

      sky.syncTo(31);
      // Staggered exits, then the colours glide on for a few seconds after
      // the last burst.
      await settle(tester, seconds: 8);

      expect(unitsOf(sky.sprites), 31);
      expect(sky.sprites.every(inSky), isTrue);
    });

    testWidgets('new clouds take the free spots nearest the sun',
        (tester) async {
      sky.syncTo(4, animate: false);
      sky.syncTo(1);
      await settle(tester);
      final before = {for (final s in sky.sprites) s.slot};

      sky.syncTo(4);

      final added = {
        for (final s in sky.sprites)
          if (!before.contains(s.slot)) s.slot,
      };
      expect(added, {0, 1, 2});
      await settle(tester);
    });

    testWidgets('switching months lays the sky out from scratch',
        (tester) async {
      sky.syncTo(10, animate: false);
      sky.syncTo(4);
      await settle(tester);

      sky.updateRule(const CloudRule(centavosPerCloud: 100000, maxClouds: 6));
      sky.syncTo(4, animate: false);

      expect({for (final s in sky.sprites) s.slot}, {0, 1, 2, 3});
      for (final s in sky.sprites) {
        expect(s.unitCenter, unitSlot(s.slot, 6));
      }
    });
  });

  group('gloom', () {
    testWidgets('glides lighter as clouds clear rather than jumping',
        (tester) async {
      sky.syncTo(18, animate: false);
      expect(sky.gloom, 1);

      sky.syncTo(0);
      await tester.pump(const Duration(milliseconds: 16));
      final justAfter = sky.gloom;
      await settle(tester, seconds: 0.8);
      final midway = sky.gloom;
      await settle(tester, seconds: 4);

      expect(justAfter, greaterThan(0.95));
      expect(midway, inExclusiveRange(0.0, justAfter));
      expect(sky.gloom, closeTo(0, 0.01));
    });

    testWidgets('snaps when switching months', (tester) async {
      sky.syncTo(18, animate: false);

      sky.syncTo(9, animate: false);

      expect(sky.gloom, closeTo(0.5, 1e-9));
    });
  });
}
