import 'package:flutter/material.dart';

import 'cloud_card.dart';
import 'peso.dart';

/// What is still left to pay, on a wide storm cloud at the top of the list.
///
/// Heavier than the white bill clouds on purpose: it holds all of them. Once
/// nothing is owed it lightens to a clear-day cloud.
class TotalCloud extends StatelessWidget {
  const TotalCloud({required this.outstandingCentavos, super.key});

  final int outstandingCentavos;

  static const Color _storm = Color(0xFF0C447C);
  static const Color _clear = Colors.white;

  // Overlapping, tallest in the middle, gathered on the left so the right
  // edge stays flat under the add button.
  static const List<CardPuff> _puffs = [
    CardPuff(54, 14, 26),
    CardPuff(100, 8, 30),
    CardPuff(142, 14, 20),
  ];

  @override
  Widget build(BuildContext context) {
    final clear = outstandingCentavos == 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: clear ? 1 : 0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        final ink = Color.lerp(Colors.white, _storm, t)!;
        return CloudCard(
          fill: Color.lerp(_storm, _clear, t)!,
          puffs: _puffs,
          rise: 22,
          radius: 20,
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clear ? 'All clear' : 'Left to pay',
                  style: TextStyle(
                    fontSize: 13,
                    color: ink.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatPeso(outstandingCentavos),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
