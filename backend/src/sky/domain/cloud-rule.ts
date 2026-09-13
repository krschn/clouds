/**
 * Turns an outstanding balance into a cloud count, and works out how far to
 * shrink the clouds once the sky is over capacity.
 *
 * This class is duplicated in Dart at
 * app/lib/features/sky/domain/entities/cloud_rule.dart. The duplication is
 * deliberate: the Flutter client has to react to a cleared payment instantly,
 * offline, without a round trip. Both implementations are pinned to
 * shared/cloud-rule.vectors.json so neither can drift alone.
 *
 * All money is integer centavos. Never floats: JS `number` and Dart `double`
 * are both IEEE-754, so a balance that is truly 2000.00 can arrive as
 * 1999.9999999998 and silently render two clouds instead of three.
 */
export class CloudRule {
  /** Below this the clouds read as lint rather than weather. */
  static readonly MIN_SCALE = 0.42;

  constructor(
    readonly centavosPerCloud: number,
    readonly maxClouds: number,
  ) {
    if (centavosPerCloud <= 0) throw new Error('centavosPerCloud must be > 0');
    if (maxClouds <= 0) throw new Error('maxClouds must be > 0');
  }

  cloudsFor(outstandingCentavos: number): number {
    if (outstandingCentavos <= 0) return 0;
    return Math.ceil(outstandingCentavos / this.centavosPerCloud);
  }

  /**
   * Area-preserving shrink. Twenty clouds at sqrt(12/20) cover the same sky as
   * twelve at full size, so the total white stays constant and a heavy month
   * reads as finer grain rather than as a number the user has to parse.
   */
  scaleFor(cloudCount: number): number {
    if (cloudCount <= this.maxClouds) return 1;
    return Math.max(CloudRule.MIN_SCALE, Math.sqrt(this.maxClouds / cloudCount));
  }
}
