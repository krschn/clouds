import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/payment.dart';
import 'cloud_words.dart';
import 'peso.dart';

/// Hold-to-clear. 700ms is near the floor for a gesture that should feel
/// deliberate: under ~500ms people trigger it by accident, over ~1200ms it
/// feels like the app does not trust them.
class PaymentModal extends StatefulWidget {
  const PaymentModal({
    required this.payment,
    required this.cloudsRemoved,
    required this.onCleared,
    this.onHoldProgress,
    super.key,
  });

  final Payment payment;
  final int cloudsRemoved;
  final VoidCallback onCleared;

  /// 0 → 1 as the hold fills, and back down if released. Lets the sky make
  /// the clouds that are about to go tremble.
  final ValueChanged<double>? onHoldProgress;

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal>
    with SingleTickerProviderStateMixin {
  static const Duration _hold = Duration(milliseconds: 700);
  static const Color _orange = Color(0xFFEF9F27);

  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: _hold,
  )
    ..addListener(_onFill)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _commit();
    });
  bool _done = false;

  /// Quarter marks already passed on this hold, for the rising haptic ticks.
  int _quarters = 0;

  void _onFill() {
    // Once committed, the hold is over. The finger lifting, or the gesture
    // being cancelled as the sheet closes, drains the bar back down — and
    // reporting that would make clouds that survived the clear tremble, stuck
    // wherever the drain was when the sheet was disposed.
    if (_done) return;
    widget.onHoldProgress?.call(_fill.value);
    final quarters = (_fill.value * 4).floor().clamp(0, 3);
    if (quarters > _quarters && _fill.status == AnimationStatus.forward) {
      // Each tick harder than the last, so the hold builds toward the commit.
      switch (quarters) {
        case 1:
          HapticFeedback.selectionClick();
        case 2:
          HapticFeedback.lightImpact();
        case 3:
          HapticFeedback.mediumImpact();
      }
    }
    _quarters = quarters;
  }

  void _commit() {
    if (_done) return;
    _done = true;
    HapticFeedback.heavyImpact();
    widget.onCleared();
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    // Dismissed mid-hold: calm the clouds back down.
    if (!_done) widget.onHoldProgress?.call(0);
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.cloudsRemoved;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.payment.label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Clears ${cloudPhrase(n)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF5F6E80)),
          ),
          const SizedBox(height: 16),
          Text(
            formatPeso(widget.payment.amountCentavos),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTapDown: (_) => _fill.forward(),
            onTapUp: (_) => _fill.reverse(),
            onTapCancel: () => _fill.reverse(),
            child: AnimatedBuilder(
              animation: _fill,
              builder: (context, _) {
                final v = _fill.value;
                // Slow to start, quick at the end: the last stretch is where
                // the hold should feel like it is about to give.
                final width = Curves.easeIn.transform(v);
                return Transform.scale(
                  scale: 1 - 0.03 * v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _orange.withValues(alpha: 0.45 * v),
                          blurRadius: 18 * v,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 50,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFFE6F1FB)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: width,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFAC775),
                                        _orange,
                                      ],
                                    ),
                                  ),
                                  // A bright leading edge, so the fill reads
                                  // as light advancing rather than a bar.
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: SizedBox(
                                      width: 6,
                                      child: ColoredBox(
                                        color: Color(0x8CFFFFFF),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Center(
                              child: Text(
                                'Hold to clear',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0C447C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
