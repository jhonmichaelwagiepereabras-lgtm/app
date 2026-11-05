import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/receipts/invoice_document.dart';
import 'package:coral_pos/receipts/receipt.dart';

Map<String, dynamic> sampleInvoice() => {
      'date': DateTime(2026, 11, 3, 18, 16).toIso8601String(),
      'invoice_number': 1,
      'total': 205.0,
      'subtotal': 205.0,
      'discount': 0.0,
      'cash_tendered': 250.0,
      'change_due': 45.0,
      'cashier': 'Admin',
      'receipt_store': 'MPOS STORE',
      'receipt_address': '123 Sample Street, Tacloban City, Leyte',
      'receipt_tin': '000-000-000-000 (SAMPLE)',
      'vat_status': 'Non-VAT',
      'payment_method': 'Cash',
      'transaction_reference': 'MPOS-SAMPLE-001',
      'items': [
        {'name': 'Rice 1kg', 'quantity': 2, 'price': 55.0},
        {'name': 'Coffee', 'quantity': 3, 'price': 15.0},
        {'name': 'Bread', 'quantity': 2, 'price': 25.0},
      ],
    };

void main() {
  test('Sample totals, number and historical business snapshot', () {
    final text = invoiceText(
        sampleInvoice(), 'Changed store', '', 'Thank you for shopping!');
    expect(text, startsWith('MPOS STORE'));
    expect(text, contains('Invoice No. | 000001'));
    expect(text, contains('Rice 1kg | 2 | 55.00 | 110.00'));
    expect(text, contains('GRAND TOTAL | PHP 205.00'));
    expect(text, contains('Change | PHP 45.00'));
    expect(text, contains('no VAT charged'));
    expect(text, contains(invoiceNotice));
  });
  test('VAT inclusive breakdown and discount use final paid total', () {
    final sale = sampleInvoice()
      ..addAll({
        'vat_status': 'VAT Registered',
        'vat_rate': 12.0,
        'subtotal': 122.0,
        'total': 112.0,
        'discount': 10.0,
        'discount_type': 'Promotional',
        'customer_name': 'Juan',
        'payment_method': 'GCash',
        'payment_reference': 'ABC123',
      });
    final text = invoiceText(sale, '', '', 'Thanks');
    expect(text, contains('VATable sales | PHP 100.00'));
    expect(text, contains('VAT (12%, inclusive) | PHP 12.00'));
    expect(text, contains('Discount (Promotional) | PHP 10.00'));
    expect(text, contains('Customer | Juan'));
    expect(text, contains('Payment Ref. | ABC123'));
  });
  test('PDF supports long item lists across pages', () async {
    final sale = sampleInvoice();
    sale['items'] = List.generate(90,
        (i) => {'name': 'Long product name $i', 'quantity': 1, 'price': 1.0});
    final bytes = await invoicePdf(invoiceText(sale, '', '', 'Thanks'));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
  testWidgets('Invoice fits a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ReceiptPreview(
                        text: invoiceText(sampleInvoice(), '', '',
                            'Thank you for shopping!')))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Invoice No.'), findsOneWidget);
    expect(find.text('000001'), findsOneWidget);
  });
}
