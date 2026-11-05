import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/receipts/receipt.dart';

void main() {
  test(
      'Receipt includes store details, original phone time, items, total and greeting',
      () {
    final sale = <String, dynamic>{
      'date': DateTime(2026, 11, 3, 13, 55, 12).toIso8601String(),
      'total': 150.0,
      'cash_tendered': 200.0,
      'change_due': 50.0,
      'items': [
        {'name': 'Animal feed', 'quantity': 3, 'price': 50.0}
      ],
    };
    final text =
        receiptText(sale, 'My Store', '123 Main Street', 'Come again!');
    expect(text, startsWith('My Store\n123 Main Street'));
    expect(text, contains('Date | 2026-11-03'));
    expect(text, contains('Time | 13:55:12'));
    expect(text, contains('Animal feed | 3 | 50.00 | 150.00'));
    expect(text, contains('GRAND TOTAL | PHP 150.00'));
    expect(text, contains('Amount Received | PHP 200.00'));
    expect(text, contains('Change | PHP 50.00'));
    expect(text, contains('Come again!'));
    expect(text, contains('Legacy / unnumbered'));
  });
}
