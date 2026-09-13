import 'dart:ui';

/// A scrap of cloud thrown off when a cloud bursts. Mutable, like CloudSprite,
/// and advanced by the same ticker.
class Puff {
  Puff({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.life,
  });

  /// Unit sky coordinates.
  Offset position;

  /// Unit sky coordinates per second. Slowed by drag each tick.
  Offset velocity;

  /// In the cloud path's authored units, so it scales with the clouds.
  final double radius;

  /// Seconds.
  final double life;

  double age = 0;

  double get progress => (age / life).clamp(0.0, 1.0);
  bool get finished => age >= life;
}
