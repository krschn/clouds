import 'package:flutter/foundation.dart';

import '../../../sky/presentation/controllers/sky_controller.dart';
import '../../domain/entities/month.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payments_repository.dart';

enum LoadState { idle, loading, ready, failed }

/// Owns the month's data and keeps the sky in step with it.
///
/// The sky is told what to do imperatively rather than rebuilt from state,
/// because "three clouds left" and "three clouds are leaving right now" are
/// different things and only the second one is an animation.
class MonthController extends ChangeNotifier {
  MonthController({
    required PaymentsRepository repository,
    required SkyController sky,
  })  : _repo = repository,
        _sky = sky;

  final PaymentsRepository _repo;
  final SkyController _sky;

  LoadState state = LoadState.idle;
  List<Month> months = const [];
  Month? current;
  String? error;

  Future<void> load() async {
    state = LoadState.loading;
    notifyListeners();
    try {
      months = await _repo.fetchMonths();
      current = months.isEmpty ? null : months.first;
      if (current != null) {
        _sky.updateRule(current!.rule);
        _sky.syncTo(current!.cloudCount, animate: false);
      }
      state = LoadState.ready;
    } catch (e) {
      error = e.toString();
      state = LoadState.failed;
    }
    notifyListeners();
  }

  void selectMonth(Month month) {
    current = month;
    _sky.updateRule(month.rule);
    // animate: false — switching months is navigation, not an achievement.
    // Evaporating the old month's clouds would read as if you had just paid
    // them off.
    _sky.syncTo(month.cloudCount, animate: false);
    notifyListeners();
  }

  /// Optimistic clear: the clouds go immediately, and come back if the server
  /// disagrees.
  ///
  /// The rollback is the honest rough edge here. Clouds reappear with the
  /// pop-in used for newly added bills, which is cheerful in a moment that
  /// should feel like a setback. A dedicated "condense" animation — the
  /// evaporate curve played backwards, slower — is the right fix and is not
  /// built yet.
  Future<void> clear(Payment payment) async {
    final month = current;
    if (month == null || payment.isCleared) return;

    final before = month.payments;
    final optimistic = month.copyWith(
      payments: [
        for (final p in before)
          if (p.id == payment.id) p.copyWith(clearedAt: DateTime.now()) else p,
      ],
    );

    current = optimistic;
    _replaceInList(optimistic);
    _sky.syncTo(optimistic.cloudCount);
    notifyListeners();

    try {
      final result = await _repo.clearPayment(month.id, payment.id);

      // Reconcile against the server's own count. A mismatch here means
      // something else touched this month — an external feed, another device —
      // and the sky should follow the server, not our guess.
      if (result.cloudCount != optimistic.cloudCount) {
        _sky.syncTo(result.cloudCount);
      }
    } catch (e) {
      final reverted = month.copyWith(payments: before);
      current = reverted;
      _replaceInList(reverted);
      _sky.syncTo(reverted.cloudCount);
      error = 'Could not clear that payment. Put it back.';
      notifyListeners();
    }
  }

  Future<void> addPayment(String label, int amountCentavos) async {
    final month = current;
    if (month == null) return;
    try {
      final created = await _repo.addPayment(
        month.id,
        label: label,
        amountCentavos: amountCentavos,
      );
      final updated = month.copyWith(payments: [...month.payments, created]);
      current = updated;
      _replaceInList(updated);
      _sky.syncTo(updated.cloudCount);
      notifyListeners();
    } catch (e) {
      error = 'Could not add that bill.';
      notifyListeners();
    }
  }

  void _replaceInList(Month m) {
    months = [
      for (final x in months)
        if (x.id == m.id) m else x,
    ];
  }
}
