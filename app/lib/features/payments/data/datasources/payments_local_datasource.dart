import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../sky/domain/entities/cloud_rule.dart';
import '../../domain/usecases/suggest_centavos_per_cloud.dart';
import '../models/month_model.dart';
import '../models/payment_model.dart';

class LocalStoreException implements Exception {
  LocalStoreException(this.message);
  final String message;
  @override
  String toString() => 'LocalStoreException: $message';
}

/// Keeps every month on the device, so the app runs offline with no backend.
///
/// The whole list lives under one SharedPreferences key as JSON. A year of
/// bills is a few kilobytes, and one key means a write can never leave a month
/// and its payments half-saved. Mirrors the rules the API enforces — unique
/// periods, no clearing twice — so swapping back to the remote source later
/// changes nothing the UI can observe.
class PaymentsLocalDataSource {
  PaymentsLocalDataSource(
    this._prefs, {
    DateTime Function()? clock,
    Random? random,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  /// Versioned so a future shape change can migrate instead of misreading.
  static const storageKey = 'clouds.months.v1';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final Random _random;

  Future<List<MonthModel>> fetchMonths() async => _read();

  Future<MonthModel> fetchMonth(String monthId) async =>
      _monthIn(_read(), monthId);

  Future<MonthModel> createMonth(
    DateTime period, {
    int? expectedTotalCentavos,
  }) async {
    final months = _read();
    if (months.any(
      (m) => m.period.year == period.year && m.period.month == period.month,
    )) {
      throw LocalStoreException('A month for that period already exists');
    }
    final created = MonthModel(
      id: _newId(),
      period: DateTime(period.year, period.month),
      rule: CloudRule(
        centavosPerCloud: suggestCentavosPerCloud(expectedTotalCentavos ?? 0),
        maxClouds: 12,
      ),
      payments: const [],
    );
    await _write([...months, created]);
    return created;
  }

  Future<PaymentModel> addPayment(
    String monthId, {
    required String label,
    required int amountCentavos,
  }) async {
    final months = _read();
    final month = _monthIn(months, monthId);
    final created = PaymentModel(
      id: _newId(),
      label: label,
      amountCentavos: amountCentavos,
      clearedAt: null,
    );
    final updated = month.withPayments([...month.payments, created]);
    await _write(_replace(months, updated));
    return created;
  }

  Future<({PaymentModel payment, int cloudCount})> clearPayment(
    String monthId,
    String paymentId,
  ) async {
    final months = _read();
    final month = _monthIn(months, monthId);
    final payment = month.payments.cast<PaymentModel?>().firstWhere(
          (p) => p!.id == paymentId,
          orElse: () => null,
        );
    if (payment == null) {
      throw LocalStoreException('No payment $paymentId in month $monthId');
    }
    if (payment.isCleared) {
      throw LocalStoreException('Payment already cleared');
    }

    final cleared = payment.withClearedAt(_clock());
    final updated = month.withPayments([
      for (final p in month.payments) p.id == paymentId ? cleared : p,
    ]);
    await _write(_replace(months, updated));
    return (payment: cleared, cloudCount: updated.cloudCount);
  }

  /// Oldest first, matching the API's `ORDER BY period`.
  List<MonthModel> _read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => MonthModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.period.compareTo(b.period));
  }

  Future<void> _write(List<MonthModel> months) async {
    final ok = await _prefs.setString(
      storageKey,
      jsonEncode([for (final m in months) m.toJson()]),
    );
    if (!ok) throw LocalStoreException('Could not save to the device');
  }

  MonthModel _monthIn(List<MonthModel> months, String monthId) =>
      months.firstWhere(
        (m) => m.id == monthId,
        orElse: () => throw LocalStoreException('No month $monthId'),
      );

  List<MonthModel> _replace(List<MonthModel> months, MonthModel month) => [
        for (final m in months) m.id == month.id ? month : m,
      ];

  /// Time-ordered and collision-safe for one person tapping on one device;
  /// no uuid package needed.
  String _newId() =>
      '${_clock().microsecondsSinceEpoch.toRadixString(36)}-'
      '${_random.nextInt(1 << 32).toRadixString(36)}';
}
