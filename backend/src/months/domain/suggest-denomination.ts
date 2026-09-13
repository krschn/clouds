/**
 * Picks a cloud denominator that lands the month in a readable band.
 *
 * Called ONCE, at month creation, and then frozen on the row. It must never be
 * recomputed from the live balance: if the denominator floats, adding a bill
 * mid-month can rescale the whole sky and even reduce the cloud count, or make
 * clearing a payment remove fewer clouds than the modal just promised. Either
 * one guts the feeling the app exists for.
 */
const LADDER = [100_000, 250_000, 500_000, 1_000_000]; // centavos: 1k, 2.5k, 5k, 10k
const TARGET_MAX_CLOUDS = 18;

export function suggestCentavosPerCloud(expectedTotalCentavos: number): number {
  for (const step of LADDER) {
    if (Math.ceil(expectedTotalCentavos / step) <= TARGET_MAX_CLOUDS) return step;
  }
  return LADDER[LADDER.length - 1];
}
