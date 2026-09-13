import 'package:flutter/material.dart';

import '../../domain/entities/payment.dart';
import 'peso.dart';

/// Hold-to-clear. 700ms is near the floor for a gesture that should feel
/// deliberate: under ~500ms people trigger it by accident, over ~1200ms it
/// feels like the app does not trust them.
class PaymentModal extends StatefulWidget {
  const PaymentModal({
    required this.payment,
    required this.cloudsRemoved,
    required this.onCleared,
    super.key,
  });

  final Payment payment;
  final int cloudsRemoved;
  final VoidCallback onCleared;

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal>
    with SingleTickerProviderStateMixin {
  static const Duration _hold = Duration(milliseconds: 700);
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: _hold,
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _commit();
    });
  bool _done = false;

  void _commit() {
    if (_done) return;
    _done = true;
    widget.onCleared();
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
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
            n == 1 ? 'Clears 1 cloud' : 'Clears $n clouds',
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFFE6F1FB)),
                    AnimatedBuilder(
                      animation: _fill,
                      builder: (context, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _fill.value,
                          child: const ColoredBox(color: Color(0xFFEF9F27)),
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
        ],
      ),
    );
  }
}
