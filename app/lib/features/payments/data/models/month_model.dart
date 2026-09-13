import '../../../sky/domain/entities/cloud_rule.dart';
import '../../domain/entities/month.dart';
import 'payment_model.dart';

class MonthModel extends Month {
  const MonthModel({
    required super.id,
    required super.period,
    required super.rule,
    required super.payments,
  });

  factory MonthModel.fromJson(Map<String, dynamic> json) => MonthModel(
        id: json['id'] as String,
        period: DateTime.parse(json['period'] as String),
        rule: CloudRule.fromJson(json),
        payments: ((json['payments'] as List<dynamic>?) ?? const [])
            .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
