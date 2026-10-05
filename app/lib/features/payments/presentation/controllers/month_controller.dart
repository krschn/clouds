import 'package:flutter/foundation.dart';

import '../../../sky/domain/entities/cloud_sprite.dart';
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
      // Copied into a real List<Month>. The store hands back its own
      // List<MonthModel>, and Dart checks callbacks against the runtime type,
      // so a reduce or add with plain Months would throw on it.
      months = List<Month>.of(await _repo.fetchMonths());
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

  /// Creates an empty month and switches to it. Returns whether it worked, so
  /// the sheet can stay open with the choice intact when it did not.
  ///
  /// [expectedTotalCentavos] only sizes the clouds. The store freezes that
  /// size at creation, so an empty month sent without an estimate would be
  /// stuck with the smallest denomination however large its bills turn out.
  Future<bool> createMonth(
    DateTime period, {
    int? expectedTotalCentavos,
  }) async {
    try {
      final created = await _repo.createMonth(
        DateTime(period.year, period.month),
        expectedTotalCentavos: expectedTotalCentavos,
      );
      months = [...months, created]
        ..sort((a, b) => a.period.compareTo(b.period));
      error = null;
      selectMonth(created);
      return true;
    } catch (e) {
      error = "Couldn't create that month.";
      notifyListeners();
      return false;
    }
  }

  /// The month after the latest one, or this month when there are none.
  DateTime suggestedNewPeriod({DateTime? now}) {
    final latest = _latest;
    if (latest == null) {
      final today = now ?? DateTime.now();
      return DateTime(today.year, today.month);
    }
    // DateTime normalises month 13 into January of the next year.
    return DateTime(latest.period.year, latest.period.month + 1);
  }

  /// The latest month's whole bill total, cleared bills included — what that
  /// month actually cost, which is the best guess at what the next will.
  int? get suggestedEstimateCentavos =>
      _latest?.payments.fold<int>(0, (sum, p) => sum + p.amountCentavos);

  /// Periods are unique; picking a taken one would be rejected.
  bool hasMonthFor(DateTime period) => months.any(
        (m) =>
            m.period.year == period.year && m.period.month == period.month,
      );

  Month? get _latest => months.isEmpty
      ? null
      : months.reduce((a, b) => a.period.isAfter(b.period) ? a : b);

  /// Optimistic clear: the clouds go immediately, and come back if the store
  /// disagrees. They come back by condensing — the evaporate played backwards,
  /// slower, in the same places — because a setback should not look like a
  /// new bill arriving.
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

      // Reconcile against the store's own count. A mismatch here means
      // something else touched this month — an external feed, another device —
      // and the sky should follow the store, not our guess.
      if (result.cloudCount != optimistic.cloudCount) {
        _sky.syncTo(result.cloudCount);
      }
    } catch (e) {
      final reverted = month.copyWith(payments: before);
      current = reverted;
      _replaceInList(reverted);
      _sky.syncTo(reverted.cloudCount, entry: CloudEntry.condense);
      error = 'Could not clear that payment. Put it back.';
      notifyListeners();
    }
  }

  /// Returns whether the bill was saved, so the sheet can keep what was typed
  /// when it was not.
  Future<bool> addPayment(String label, int amountCentavos) async {
    final month = current;
    if (month == null) return false;
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
      error = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = 'Could not add that bill.';
      notifyListeners();
      return false;
    }
  }

  void _replaceInList(Month m) {
    months = [
      for (final x in months)
        if (x.id == m.id) m else x,
    ];
  }
}
