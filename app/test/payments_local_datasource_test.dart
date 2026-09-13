import 'dart:math';

import 'package:clouds/features/payments/data/datasources/payments_local_datasource.dart';
import 'package:clouds/features/payments/domain/usecases/suggest_centavos_per_cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  PaymentsLocalDataSource source() => PaymentsLocalDataSource(
        prefs,
        clock: () => DateTime.utc(2026, 9, 13, 8),
        random: Random(1),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('starts with no months', () async {
    expect(await source().fetchMonths(), isEmpty);
  });

  test('keeps months and bills across app restarts', () async {
    final first = source();
    final month = await first.createMonth(
      DateTime(2026, 9, 20),
      expectedTotalCentavos: 3000000,
    );
    final rent = await first.addPayment(
      month.id,
      label: 'Rent',
      amountCentavos: 1500000,
    );
    await first.addPayment(month.id, label: 'Phone', amountCentavos: 99900);
    final cleared = await first.clearPayment(month.id, rent.id);

    // A fresh instance reads only what reached SharedPreferences.
    final reopened = (await source().fetchMonths()).single;

    expect(reopened.id, month.id);
    expect(reopened.period, DateTime(2026, 9));
    expect(reopened.rule.centavosPerCloud, 250000);
    expect(reopened.payments.map((p) => p.label), ['Rent', 'Phone']);
    expect(reopened.payments.first.clearedAt, DateTime.utc(2026, 9, 13, 8));
    expect(reopened.payments.last.isCleared, isFalse);
    expect(reopened.outstandingCentavos, 99900);
    expect(cleared.cloudCount, reopened.cloudCount);
  });

  test('lists months oldest first', () async {
    final s = source();
    await s.createMonth(DateTime(2026, 11));
    await s.createMonth(DateTime(2026, 8));
    await s.createMonth(DateTime(2027, 1));

    expect(
      (await s.fetchMonths()).map((m) => m.period),
      [DateTime(2026, 8), DateTime(2026, 11), DateTime(2027, 1)],
    );
  });

  test('refuses a second month for the same period', () async {
    final s = source();
    await s.createMonth(DateTime(2026, 9));

    expect(
      () => s.createMonth(DateTime(2026, 9, 15)),
      throwsA(isA<LocalStoreException>()),
    );
    expect(await s.fetchMonths(), hasLength(1));
  });

  test('refuses to clear a bill twice', () async {
    final s = source();
    final month = await s.createMonth(DateTime(2026, 9));
    final bill =
        await s.addPayment(month.id, label: 'Water', amountCentavos: 50000);
    await s.clearPayment(month.id, bill.id);

    expect(
      () => s.clearPayment(month.id, bill.id),
      throwsA(isA<LocalStoreException>()),
    );
  });

  test('gives every month and bill its own id', () async {
    final s = PaymentsLocalDataSource(prefs);
    final month = await s.createMonth(DateTime(2026, 9));
    final ids = {
      month.id,
      for (var i = 0; i < 20; i++)
        (await s.addPayment(month.id, label: '$i', amountCentavos: 100)).id,
    };
    expect(ids, hasLength(21));
  });

  group('suggestCentavosPerCloud', () {
    test('uses the smallest step that fits in eighteen clouds', () {
      expect(suggestCentavosPerCloud(0), 100000);
      expect(suggestCentavosPerCloud(1800000), 100000);
      expect(suggestCentavosPerCloud(1800001), 250000);
      expect(suggestCentavosPerCloud(9000000), 500000);
    });

    test('tops out at the largest step', () {
      expect(suggestCentavosPerCloud(100000000), 1000000);
    });
  });
}
