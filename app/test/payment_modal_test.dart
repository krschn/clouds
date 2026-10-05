import 'package:clouds/features/payments/presentation/widgets/payment_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late int cleared;
  late List<double> progress;

  Future<void> pumpModal(WidgetTester tester) async {
    cleared = 0;
    progress = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PaymentModal(
              payment: bill('internet', 1000000),
              cloudsRemoved: 10,
              onCleared: () => cleared++,
              onProgress: progress.add,
            ),
          ),
        ),
      ),
    );
  }

  /// The idle peek repeats forever, so never pumpAndSettle.
  Future<void> frames(WidgetTester tester, [int count = 60]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final cloud = find.byKey(PaymentModal.cloudKey);

  testWidgets('says what the clear removes in big and small clouds',
      (tester) async {
    await pumpModal(tester);

    expect(find.text('Clears 2 big clouds'), findsOneWidget);
    expect(find.text('Swipe up to clear'), findsOneWidget);
  });

  testWidgets('a short push springs back without clearing', (tester) async {
    await pumpModal(tester);

    await tester.drag(cloud, const Offset(0, -70));
    await frames(tester);

    expect(cleared, 0);
    expect(progress.last, closeTo(0, 0.02));
  });

  testWidgets('past the detent it says to let go, and letting go clears',
      (tester) async {
    await pumpModal(tester);

    final finger = await tester.startGesture(tester.getCenter(cloud));
    for (var i = 0; i < 16; i++) {
      await finger.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Let go to clear'), findsOneWidget);
    expect(cleared, 0, reason: 'nothing clears while the finger is down');

    await finger.up();
    await frames(tester, 30);

    expect(cleared, 1);
  });

  testWidgets('a quick flick clears from a shorter push', (tester) async {
    await pumpModal(tester);

    await tester.fling(cloud, const Offset(0, -80), 1600);
    await frames(tester, 30);

    expect(cleared, 1);
  });

  testWidgets('dragging down does nothing', (tester) async {
    await pumpModal(tester);

    await tester.fling(cloud, const Offset(0, 200), 1600);
    await frames(tester);

    expect(cleared, 0);
  });
}
