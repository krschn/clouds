import 'package:clouds/features/payments/domain/entities/month.dart';
import 'package:clouds/features/payments/presentation/controllers/month_controller.dart';
import 'package:clouds/features/payments/presentation/pages/home_page.dart';
import 'package:clouds/features/payments/presentation/widgets/add_bill_sheet.dart';
import 'package:clouds/features/payments/presentation/widgets/cloud_add_button.dart';
import 'package:clouds/features/payments/presentation/widgets/new_month_sheet.dart';
import 'package:clouds/features/payments/presentation/widgets/payment_modal.dart';
import 'package:clouds/features/payments/presentation/widgets/total_cloud.dart';
import 'package:clouds/features/sky/domain/entities/cloud_rule.dart';
import 'package:clouds/features/sky/presentation/controllers/sky_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<SkyController> pumpHome(WidgetTester tester, List<Month> months) async {
  final sky = SkyController(
    vsync: const TestVSync(),
    rule: const CloudRule(centavosPerCloud: 100000, maxClouds: 12),
    haptics: RecordingHaptics(),
  );
  final controller = MonthController(
    repository: FakePaymentsRepository(months),
    sky: sky,
  );
  addTearDown(() {
    controller.dispose();
    sky.dispose();
  });

  await controller.load();
  await tester.pumpWidget(
    MaterialApp(home: HomePage(controller: controller, sky: sky)),
  );
  await tester.pump();
  return sky;
}

/// The "+" clouds that add a month or a bill.
final addClouds = find.byWidgetPredicate(
  (w) => w is CloudAddButton && w.label == null,
);

/// The cloud at the top that names the month and opens the drawer.
final monthCloud = find.byWidgetPredicate(
  (w) => w is CloudAddButton && w.label != null,
);

