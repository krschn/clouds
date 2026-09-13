import '../../../sky/domain/entities/cloud_rule.dart';
import '../../domain/entities/month.dart';
import 'payment_model.dart';

class MonthModel extends Month {
  const MonthModel({
    required super.id,
    required super.period,
    required super.rule,
    required List<PaymentModel> super.payments,
  });

  factory MonthModel.fromJson(Map<String, dynamic> json) => MonthModel(
        id: json['id'] as String,
        period: DateTime.parse(json['period'] as String),
        rule: CloudRule.fromJson(json),
        payments: ((json['payments'] as List<dynamic>?) ?? const [])
            .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<PaymentModel> get payments => super.payments.cast<PaymentModel>();

  MonthModel withPayments(List<PaymentModel> payments) => MonthModel(
        id: id,
        period: period,
        rule: rule,
        payments: payments,
      );

  /// Same shape the API returns, so either source reads the other's JSON.
  Map<String, dynamic> toJson() {
    final y = period.year.toString().padLeft(4, '0');
    final m = period.month.toString().padLeft(2, '0');
    return {
      'id': id,
      // A date, not a timestamp: a local midnight written as UTC could land
      // on the previous day when read back.
      'period': '$y-$m-01',
      'centavosPerCloud': rule.centavosPerCloud,
      'maxClouds': rule.maxClouds,
      'payments': [for (final p in payments) p.toJson()],
    };
  }
}
