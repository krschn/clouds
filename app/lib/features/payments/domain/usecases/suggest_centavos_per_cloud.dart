/// Picks a cloud denominator that lands the month in a readable band.
///
/// Mirrored in TypeScript at backend/src/months/domain/suggest-denomination.ts,
/// now that months are created on the device.
///
/// Called ONCE, at month creation, and then frozen on the month. It must never
/// be recomputed from the live balance: if the denominator floats, adding a
/// bill mid-month can rescale the whole sky and even reduce the cloud count, or
/// make clearing a payment remove fewer clouds than the modal just promised.
const List<int> _ladder = [100000, 250000, 500000, 1000000]; // 1k, 2.5k, 5k, 10k
const int _targetMaxClouds = 18;

int suggestCentavosPerCloud(int expectedTotalCentavos) {
  for (final step in _ladder) {
    // Integer ceiling division, same as CloudRule.cloudsFor.
    if ((expectedTotalCentavos + step - 1) ~/ step <= _targetMaxClouds) {
      return step;
    }
  }
  return _ladder.last;
}
