import 'dart:ui';

/// A single cloud's animation state. Plain mutable data, not a widget — the
/// whole sky is painted by one CustomPainter, so these never enter the widget
/// tree.
class CloudSprite {
  CloudSprite({
    required this.slot,
    required this.unitCenter,
    required this.distanceFromSun,
    this.entry = 1,
  });

  /// Stable birth index. Position is derived from this and never recomputed,
  /// so clouds cannot teleport when the count changes mid-animation.
  final int slot;
  final Offset unitCenter;
  final double distanceFromSun;

  /// 0 → 1 pop-in progress.
  double entry;

  /// 0 → 1 evaporate progress. Only advances once [exiting] is set.
  double t = 0;
  bool exiting = false;

  /// Seconds left before this sprite's exit begins. Drives the stagger.
  double delay = 0;

  bool get finished => exiting && t >= 1;
}
