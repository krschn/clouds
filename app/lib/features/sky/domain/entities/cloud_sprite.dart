import 'dart:ui';

/// How a cloud arrives.
enum CloudEntry {
  /// Falls into place from just above. Used when there is no add button.
  drop,

  /// Thrown along an arc: from the add button, or out of a big cloud that has
  /// just split.
  launch,

  /// Re-forms where it just evaporated, when a clear is rolled back.
  condense,

  /// A big cloud forming where small ones are flying together.
  gather,
}

/// A single cloud's animation state. Plain mutable data, not a widget — the
/// whole sky is painted by one CustomPainter, so these never enter the widget
/// tree.
class CloudSprite {
  CloudSprite({
    required this.slot,
    required this.unitCenter,
    required this.distanceFromSun,
    this.entry = 1,
    this.entryStyle = CloudEntry.drop,
    this.origin,
    this.units = 1,
  }) : landed = entry >= 1;

  /// Layout slot, fixed for this sprite's life. Position is derived from it
  /// and never recomputed, so clouds cannot teleport when the count changes
  /// mid-animation. New sprites take the lowest free slot.
  final int slot;
  final Offset unitCenter;
  final double distanceFromSun;

  final CloudEntry entryStyle;

  /// Where a launched cloud starts, in the sky's unit coordinates.
  final Offset? origin;

  /// How many clouds this sprite stands for: 1, or cloudsPerBigCloud for a
  /// big cloud.
  final int units;

  /// 0 → 1 arrival progress.
  double entry;

  /// Seconds left before arrival begins. Drives the entry stagger.
  double entryDelay = 0;

  /// Whether the landing beat (and its haptic) has happened.
  bool landed;

  /// 0 → 1 exit progress. Only advances once [exiting] is set.
  double t = 0;
  bool exiting = false;

  /// Set when this cloud is leaving by flying into a new big cloud rather
  /// than evaporating. It then neither bursts nor counts as a clear.
  Offset? mergeInto;

  /// Seconds left before this sprite's exit begins. Drives the stagger.
  double delay = 0;

  /// Whether this cloud has burst into puffs yet.
  bool burst = false;

  /// 0 → 1 how hard this cloud trembles while its bill is being held.
  double tension = 0;

  bool get finished => exiting && t >= 1;
}