/// The sheets slide up; the add button bobs forever, so never pumpAndSettle.
Future<void> openSheet(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('with no months, the way in is a cloud rather than a button',
      (tester) async {
    await pumpHome(tester, []);

    expect(find.byType(CloudAddButton), findsOneWidget);
    expect(find.text('Create your first month'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.byType(CloudAddButton));
    await openSheet(tester);

    expect(find.byType(NewMonthSheet), findsOneWidget);
  });

  testWidgets('a month with no bills shows one big cloud to add the first',
      (tester) async {
    await pumpHome(tester, [monthOf('sep', DateTime(2026, 9), const [])]);

    expect(addClouds, findsOneWidget);
    expect(find.text('Add your first bill'), findsOneWidget);

    await tester.tap(addClouds);
    await openSheet(tester);

    expect(find.byType(AddBillSheet), findsOneWidget);
  });

  testWidgets('once there is a bill, only the edge cloud remains',
      (tester) async {
    await pumpHome(tester, [
      monthOf('sep', DateTime(2026, 9), [bill('rent', 200000)]),
    ]);

    expect(addClouds, findsOneWidget);
    expect(find.text('Add your first bill'), findsNothing);
  });

  testWidgets('the total cloud shows what is left, without a cloud count',
      (tester) async {
    await pumpHome(tester, [
      monthOf('sep', DateTime(2026, 9), [
        bill('internet', 1000000),
        bill('water', 300000),
        bill('rent', 500000, cleared: true),
      ]),
    ]);

    expect(find.byType(TotalCloud), findsOneWidget);
    expect(find.text('Left to pay'), findsOneWidget);
    expect(find.text('₱13,000'), findsOneWidget);
    expect(find.textContaining('big'), findsNothing);
  });

  testWidgets('cleared bills fold into their own group', (tester) async {
    await pumpHome(tester, [
      monthOf('sep', DateTime(2026, 9), [
        bill('gcash', 200000, cleared: true),
        bill('spay', 1000000),
        bill('water', 300000, cleared: true),
      ]),
    ]);

    expect(find.text('spay'), findsOneWidget);
    expect(find.text('gcash'), findsNothing);
    expect(find.text('water'), findsNothing);
    expect(find.text('Cleared  ·  2'), findsOneWidget);
    expect(find.text('₱5,000'), findsOneWidget);

    await tester.tap(find.text('Cleared  ·  2'));
    await openSheet(tester);

    expect(find.text('gcash'), findsOneWidget);
    expect(find.text('water'), findsOneWidget);
  });

  testWidgets('with every bill paid, the total cloud reads all clear',
      (tester) async {
    await pumpHome(tester, [
      monthOf('sep', DateTime(2026, 9), [bill('gcash', 200000, cleared: true)]),
    ]);

    expect(find.text('All clear'), findsOneWidget);
    expect(find.text('₱0'), findsOneWidget);
    expect(find.text('gcash'), findsNothing);
  });

  testWidgets('the drawer lists months newest first, with what each has left',
      (tester) async {
    await pumpHome(tester, [
      monthOf('aug', DateTime(2026, 8), [bill('rent', 500000, cleared: true)]),
      monthOf('sep', DateTime(2026, 9), [
        bill('internet', 1000000),
        bill('water', 300000),
      ]),
    ]);

    // The drawer opens from the cloud naming the month on screen.
    await tester.tap(monthCloud);
    await openSheet(tester);

    final drawer = find.byType(Drawer);
    expect(find.text('₱13,000 left'), findsOneWidget);
    expect(
      find.descendant(of: drawer, matching: find.text('All clear')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('September 2026')).dy,
      lessThan(tester.getTopLeft(find.text('August 2026')).dy),
    );

    await tester.tap(find.text('August 2026'));
    await settle(tester);

    expect(drawer, findsNothing);
    expect(
      find.descendant(
        of: find.byType(TotalCloud),
        matching: find.text('All clear'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the drawer adds a month from one cloud that says so',
      (tester) async {
    await pumpHome(tester, [monthOf('sep', DateTime(2026, 9), const [])]);

    await tester.tap(monthCloud);
    await openSheet(tester);

    // Not the home screen's "+" cloud: that one adds bills.
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(CloudAddButton),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Add month'));
    await openSheet(tester);
    await openSheet(tester);

    expect(find.byType(NewMonthSheet), findsOneWidget);
  });

  testWidgets('closing the sheet without clearing calms the clouds quietly',
      (tester) async {
    final sky = await pumpHome(tester, [
      monthOf('sep', DateTime(2026, 9), [
        bill('internet', 1000000),
        bill('rent', 700000),
      ]),
    ]);

    await tester.tap(find.text('internet'));
    await openSheet(tester);

    // Hold a short push, so the clouds are trembling when the sheet goes.
    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(PaymentModal.cloudKey)),
    );
    for (var i = 0; i < 5; i++) {
      await finger.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.cancel();
    await tester.pump(const Duration(milliseconds: 16));

    // Tap the barrier above the sheet.
    await tester.tapAt(const Offset(400, 60));
    await settle(tester, seconds: 2);

    expect(find.byType(PaymentModal), findsNothing);
    expect(sky.sprites.where((s) => s.tension > 0), isEmpty);
  });

  group('after a swipe clears a bill, no remaining cloud keeps trembling', () {
    for (final flick in [false, true]) {
      testWidgets(flick ? 'a quick flick' : 'a slow push held past the detent',
          (tester) async {
        final sky = await pumpHome(tester, [
          monthOf('sep', DateTime(2026, 9), [
            bill('internet', 1000000),
            bill('rent', 700000),
          ]),
        ]);

        await tester.tap(find.text('internet'));
        await openSheet(tester);

        final cloud = find.byKey(PaymentModal.cloudKey);
        if (flick) {
          await tester.fling(cloud, const Offset(0, -90), 1600);
        } else {
          final finger = await tester.startGesture(tester.getCenter(cloud));
          for (var i = 0; i < 16; i++) {
            await finger.moveBy(const Offset(0, -12));
            await tester.pump(const Duration(milliseconds: 16));
          }
          // Held at the top with the clouds trembling, then let go.
          await settle(tester, seconds: 0.6);
          await finger.up();
        }
        // The clear lands only after the cloud has flown off, so give the
        // bursts and the sun's pulse time to die down.
        await settle(tester, seconds: 5);

        expect(find.byType(PaymentModal), findsNothing);

        final remaining = sky.sprites.where((s) => !s.exiting).toList();
        expect(remaining, isNotEmpty);
        expect(
          remaining.where((s) => s.tension > 0).map((s) => s.tension),
          isEmpty,
        );
      });
    }
  });
}
