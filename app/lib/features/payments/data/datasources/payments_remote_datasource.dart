import '../../../../core/network/api_client.dart';
import '../models/month_model.dart';
import '../models/payment_model.dart';

class PaymentsRemoteDataSource {
  PaymentsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<MonthModel>> fetchMonths() async {
    final json = await _api.get('/months') as List<dynamic>;
    return json
        .map((e) => MonthModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MonthModel> fetchMonth(String monthId) async {
    final json = await _api.get('/months/$monthId') as Map<String, dynamic>;
    return MonthModel.fromJson(json);
  }

  Future<PaymentModel> addPayment(
    String monthId, {
    required String label,
    required int amountCentavos,
  }) async {
    final json = await _api.post(
      '/months/$monthId/payments',
      body: {'label': label, 'amountCentavos': amountCentavos},
    ) as Map<String, dynamic>;
    return PaymentModel.fromJson(json);
  }

  Future<({PaymentModel payment, int cloudCount})> clearPayment(
    String monthId,
    String paymentId,
  ) async {
    final json = await _api.post('/months/$monthId/payments/$paymentId/clear')
        as Map<String, dynamic>;
    return (
      payment: PaymentModel.fromJson(json['payment'] as Map<String, dynamic>),
      cloudCount: (json['sky'] as Map<String, dynamic>)['cloudCount'] as int,
    );
  }
}
