import '../entities/month.dart';
import '../entities/payment.dart';

abstract class PaymentsRepository {
  Future<List<Month>> fetchMonths();
  Future<Month> fetchMonth(String monthId);
  Future<Payment> addPayment(
    String monthId, {
    required String label,
    required int amountCentavos,
  });

  /// Returns the server's authoritative cloud count so the caller can
  /// reconcile whatever it rendered optimistically.
  Future<({Payment payment, int cloudCount})> clearPayment(
    String monthId,
    String paymentId,
  );
}
