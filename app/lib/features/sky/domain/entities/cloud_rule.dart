import 'dart:math' as math;

/// Turns an outstanding balance into a cloud count, and works out how far to
/// shrink the clouds once the sky is over capacity.
///
/// Mirrored in TypeScript at backend/src/sky/domain/cloud-rule.ts. The
/// duplication is deliberate — the sky has to react the instant a payment
/// clears, offline, with no round trip — and both sides are pinned to
/// shared/cloud-rule.vectors.json so neither can drift alone.
///
/// Money is always integer centavos. Dart's `double` and JS's `number` are the
/// same IEEE-754 type, so a balance that is truly 2000.00 can arrive as
/// 1999.9999999998 and silently render two clouds instead of three.
class CloudRule {
  const CloudRule({
    required this.centavosPerCloud,
    required this.maxClouds,
  })  : assert(centavosPerCloud > 0, 'centavosPerCloud must be > 0'),
        assert(maxClouds > 0, 'maxClouds must be > 0');

  factory CloudRule.fromJson(Map<String, dynamic> json) => CloudRule(
        centavosPerCloud: json['centavosPerCloud'] as int,
        maxClouds: json['maxClouds'] as int,
      );

  final int centavosPerCloud;
  final int maxClouds;

  /// Below this the clouds read as lint rather than weather.
  static const double minScale = 0.42;

  /// Integer ceiling division — deliberately never touches `double`.
  int cloudsFor(int outstandingCentavos) {
    if (outstandingCentavos <= 0) return 0;
    return (outstandingCentavos + centavosPerCloud - 1) ~/ centavosPerCloud;
  }

  /// Area-preserving shrink. Twenty clouds at sqrt(12/20) cover the same sky
  /// as twelve at full size, so total white stays constant and a heavy month
  /// reads as finer grain rather than a number to parse.
  double scaleFor(int cloudCount) {
    if (cloudCount <= maxClouds) return 1;
    return math.sqrt(maxClouds / cloudCount).clamp(minScale, 1.0);
  }
}
