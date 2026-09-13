import 'package:clouds/features/sky/domain/usecases/group_clouds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = {
    0: (big: 0, small: 0),
    4: (big: 0, small: 4),
    5: (big: 1, small: 0),
    23: (big: 4, small: 3),
    81: (big: 16, small: 1),
  };
  cases.forEach((count, want) {
    test('$count clouds draw as ${want.big} big and ${want.small} small', () {
      expect(cloudGroups(count), want);
    });
  });

  test('a negative count draws nothing', () {
    expect(cloudGroups(-3), (big: 0, small: 0));
  });
}
