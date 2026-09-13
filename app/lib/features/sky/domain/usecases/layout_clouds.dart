import 'dart:math' as math;
import 'dart:ui';

import '../entities/cloud_sprite.dart';

/// Where the sun sits, in unit coordinates of the sky box.
const Offset sunUnitCenter = Offset(0.5, 0.46);

const double _goldenAngle = 2.39996323;

/// A Vogel spiral (the sunflower-seed arrangement). Gives even, non-gridlike
/// coverage at any count, deterministically, with no packing loop and no
/// random seed to keep in sync.
///
/// [basis] is the month's maxClouds, NOT the live count — keying off the live
/// count would shift every existing cloud whenever one is added or removed.
/// Overflow clouds past the basis simply spiral outward and get clipped by the
/// sky bounds, which combined with the shrink is what makes a heavy month read
/// as dense weather.
Offset unitSlot(int index, int basis) {
  final r = math.sqrt((index + 0.5) / basis);
  final a = index * _goldenAngle;
  return Offset(
    sunUnitCenter.dx + r * 0.46 * math.cos(a),
    sunUnitCenter.dy + r * 0.40 * math.sin(a),
  );
}

CloudSprite buildSprite(int slot, int basis, {double entry = 1}) {
  final c = unitSlot(slot, basis);
  return CloudSprite(
    slot: slot,
    unitCenter: c,
    // Vogel radius grows with index, so this is monotonic — index 0 is the
    // cloud sitting on the sun's face.
    distanceFromSun: (c - sunUnitCenter).distance,
    entry: entry,
  );
}
