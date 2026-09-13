import '../../../sky/domain/entities/cloud_rule.dart';
import 'payment.dart';

class Month {
  const Month({
    required this.id,
    required this.period,
    required this.rule,
    required this.payments,
  });

  final String id;
  final DateTime period;

  /// Frozen at creation. Editing it redraws the whole sky, so
  /// the UI confirms first.
  final CloudRule rule;
  final List<Payment> payments;

  int get outstandingCentavos => payments.fold(
        0,
        (sum, p) => p.isCleared ? sum : sum + p.amountCentavos,
      );

  int get cloudCount => rule.cloudsFor(outstandingCentavos);

  Month copyWith({List<Payment>? payments}) => Month(
        id: id,
        period: period,
        rule: rule,
        payments: payments ?? this.payments,
      );
}
