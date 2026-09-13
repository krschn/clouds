import '../../domain/entities/month.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payments_repository.dart';
import '../datasources/payments_local_datasource.dart';

/// The repository the app runs on: everything on the device, nothing over the
/// network. [PaymentsRepositoryImpl] is the API-backed twin, kept for when the
/// backend comes back into the loop.
class LocalPaymentsRepository implements PaymentsRepository {
  LocalPaymentsRepository(this._local);

  final PaymentsLocalDataSource _local;

  @override
  Future<List<Month>> fetchMonths() => _local.fetchMonths();

  @override
  Future<Month> fetchMonth(String monthId) => _local.fetchMonth(monthId);

  @override
  Future<Month> createMonth(DateTime period, {int? expectedTotalCentavos}) =>
      _local.createMonth(period, expectedTotalCentavos: expectedTotalCentavos);

  @override
  Future<Payment> addPayment(
    String monthId, {
    required String label,
    required int amountCentavos,
  }) =>
      _local.addPayment(
        monthId,
        label: label,
        amountCentavos: amountCentavos,
      );

  @override
  Future<({Payment payment, int cloudCount})> clearPayment(
    String monthId,
    String paymentId,
  ) async {
    final r = await _local.clearPayment(monthId, paymentId);
    return (payment: r.payment as Payment, cloudCount: r.cloudCount);
  }
}
