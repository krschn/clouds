import 'package:clouds/features/payments/presentation/widgets/payment_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('says what the clear removes in big and small clouds',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentModal(
            payment: bill('internet', 1000000),
            cloudsRemoved: 10,
            onCleared: () {},
          ),
        ),
      ),
    );

    expect(find.text('Clears 2 big clouds'), findsOneWidget);
  });
}
