import 'dart:math' as math;
import 'dart:ui';

import '../entities/cloud_sprite.dart';

/// Where the sun sits, in unit coordinates of the sky box.
const Offset sunUnitCenter = Offset(0.5, 0.46);

/// How many times over a month's capacity the clouds stack before they start
/// sharing spots. Past this a heavy month stops getting visibly busier; it
/// already reads as dense weather, and the count is in the caption.
const int maxStackedLayers = 3;

const double _goldenAngle = 2.39996323;

/// How far a doubled-up cloud sits from the one it shares a spot with, so the
/// pair reads as one thicker cloud rather than a single flat one.
const double _sharedJitter = 0.012;

/// Where cloud [index] sits, for a month whose capacity is [basis].
///
/// The first [basis] clouds follow a Vogel spiral (the sunflower-seed
/// arrangement): even, non-gridlike coverage, deterministic, with no packing
/// loop and no random seed to keep in sync. Its radius never reaches 1, so
/// every one lands inside the sky.
///
/// Heavier months stack further layers of the same spiral over the first,
/// each offset half a step along it so their clouds fall in the gaps rather
/// than behind existing ones. Spiralling further out instead — the old
/// behaviour — put everything past about twice capacity outside the sky,
/// where it still darkened the screen but could not be seen or cleared.
///
/// [basis] is the month's maxClouds, NOT the live count — keying off the live
/// count would shift every existing cloud whenever one is added or removed.
Offset unitSlot(int index, int basis) {
  final perLayer = math.max(1, basis);
  final spots = perLayer * maxStackedLayers;
  final wraps = index ~/ spots;
  final spot = index % spots;
  final layer = spot ~/ perLayer;
  final j = spot % perLayer;

  // Layer 0 sits at j + 0.5, exactly the original spiral. The other layers
  // take the thirds either side of it.
  final step = j + const [0.5, 0.8333, 0.1667][layer];
  final r = math.sqrt(step / perLayer);
  final a = (step - 0.5) * _goldenAngle;
  var c = Offset(
    sunUnitCenter.dx + r * 0.46 * math.cos(a),
    sunUnitCenter.dy + r * 0.40 * math.sin(a),
  );

  if (wraps > 0) {
    final turn = wraps * 2.1 + spot * 0.7;
    c += Offset(math.cos(turn), math.sin(turn)) * _sharedJitter;
  }
  return c;
}

CloudSprite buildSprite(
  int slot,
  int basis, {
  double entry = 1,
  CloudEntry entryStyle = CloudEntry.drop,
  Offset? origin,
  int units = 1,
}) {
  final c = unitSlot(slot, basis);
  return CloudSprite(
    slot: slot,
    unitCenter: c,
    distanceFromSun: (c - sunUnitCenter).distance,
    entry: entry,
    entryStyle: entryStyle,
    origin: origin,
    units: units,
  );
}
