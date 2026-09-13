import '../../domain/entities/payment.dart';

class PaymentModel extends Payment {
  const PaymentModel({
    required super.id,
    required super.label,
    required super.amountCentavos,
    required super.clearedAt,
    super.source,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id'] as String,
        label: json['label'] as String,
        amountCentavos: json['amountCentavos'] as int,
        clearedAt: json['clearedAt'] == null
            ? null
            : DateTime.parse(json['clearedAt'] as String),
        source: (json['source'] as String?) ?? 'manual',
      );

  PaymentModel withClearedAt(DateTime at) => PaymentModel(
        id: id,
        label: label,
        amountCentavos: amountCentavos,
        clearedAt: at,
        source: source,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amountCentavos': amountCentavos,
        // UTC so the stored instant does not shift with the device's zone.
        'clearedAt': clearedAt?.toUtc().toIso8601String(),
        'source': source,
      };
}
