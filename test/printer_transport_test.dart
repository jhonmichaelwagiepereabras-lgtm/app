import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/receipts/printer_transport.dart';
import 'package:coral_pos/receipts/receipt_printing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final connection in [
    'Bluetooth Classic',
    'Bluetooth BLE',
    'USB',
    'Wi-Fi'
  ]) {
    for (final wide in [false, true]) {
      test(
          'SIMULATED $connection connection sends ${wide ? 80 : 58} mm receipt then disconnects',
          () async {
        final calls = <String>[];
        List<int>? received;
        final bytes = await receiptPrintBytes(
            samplePrinterReceipt('MPOS Simulator', DateTime(2026, 11, 3),
                connection, wide ? '80 mm' : '58 mm'),
            wide: wide);
        await transmitReceipt(
          bytes: bytes,
          connect: () async {
            calls.add('connect');
            return true;
          },
          write: (data) async {
            calls.add('write');
            received = List.of(data);
          },
          disconnect: () async {
            calls.add('disconnect');
          },
        );
        expect(calls, ['connect', 'write', 'disconnect']);
        expect(received, orderedEquals(bytes));
      });
    }
  }
  test('SIMULATED offline printer does not receive bytes or a false success',
      () async {
    bool sent = false;
    await expectLater(
        transmitReceipt(
            bytes: [27, 64],
            connect: () async => false,
            write: (_) async {
              sent = true;
            },
            disconnect: () async {}),
        throwsStateError);
    expect(sent, isFalse);
  });
  test('SIMULATED Bluetooth permission failure prevents sending', () async {
    bool sent = false;
    await expectLater(
        transmitReceipt(
            bytes: [27, 64],
            connect: () async =>
                throw StateError('Bluetooth permission denied'),
            write: (_) async {
              sent = true;
            },
            disconnect: () async {}),
        throwsStateError);
    expect(sent, isFalse);
  });
  test('SIMULATED dropped connection disconnects and reports write failure',
      () async {
    bool disconnected = false;
    await expectLater(
        transmitReceipt(
            bytes: [27, 64],
            connect: () async => true,
            write: (_) async =>
                throw StateError('Printer disconnected during write'),
            disconnect: () async {
              disconnected = true;
            }),
        throwsStateError);
    expect(disconnected, isTrue);
  });
}
