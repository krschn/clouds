import 'package:clouds/features/payments/data/models/month_model.dart';
import 'package:clouds/features/payments/presentation/controllers/month_controller.dart';
import 'package:clouds/features/sky/domain/entities/cloud_rule.dart';
import 'package:clouds/features/sky/presentation/controllers/sky_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late FakePaymentsRepository repo;
  late SkyController sky;
  late MonthController controller;

  setUp(() {
    repo = FakePaymentsRepository([
      monthOf('aug', DateTime(2026, 8), [bill('rent', 200000)]),
      monthOf('oct', DateTime(2026, 10), [
        bill('rent', 150000, cleared: true),
        bill('phone', 50000),
      ]),
    ]);
    sky = SkyController(
      vsync: const TestVSync(),
      rule: const CloudRule(centavosPerCloud: 100000, maxClouds: 12),
      haptics: RecordingHaptics(),
    );
    controller = MonthController(repository: repo, sky: sky);
  });

  tearDown(() => sky.dispose());

  testWidgets('suggestions work on months the store hands back as its models',
      (tester) async {
    // The device store returns a List<MonthModel>. Kept as-is, a reduce with
    // a Month callback throws at runtime once there are two months.
    const rule = CloudRule(centavosPerCloud: 100000, maxClouds: 12);
    final stored = MonthController(
      repository: FakePaymentsRepository(<MonthModel>[
        MonthModel(
          id: 'aug',
          period: DateTime(2026, 8),
          rule: rule,
          payments: const [],
        ),
        MonthModel(
          id: 'sep',
          period: DateTime(2026, 9),
          rule: rule,
          payments: const [],
        ),
      ]),
      sky: sky,
    );
    await stored.load();

    expect(stored.suggestedNewPeriod(), DateTime(2026, 10));
    expect(stored.suggestedEstimateCentavos, 0);
  });

  group('createMonth', () {
    testWidgets('inserts the month in date order and switches to it',
        (tester) async {
      await controller.load();

      final ok = await controller.createMonth(DateTime(2026, 9));

      expect(ok, isTrue);
      expect(controller.months.map((m) => m.id), ['aug', 'new-month', 'oct']);
      expect(controller.current!.id, 'new-month');
      expect(sky.rule.centavosPerCloud, 250000);
      expect(sky.sprites, isEmpty);
    });

    testWidgets('sends the estimate so the server can size the clouds',
        (tester) async {
      await controller.load();

      await controller.createMonth(
        DateTime(2026, 11),
        expectedTotalCentavos: 1234500,
      );

      expect(repo.createMonthCalls.single.period, DateTime(2026, 11));
      expect(repo.createMonthCalls.single.expectedTotalCentavos, 1234500);
    });

    testWidgets('leaves everything alone when the server refuses',
        (tester) async {
      await controller.load();
      repo.failCreateMonth = true;

      final ok = await controller.createMonth(DateTime(2026, 9));

      expect(ok, isFalse);
      expect(controller.months.map((m) => m.id), ['aug', 'oct']);
      expect(controller.current!.id, 'aug');
      expect(controller.error, isNotNull);
    });
  });

  group('new month suggestions', () {
    testWidgets('suggests the month after the latest one', (tester) async {
      await controller.load();
      expect(
        controller.suggestedNewPeriod(now: DateTime(2026, 9, 13)),
        DateTime(2026, 11),
      );
    });

    testWidgets('rolls the suggestion over into the next year',
        (tester) async {
      repo.months = [monthOf('dec', DateTime(2026, 12), const [])];
      await controller.load();
      expect(
        controller.suggestedNewPeriod(now: DateTime(2026, 9, 13)),
        DateTime(2027),
      );
    });

    testWidgets('suggests this month when there are none', (tester) async {
      repo.months = [];
      await controller.load();
      expect(
        controller.suggestedNewPeriod(now: DateTime(2026, 9, 13, 18, 30)),
        DateTime(2026, 9),
      );
    });

    testWidgets("prefills the estimate with the latest month's full total",
        (tester) async {
      await controller.load();
      // Cleared bills still count: they were part of what that month cost.
      expect(controller.suggestedEstimateCentavos, 200000);
    });

    testWidgets('has no estimate when there are no months', (tester) async {
      repo.months = [];
      await controller.load();
      expect(controller.suggestedEstimateCentavos, isNull);
    });

    testWidgets('knows which months already exist', (tester) async {
      await controller.load();
      expect(controller.hasMonthFor(DateTime(2026, 10)), isTrue);
      expect(controller.hasMonthFor(DateTime(2026, 9)), isFalse);
      expect(controller.hasMonthFor(DateTime(2025, 10)), isFalse);
    });
  });

  group('addPayment', () {
    testWidgets('adds the bill and its clouds', (tester) async {
      await controller.load();

      final ok = await controller.addPayment('Water', 250000);
      await settle(tester);

      expect(ok, isTrue);
      expect(controller.current!.payments.last.label, 'Water');
      // Aug had 2 clouds; +2,500 at 1,000/cloud is 3 more. Five clouds
      // draw as a single big one.
      expect(controller.current!.cloudCount, 5);
      final live = sky.sprites.where((s) => !s.exiting);
      expect(live.fold<int>(0, (n, s) => n + s.units), 5);
      expect(live.single.units, 5);
    });

    testWidgets('reports failure and keeps the month unchanged',
        (tester) async {
      await controller.load();
      repo.failAddPayment = true;

      final ok = await controller.addPayment('Water', 250000);

      expect(ok, isFalse);
      expect(controller.current!.payments, hasLength(1));
      expect(controller.error, isNotNull);
    });
  });

  group('clear rollback', () {
    testWidgets('re-forms the same clouds instead of popping in new ones',
        (tester) async {
      repo.months = [
        monthOf('aug', DateTime(2026, 8), [
          bill('rent', 200000),
          bill('phone', 100000),
        ]),
      ];
      await controller.load();
      final before = {for (final s in sky.sprites) s.slot};
      repo.failClearPayment = true;

      await controller.clear(controller.current!.payments.first);
      await settle(tester);

      final live = sky.sprites.where((s) => !s.exiting).toList();
      expect(live, hasLength(3));
      expect({for (final s in live) s.slot}, before);
    });
  });
}
