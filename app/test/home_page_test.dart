import 'package:cloud_payments/features/payments/domain/entities/month.dart';
import 'package:cloud_payments/features/payments/presentation/controllers/month_controller.dart';
import 'package:cloud_payments/features/payments/presentation/pages/home_page.dart';
import 'package:cloud_payments/features/payments/presentation/widgets/add_bill_sheet.dart';
import 'package:cloud_payments/features/payments/presentation/widgets/cloud_add_button.dart';
import 'package:cloud_payments/features/payments/presentation/widgets/new_month_sheet.dart';
import 'package:cloud_payments/features/sky/domain/entities/cloud_rule.dart';
import 'package:cloud_payments/features/sky/presentation/controllers/sky_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<void> pumpHome(WidgetTester tester, List<Month> months) async {
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
}
