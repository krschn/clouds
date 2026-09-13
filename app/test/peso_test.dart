import 'package:cloud_payments/features/payments/presentation/widgets/peso.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePesoToCentavos', () {
    const valid = {
      '1500': 150000,
      '1,500': 150000,
      '1,500.5': 150050,
      '2000.25': 200025,
      '₱2,000.25': 200025,
      '  12.05 ': 1205,
      '0.01': 1,
      '.5': 50,
      // The largest amount a Postgres int column holds.
      '21474836.47': 2147483647,
    };
    valid.forEach((input, want) {
      test('"$input" is $want centavos', () {
        expect(parsePesoToCentavos(input), want);
      });
    });

    const invalid = [
      '',
      '   ',
      '0',
      '0.00',
      '.',
      'abc',
      '12a',
      '1.234',
      '1.2.3',
      '-5',
      '21474836.48',
    ];
    for (final input in invalid) {
      test('"$input" is rejected', () {
        expect(parsePesoToCentavos(input), isNull);
      });
    }
  });
}
