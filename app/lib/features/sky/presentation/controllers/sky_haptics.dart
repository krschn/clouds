import 'package:flutter/services.dart';

/// The taps that go with the sky's animations. An interface so the sky can be
/// tested without a platform channel, and so haptics can be switched off.
abstract class SkyHaptics {
  /// A cloud has burst into puffs.
  void burst();

  /// A new cloud has landed in its place.
  void land();

  /// The last cloud is gone.
  void finale();
}

class PlatformSkyHaptics implements SkyHaptics {
  const PlatformSkyHaptics();

  @override
  void burst() => HapticFeedback.lightImpact();

  @override
  void land() => HapticFeedback.selectionClick();

  @override
  void finale() => HapticFeedback.heavyImpact();
}
