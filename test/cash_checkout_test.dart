import 'package:flutter/material.dart';
import 'package:coral_pos/app_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/cash_checkout_dialog.dart';

void main() {
  testWidgets('Insufficient cash is blocked and change is calculated in cents',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CashCheckoutDialog(total: 15.35, items: const [
      {'name': 'Feed', 'quantity': 1, 'price': 15.35}
    ])));
    final input = find.byKey(const ValueKey('cash-tendered'));
    final button = find.widgetWithText(FilledButton, 'Payment received');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(input, '10');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(input, '20');
    await tester.pump();
    expect(tester.widget<LText>(find.byKey(const ValueKey('cash-change'))).data,
        '\u20b14.65');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.enterText(input, '20.001');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });
}
