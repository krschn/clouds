import 'package:clouds/features/payments/domain/entities/month.dart';
import 'package:clouds/features/payments/presentation/controllers/month_controller.dart';
import 'package:clouds/features/payments/presentation/pages/home_page.dart';
import 'package:clouds/features/payments/presentation/widgets/add_bill_sheet.dart';
import 'package:clouds/features/payments/presentation/widgets/cloud_add_button.dart';
import 'package:clouds/features/payments/presentation/widgets/new_month_sheet.dart';
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

    expect(find.byType(CloudAddButton), findsOneWidget);
    expect(find.text('Add your first bill'), findsOneWidget);

    await tester.tap(find.byType(CloudAddButton));
    await openSheet(tester);

    expect(find.byType(AddBillSheet), findsOneWidget);
  });

  testWidgets('once there is a bill, only the edge cloud remains',
      (tester) async {
    await pumpHome(tester, [
      monthOf('sep', DateTime(2026, 9), [bill('rent', 200000)]),
    ]);

    expect(find.byType(CloudAddButton), findsOneWidget);
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

    await tester.tap(find.byIcon(Icons.menu));
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

  group('after a hold clears a bill, no remaining cloud keeps trembling', () {
    // 0.76s lets go while the sheet is still sliding away; 1.5s holds on
    // until it has gone.
    for (final releaseAfter in [0.76, 1.5]) {
      testWidgets('letting go after ${releaseAfter}s', (tester) async {
        final sky = await pumpHome(tester, [
          monthOf('sep', DateTime(2026, 9), [
            bill('internet', 1000000),
            bill('rent', 700000),
          ]),
        ]);

        await tester.tap(find.text('internet'));
        await openSheet(tester);

        final finger = await tester.startGesture(
          tester.getCenter(find.text('Hold to clear')),
        );
        await settle(tester, seconds: releaseAfter);
        await finger.up();
        await settle(tester, seconds: 3);

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
