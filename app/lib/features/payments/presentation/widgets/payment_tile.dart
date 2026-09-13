import 'package:flutter/material.dart';

import '../../domain/entities/payment.dart';
import 'peso.dart';

class PaymentTile extends StatelessWidget {
  const PaymentTile({required this.payment, required this.onTap, super.key});

  final Payment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cleared = payment.isCleared;
    return Opacity(
      opacity: cleared ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: cleared ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    payment.label,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  cleared ? 'Cleared' : formatPeso(payment.amountCentavos),
                  style: TextStyle(
                    fontSize: 14,
                    color: cleared
                        ? const Color(0xFF0F6E56)
                        : const Color(0xFF1B2733),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
