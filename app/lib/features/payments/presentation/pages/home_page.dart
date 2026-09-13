import 'package:flutter/material.dart';

import '../../../sky/presentation/controllers/sky_controller.dart';
import '../../../sky/presentation/widgets/sky_view.dart';
import '../../domain/entities/payment.dart';
import '../controllers/month_controller.dart';
import '../widgets/month_drawer.dart';
import '../widgets/payment_modal.dart';
import '../widgets/payment_tile.dart';
import '../widgets/peso.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.controller, required this.sky, super.key});

  final MonthController controller;
  final SkyController sky;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final month = controller.current;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F8FC),
          drawer: MonthDrawer(
            months: controller.months,
            currentId: month?.id,
            onSelect: controller.selectMonth,
          ),
          body: month == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      flex: 51,
                      child: Stack(
                        children: [
                          Positioned.fill(child: SkyView(controller: sky)),
                          SafeArea(
                            child: Builder(
                              builder: (context) => IconButton(
                                icon: const Icon(Icons.menu),
                                color: const Color(0xFF0C447C),
                                onPressed: Scaffold.of(context).openDrawer,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: Text(
                              month.cloudCount == 0
                                  ? 'Cleared'
                                  : '${month.cloudCount} clouds  \u00B7  '
                                      '${formatPeso(month.outstandingCentavos)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0C447C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 49,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: month.payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (context, i) {
                          final p = month.payments[i];
                          return PaymentTile(
                            payment: p,
                            onTap: () => _openModal(context, p),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _openModal(BuildContext context, Payment payment) {
    final month = controller.current!;
    // How many clouds this payment actually removes, given everything else
    // still outstanding. Not amount/denominator — ceiling division means the
    // last payment of a month can clear a cloud that was only part-owed.
    final before = month.cloudCount;
    final after = month.rule
        .cloudsFor(month.outstandingCentavos - payment.amountCentavos);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => PaymentModal(
        payment: payment,
        cloudsRemoved: before - after,
        onCleared: () => controller.clear(payment),
      ),
    );
  }
}
