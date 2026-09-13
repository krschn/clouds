import 'package:clouds/features/payments/domain/entities/month.dart';
import 'package:clouds/features/payments/domain/entities/payment.dart';
import 'package:clouds/features/payments/domain/repositories/payments_repository.dart';
import 'package:clouds/features/sky/domain/entities/cloud_rule.dart';
import 'package:clouds/features/sky/presentation/controllers/sky_haptics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a frame at a time so the sky's ticker sees realistic 60fps deltas.
/// The sky caps each tick at 1/20s, so one long pump would barely move it.
///
/// Also how tests end with the sky at rest: testWidgets fails a test whose
/// ticker is still scheduled when the body returns.
Future<void> settle(WidgetTester tester, {double seconds = 4}) async {
  for (var i = 0; i < seconds * 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Stands in for the HTTP-backed repository. Each call can be made to fail.
class FakePaymentsRepository implements PaymentsRepository {
  FakePaymentsRepository(this.months);

  List<Month> months;
  bool failCreateMonth = false;
  bool failAddPayment = false;
  bool failClearPayment = false;

  final List<({DateTime period, int? expectedTotalCentavos})> createMonthCalls =
      [];

  /// The rule the "server" picks for a new month.
  CloudRule createdRule =
      const CloudRule(centavosPerCloud: 250000, maxClouds: 12);

  @override
  Future<List<Month>> fetchMonths() async => months;

  @override
  Future<Month> fetchMonth(String monthId) async =>
      months.firstWhere((m) => m.id == monthId);

  @override
  Future<Month> createMonth(
    DateTime period, {
    int? expectedTotalCentavos,
  }) async {
    createMonthCalls.add(
      (period: period, expectedTotalCentavos: expectedTotalCentavos),
    );
    if (failCreateMonth) throw Exception('duplicate period');
    return Month(
      id: 'new-month',
      period: period,
      rule: createdRule,
      payments: const [],
    );
  }

  @override
  Future<Payment> addPayment(
    String monthId, {
    required String label,
    required int amountCentavos,
  }) async {
    if (failAddPayment) throw Exception('offline');
    return Payment(
      id: 'new-payment',
      label: label,
      amountCentavos: amountCentavos,
      clearedAt: null,
    );
  }

  @override
  Future<({Payment payment, int cloudCount})> clearPayment(
    String monthId,
    String paymentId,
  ) async {
    if (failClearPayment) throw Exception('offline');
    final month = months.firstWhere((m) => m.id == monthId);
    final p = month.payments.firstWhere((p) => p.id == paymentId);
    final cleared = p.copyWith(clearedAt: DateTime(2026, 9, 13));
    final after = month.copyWith(
      payments: [
        for (final x in month.payments) x.id == paymentId ? cleared : x,
      ],
    );
    return (payment: cleared, cloudCount: after.cloudCount);
  }
}

class RecordingHaptics implements SkyHaptics {
  int bursts = 0;
  int finales = 0;
  int landings = 0;

  @override
  void burst() => bursts++;

  @override
  void finale() => finales++;

  @override
  void land() => landings++;
}

Payment bill(String id, int centavos, {bool cleared = false}) => Payment(
      id: id,
      label: id,
      amountCentavos: centavos,
      clearedAt: cleared ? DateTime(2026, 9, 1) : null,
    );

Month monthOf(
  String id,
  DateTime period,
  List<Payment> payments, {
  int centavosPerCloud = 100000,
}) =>
    Month(
      id: id,
      period: period,
      rule: CloudRule(centavosPerCloud: centavosPerCloud, maxClouds: 12),
      payments: payments,
    );
