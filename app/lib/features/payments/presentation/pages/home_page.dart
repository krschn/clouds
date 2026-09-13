import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../sky/presentation/controllers/sky_controller.dart';
import '../../../sky/presentation/painters/sky_palette.dart';
import '../../../sky/presentation/widgets/sky_view.dart';
import '../../domain/entities/month.dart';
import '../../domain/entities/payment.dart';
import '../controllers/month_controller.dart';
import '../widgets/add_bill_sheet.dart';
import '../widgets/cleared_group.dart';
import '../widgets/cloud_add_button.dart';
import '../widgets/month_drawer.dart';
import '../widgets/new_month_sheet.dart';
import '../widgets/payment_modal.dart';
import '../widgets/payment_tile.dart';
import '../widgets/total_cloud.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.controller, required this.sky, super.key});

  final MonthController controller;
  final SkyController sky;

  static const int _skyFlex = 51;
  static const int _listFlex = 49;
  static const Size _addButtonSize = Size(84, 58);
  static const double _addButtonInset = 16;

  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const RoundedRectangleBorder _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  );

  @override
  Widget build(BuildContext context) {
    // Only the colours listen to the sky. It notifies every animation frame,
    // and the scaffold below is passed as `child` so it is not rebuilt with
    // them.
    return AnimatedBuilder(
      animation: sky,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _scaffold(context),
      ),
      builder: (context, child) {
        final palette = paletteFor(sky.gloom);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: palette.darkChrome
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: ColoredBox(color: palette.page, child: child),
        );
      },
    );
  }

  Widget _scaffold(BuildContext context) {
    final month = controller.current;
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: MonthDrawer(
        months: controller.months,
        currentId: month?.id,
        onSelect: controller.selectMonth,
        onNewMonth: () => _openNewMonth(context),
      ),
      body: switch (controller.state) {
        _ when month != null => _monthBody(context, month),
        LoadState.failed => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Couldn't load your months.",
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: controller.load,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0C447C),
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        LoadState.ready => Center(
            child: _EmptyCloud(
              label: 'Create your first month',
              onPressed: () => _openNewMonth(context),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _monthBody(BuildContext context, Month month) {
    return LayoutBuilder(
      builder: (context, box) {
        final total = (_skyFlex + _listFlex).toDouble();
        final skyHeight = box.maxHeight * _skyFlex / total;
        final listHeight = box.maxHeight * _listFlex / total;
        final empty = month.payments.isEmpty;

        // Launched clouds start under whichever cloud was tapped, in the
        // sky's unit coordinates. Assigned rather than notified: the sky only
        // reads it when a bill is added.
        // Sky coordinates are measured in the area below the notch (see
        // skyStage), so the launch point goes through the same inset.
        final topInset = MediaQuery.paddingOf(context).top;
        sky.launchFrom = empty
            ? Offset(
                0.5,
                (skyHeight +
                        listHeight / 2 -
                        _EmptyCloud.centreAboveMiddle -
                        topInset) /
                    (skyHeight - topInset),
              )
            : Offset(
                (box.maxWidth - _addButtonInset - _addButtonSize.width / 2) /
                    box.maxWidth,
                1,
              );

        return Stack(
          children: [
            Column(
              // stretch, not the default center. The sky Stack's only
              // non-positioned child is the menu button, so a centered Stack
              // shrinks to the button's 40px and the sky and caption (both
              // positioned) render as a thin strip.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: _skyFlex,
                  child: Stack(
                    children: [
                      Positioned.fill(child: SkyView(controller: sky)),
                      // The months drawer opens from a cloud that names the
                      // month on screen, pairing with the add cloud opposite.
                      // White with navy text, so it reads at any gloom.
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
                          child: Builder(
                            builder: (context) => CloudAddButton(
                              size: const Size(66, 46),
                              bob: false,
                              semanticLabel: 'Months',
                              label: _shortMonths[month.period.month - 1],
                              onPressed: Scaffold.of(context).openDrawer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: _listFlex,
                  child: empty
                      ? Center(
                          child: _EmptyCloud(
                            label: 'Add your first bill',
                            onPressed: () => _openAddBill(context),
                          ),
                        )
                      : _billList(context, month),
                ),
              ],
            ),
            // Hidden while the month is empty, so there is only ever one
            // cloud to tap.
            if (!empty)
              Positioned(
                right: _addButtonInset,
                top: skyHeight - _addButtonSize.height / 2,
                child: CloudAddButton(
                  size: _addButtonSize,
                  recoil: sky.launches,
                  onPressed: () => _openAddBill(context),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The total, then what is still owed, then everything already paid folded
  /// into one group at the bottom.
  Widget _billList(BuildContext context, Month month) {
    final owed = [
      for (final p in month.payments)
        if (!p.isCleared) p,
    ];
    final cleared = [
      for (final p in month.payments)
        if (p.isCleared) p,
    ];

    return ListView(
      // The add button hangs over the top edge; the total cloud keeps its
      // flat right side clear of it.
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      children: [
        _FinalePop(
          sky: sky,
          child: TotalCloud(outstandingCentavos: month.outstandingCentavos),
        ),
        const SizedBox(height: 6),
        for (final (i, p) in owed.indexed) ...[
          const SizedBox(height: 8),
          PaymentTile(
            payment: p,
            // Right first: the total cloud's puffs are on the left.
            puffsOnRight: i.isEven,
            onTap: () => _openModal(context, p),
          ),
        ],
        if (cleared.isNotEmpty) ...[
          const SizedBox(height: 20),
          ClearedGroup(payments: cleared),
        ],
      ],
    );
  }

  void _openAddBill(BuildContext context) {
    final month = controller.current;
    if (month == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => AddBillSheet(
        rule: month.rule,
        outstandingCentavos: month.outstandingCentavos,
        onSave: controller.addPayment,
      ),
    );
  }

  void _openNewMonth(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => NewMonthSheet(
        initialPeriod: controller.suggestedNewPeriod(),
        isTaken: controller.hasMonthFor,
        initialEstimateCentavos: controller.suggestedEstimateCentavos,
        onSave: (period, estimate) => controller.createMonth(
          period,
          expectedTotalCentavos: estimate,
        ),
      ),
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
    final removed = before - after;

    showModalBottomSheet<void>(
      context: context,
      // Sized to its content. The push needs room to rise, and the default
      // 9/16-of-the-screen cap would squeeze it on a short phone.
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      // Light enough that the clouds trembling above stay part of the push.
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (_) => PaymentModal(
        payment: payment,
        cloudsRemoved: removed,
        onProgress: (v) => sky.setTension(removed, v),
        onCleared: () => controller.clear(payment),
      ),
    );
  }
}

/// The one thing to tap when there is nothing yet: a big bobbing cloud with
/// what it does written underneath.
class _EmptyCloud extends StatelessWidget {
  const _EmptyCloud({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const Size _size = Size(150, 104);
  static const double _gap = 10;
  static const double _labelHeight = 20;

  /// How far the cloud's centre sits above the middle of the column, so new
  /// clouds can launch from exactly under it.
  static const double centreAboveMiddle = (_gap + _labelHeight) / 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CloudAddButton(
          size: _size,
          semanticLabel: label,
          onPressed: onPressed,
        ),
        const SizedBox(height: _gap),
        SizedBox(
          height: _labelHeight,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0C447C),
            ),
          ),
        ),
      ],
    );
  }
}

/// Springs [child] up when the last cloud clears. Only the transform listens
/// to the sky, which notifies every frame.
class _FinalePop extends StatelessWidget {
  const _FinalePop({required this.sky, required this.child});

  final SkyController sky;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sky,
      child: child,
      builder: (context, child) {
        final f = sky.finale;
        // Smaller than a chip could take: this card spans the list.
        final pop = f > 0 && f < 1
            ? math.sin(math.pi * math.min(1, f * 2.2)) * 0.05
            : 0.0;
        return Transform.scale(scale: 1 + pop, child: child);
      },
    );
  }
}
