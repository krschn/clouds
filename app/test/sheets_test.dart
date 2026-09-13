import 'dart:async';

import 'package:cloud_payments/features/payments/presentation/widgets/add_bill_sheet.dart';
import 'package:cloud_payments/features/payments/presentation/widgets/new_month_sheet.dart';
import 'package:cloud_payments/features/sky/domain/entities/cloud_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  group('AddBillSheet', () {
    const rule = CloudRule(centavosPerCloud: 100000, maxClouds: 12);

    Future<void> pumpSheet(
      WidgetTester tester,
      Future<bool> Function(String, int) onSave,
    ) =>
        tester.pumpWidget(
          host(
            AddBillSheet(
              rule: rule,
              // 1,500 outstanding is 2 clouds; the 2nd is only half-used.
              outstandingCentavos: 150000,
              onSave: onSave,
            ),
          ),
        );

    testWidgets('cannot save until it has a name and a valid amount',
        (tester) async {
      await pumpSheet(tester, (_, __) async => true);
      expect(saveButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(AddBillSheet.labelKey), 'Water');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(AddBillSheet.amountKey), '12.345');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(AddBillSheet.amountKey), '1,200');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('previews the clouds the bill will add', (tester) async {
      await pumpSheet(tester, (_, __) async => true);

      // 1,500 + 600 = 2,100 → 3 clouds, one more than now.
      await tester.enterText(find.byKey(AddBillSheet.amountKey), '600');
      await tester.pump();
      expect(find.text('Adds 1 small cloud'), findsOneWidget);

      // 1,500 + 2,600 = 4,100 → 5 clouds, three more.
      await tester.enterText(find.byKey(AddBillSheet.amountKey), '2600');
      await tester.pump();
      expect(find.text('Adds 3 small clouds'), findsOneWidget);

      // 1,500 + 10,000 = 11,500 → 12 clouds, ten more: two big ones.
      await tester.enterText(find.byKey(AddBillSheet.amountKey), '10000');
      await tester.pump();
      expect(find.text('Adds 2 big clouds'), findsOneWidget);
    });

    testWidgets('saves centavos and blocks a double tap while saving',
        (tester) async {
      final pending = Completer<bool>();
      final calls = <(String, int)>[];
      await pumpSheet(tester, (label, amount) {
        calls.add((label, amount));
        return pending.future;
      });

      await tester.enterText(find.byKey(AddBillSheet.labelKey), ' Water ');
      await tester.enterText(find.byKey(AddBillSheet.amountKey), '1,200.50');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(calls, [('Water', 120050)]);
      expect(saveButton(tester).onPressed, isNull);
      pending.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps what was typed and says so when saving fails',
        (tester) async {
      await pumpSheet(tester, (_, __) async => false);

      await tester.enterText(find.byKey(AddBillSheet.labelKey), 'Water');
      await tester.enterText(find.byKey(AddBillSheet.amountKey), '600');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Water'), findsOneWidget);
      expect(find.text('600'), findsOneWidget);
      expect(find.textContaining("Couldn't save"), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
    });
  });

  group('NewMonthSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required Future<bool> Function(DateTime, int?) onSave,
      int? estimate = 4500000,
    }) =>
        tester.pumpWidget(
          host(
            SingleChildScrollView(
              child: NewMonthSheet(
                initialPeriod: DateTime(2026, 11),
                isTaken: (p) => p == DateTime(2026, 10),
                initialEstimateCentavos: estimate,
                onSave: onSave,
              ),
            ),
          ),
        );

    testWidgets('starts on the suggested month with the estimate filled in',
        (tester) async {
      DateTime? saved;
      int? savedEstimate;
      await pumpSheet(
        tester,
        onSave: (p, e) async {
          saved = p;
          savedEstimate = e;
          return true;
        },
      );

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('45,000'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(saved, DateTime(2026, 11));
      expect(savedEstimate, 4500000);
    });

    testWidgets('months that already exist cannot be picked', (tester) async {
      await pumpSheet(tester, onSave: (_, __) async => true);

      await tester.tap(find.text('Oct'));
      await tester.pump();

      // Still on November.
      final nov = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Nov'),
      );
      final oct = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Oct'),
      );
      expect(nov.selected, isTrue);
      expect(oct.onSelected, isNull);
    });

    testWidgets('changing the year frees up that month', (tester) async {
      DateTime? saved;
      await pumpSheet(
        tester,
        onSave: (p, _) async {
          saved = p;
          return true;
        },
      );

      await tester.tap(find.byKey(NewMonthSheet.nextYearKey));
      await tester.pump();
      await tester.tap(find.text('Oct'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(saved, DateTime(2027, 10));
    });

    testWidgets('an empty estimate is sent as none', (tester) async {
      int? savedEstimate = -1;
      await pumpSheet(
        tester,
        estimate: null,
        onSave: (_, e) async {
          savedEstimate = e;
          return true;
        },
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(savedEstimate, isNull);
    });
  });

  group('money fields only take amounts', () {
    const rule = CloudRule(centavosPerCloud: 100000, maxClouds: 12);

    Future<void> pumpAddBill(WidgetTester tester) => tester.pumpWidget(
          host(
            AddBillSheet(
              rule: rule,
              outstandingCentavos: 0,
              onSave: (_, __) async => true,
            ),
          ),
        );

    Future<void> pumpNewMonth(WidgetTester tester) => tester.pumpWidget(
          host(
            SingleChildScrollView(
              child: NewMonthSheet(
                initialPeriod: DateTime(2026, 11),
                isTaken: (_) => false,
                initialEstimateCentavos: null,
                onSave: (_, __) async => true,
              ),
            ),
          ),
        );

    final fields = <String, (Future<void> Function(WidgetTester), Key)>{
      'bill amount': (pumpAddBill, AddBillSheet.amountKey),
      'month estimate': (pumpNewMonth, NewMonthSheet.estimateKey),
    };

    fields.forEach((name, field) {
      final (pump, key) = field;

      testWidgets('$name drops letters and symbols', (tester) async {
        await pump(tester);

        await tester.enterText(find.byKey(key), 'a1b2,5c00.5x0!');
        await tester.pump();

        expect(find.text('12,500.50'), findsOneWidget);
      });

      testWidgets('$name keeps one decimal point and two places',
          (tester) async {
        await pump(tester);

        await tester.enterText(find.byKey(key), '1.25');
        await tester.enterText(find.byKey(key), '1.256');
        await tester.pump();
        expect(find.text('1.25'), findsOneWidget);

        await tester.enterText(find.byKey(key), '1.2.5');
        await tester.pump();
        expect(find.text('1.25'), findsOneWidget);
      });
    });
  });
}
