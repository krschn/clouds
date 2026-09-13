import 'package:flutter/material.dart';

import '../../domain/entities/payment.dart';
import 'cloud_card.dart';
import 'peso.dart';

/// One bill as a small white cloud: the total cloud in miniature, with low
/// puffs and a light shadow so it never competes with it. Paid bills fade to a
/// flat, see-through cloud with the amount struck out.
class PaymentTile extends StatelessWidget {
  const PaymentTile({
    required this.payment,
    this.onTap,
    this.puffsOnRight = false,
    super.key,
  });

  final Payment payment;
  final VoidCallback? onTap;

  /// Alternated down the list so the clouds don't stack into a column.
  final bool puffsOnRight;

  static const List<CardPuff> _puffs = [
    CardPuff(30, 10, 12),
    CardPuff(52, 8, 17),
    CardPuff(74, 9, 11),
  ];

  static const Color _navy = Color(0xFF0C447C);
  static const Color _ink = Color(0xFF1B2733);
  static const Color _muted = Color(0xFF5F6B76);

  @override
  Widget build(BuildContext context) {
    final cleared = payment.isCleared;
    final tap = cleared ? null : onTap;

    final card = CloudCard(
      fill: cleared ? Colors.white.withValues(alpha: 0.45) : Colors.white,
      puffs: _puffs,
      rise: 12,
      elevation: cleared ? 0 : 1.5,
      puffsOnRight: puffsOnRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                payment.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cleared ? _muted : _ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatPeso(payment.amountCentavos),
              style: TextStyle(
                fontSize: 15,
                fontWeight: cleared ? FontWeight.w400 : FontWeight.w600,
                color: cleared ? _muted : _navy,
                decoration: cleared ? TextDecoration.lineThrough : null,
                decorationColor: _muted,
              ),
            ),
          ],
        ),
      ),
    );

    return tap == null ? card : Squish(onTap: tap, child: card);
  }
}
