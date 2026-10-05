import 'package:flutter/material.dart';

import '../../domain/entities/payment.dart';
import 'cloud_card.dart';
import 'payment_tile.dart';
import 'peso.dart';

/// Paid bills, folded into one pale cloud under the ones still owed so they
/// never crowd them. Tap to look inside.
class ClearedGroup extends StatefulWidget {
  const ClearedGroup({required this.payments, super.key});

  final List<Payment> payments;

  @override
  State<ClearedGroup> createState() => _ClearedGroupState();
}

class _ClearedGroupState extends State<ClearedGroup> {
  bool _open = false;

  static const List<CardPuff> _puffs = [
    CardPuff(28, 9, 11),
    CardPuff(46, 7, 13),
  ];

  static const Color _green = Color(0xFF0F6E56);
  static const Color _muted = Color(0xFF5F6B76);

  @override
  Widget build(BuildContext context) {
    final payments = widget.payments;
    final total = payments.fold<int>(0, (sum, p) => sum + p.amountCentavos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: CloudCard(
              fill: Colors.white.withValues(alpha: 0.6),
              puffs: _puffs,
              rise: 10,
              radius: 14,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: _green),
                    const SizedBox(width: 8),
                    Text(
                      'Cleared  ·  ${payments.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _green,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatPeso(total),
                      style: const TextStyle(fontSize: 14, color: _muted),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more,
                        size: 20,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, p) in payments.indexed) ...[
                      const SizedBox(height: 8),
                      PaymentTile(payment: p, puffsOnRight: i.isEven),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
