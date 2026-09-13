import '../../domain/entities/month.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payments_repository.dart';
import '../datasources/payments_remote_datasource.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  PaymentsRepositoryImpl(this._remote);

  final PaymentsRemoteDataSource _remote;

  @override
  Future<List<Month>> fetchMonths() => _remote.fetchMonths();

  @override
  Future<Month> fetchMonth(String monthId) => _remote.fetchMonth(monthId);

  @override
  Future<Payment> addPayment(
    String monthId, {
    required String label,
    required int amountCentavos,
  }) =>
      _remote.addPayment(
        monthId,
        label: label,
        amountCentavos: amountCentavos,
      );

  @override
  Future<({Payment payment, int cloudCount})> clearPayment(
    String monthId,
    String paymentId,
  ) async {
    final r = await _remote.clearPayment(monthId, paymentId);
    return (payment: r.payment as Payment, cloudCount: r.cloudCount);
  }
}
