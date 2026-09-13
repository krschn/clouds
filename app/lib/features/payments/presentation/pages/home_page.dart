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
import '../widgets/cloud_add_button.dart';
import '../widgets/month_drawer.dart';
import '../widgets/new_month_sheet.dart';
import '../widgets/payment_modal.dart';
import '../widgets/payment_tile.dart';
import '../widgets/peso.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.controller, required this.sky, super.key});

  final MonthController controller;
  final SkyController sky;

  static const int _skyFlex = 51;
  static const int _listFlex = 49;
  static const Size _addButtonSize = Size(84, 58);
  static const double _addButtonInset = 16;

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
                  "Couldn't reach the server.",
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
        sky.launchFrom = empty
            ? Offset(
                0.5,
                (skyHeight + listHeight / 2 - _EmptyCloud.centreAboveMiddle) /
                    skyHeight,
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
                      SafeArea(
                        child: Builder(
                          builder: (context) => AnimatedBuilder(
                            animation: sky,
                            builder: (_, __) => IconButton(
                              icon: const Icon(Icons.menu),
                              color: paletteFor(sky.gloom).ink,
                              onPressed: Scaffold.of(context).openDrawer,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(
                          child: _Caption(
                            sky: sky,
                            text: month.cloudCount == 0
                                ? 'Cleared'
                                : '${month.cloudCount} clouds  ·  '
                                    '${formatPeso(month.outstandingCentavos)}',
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
                      : ListView.separated(
                          // Extra top padding keeps the first bill's amount
                          // out from under the add button.
                          padding: const EdgeInsets.fromLTRB(14, 38, 14, 14),
                          itemCount: month.payments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 7),
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
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => PaymentModal(
        payment: payment,
        cloudsRemoved: removed,
        onHoldProgress: (v) => sky.setTension(removed, v),
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

/// The count under the sky, on a chip that flips light or dark with the sky
/// so it stays readable at any gloom. Springs up when the finale plays.
class _Caption extends StatelessWidget {
  const _Caption({required this.sky, required this.text});

  final SkyController sky;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sky,
      builder: (context, _) {
        final palette = paletteFor(sky.gloom);
        final f = sky.finale;
        final pop = f > 0 && f < 1
            ? math.sin(math.pi * math.min(1, f * 2.2)) * 0.22
            : 0.0;
        return Transform.scale(
          scale: 1 + pop,
          child: AnimatedContainer(
            // The chip swaps colour at one gloom threshold; a short fade
            // keeps that from reading as a flicker.
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: palette.chip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.ink,
              ),
            ),
          ),
        );
      },
    );
  }
}
