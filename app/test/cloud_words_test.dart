import 'package:clouds/features/payments/presentation/widgets/cloud_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cloudPhrase', () {
    const cases = {
      1: '1 small cloud',
      3: '3 small clouds',
      5: '1 big cloud',
      10: '2 big clouds',
      6: '1 big cloud and 1 small',
      7: '1 big cloud and 2 small',
      23: '4 big clouds and 3 small',
    };
    cases.forEach((count, want) {
      test('$count clouds read as "$want"', () {
        expect(cloudPhrase(count), want);
      });
    });
  });

  group('cloudSummary', () {
    const cases = {
      0: 'Clear',
      1: '1 small cloud',
      4: '4 small clouds',
      5: '1 big cloud',
      10: '2 big clouds',
      13: '2 big, 3 small',
    };
    cases.forEach((count, want) {
      test('$count clouds read as "$want"', () {
        expect(cloudSummary(count), want);
      });
    });
  });
}
