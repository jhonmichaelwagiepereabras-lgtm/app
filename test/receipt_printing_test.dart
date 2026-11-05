import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/receipts/receipt_printing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final wide in [false, true]) {
    test(
        'ESC/POS test receipt generates correct totals for ${wide ? 80 : 58} mm',
        () async {
      final sample = samplePrinterReceipt('MPOS Test Store',
          DateTime(2026, 11, 3, 12), 'Bluetooth', wide ? '80 mm' : '58 mm');
      final bytes = await receiptPrintBytes(sample, wide: wide);
      expect(bytes.take(2), [27, 64]);
      final data = latin1.decode(bytes);
      expect(data, contains('TOTAL: PHP 125.50'));
      expect(data, contains('CASH TENDERED: PHP 200.00'));
      expect(data, contains('CHANGE: PHP 74.50'));
      expect(data, isNot(contains(String.fromCharCodes([29, 86]))));
      expect(bytes.every((byte) => byte >= 0 && byte <= 255), isTrue);
    });
  }
  test('Long product names and unbroken identifiers fit the selected width',
      () {
    for (final columns in [32, 48]) {
      for (final line in [
        'Very long agricultural product name with multiple words for checking paper width',
        List.filled(120, 'A').join()
      ]) {
        final wrapped = wrapPrinterLine(line, columns);
        expect(wrapped.every((part) => part.length <= columns), isTrue);
        expect(wrapped.join().replaceAll(' ', ''), line.replaceAll(' ', ''));
      }
    }
    expect(wrapPrinterLine('\u20b150.00', 32), ['PHP 50.00']);
  });
}
