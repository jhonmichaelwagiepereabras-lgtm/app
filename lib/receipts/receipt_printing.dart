import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// Basic ESC/POS receipt output, for continuous-roll receipt printers.
/// This is not a driver for TSPL/ZPL label or proprietary pocket printers.
Future<List<int>> receiptPrintBytes(String text, {bool wide = false}) async {
  final generator = Generator(
      wide ? PaperSize.mm80 : PaperSize.mm58, await CapabilityProfile.load());
  final bytes = <int>[...generator.reset()];
  bool header = true;
  for (final line in text.split('\n')) {
    if (line == '--------------------------------') {
      header = false;
      bytes.addAll(generator.hr());
      continue;
    }
    if (line.contains(' | ')) {
      final cells = line.split(' | ');
      if (cells.length == 4) {
        for (final wrapped in wrapPrinterLine(cells.first, wide ? 48 : 32)) {
          bytes.addAll(generator.text(wrapped));
        }
        bytes.addAll(generator.row([
          PosColumn(text: cells[1], width: 2),
          PosColumn(
              text: cells[2],
              width: 5,
              styles: const PosStyles(align: PosAlign.right)),
          PosColumn(
              text: cells[3],
              width: 5,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      } else {
        final label = cells.first;
        for (final wrapped in wrapPrinterLine(
            '$label: ${cells.skip(1).join(' ')}', wide ? 48 : 32)) {
          bytes.addAll(generator.text(wrapped,
              styles: PosStyles(bold: label == 'GRAND TOTAL')));
        }
      }
      continue;
    }
    for (final wrapped in wrapPrinterLine(line, wide ? 48 : 32)) {
      bytes.addAll(generator.text(wrapped,
          styles: PosStyles(align: header ? PosAlign.center : PosAlign.left)));
    }
  }
  // Mobile printers often have a tear bar rather than an automatic cutter.
  bytes.addAll(generator.feed(3));
  return bytes;
}

List<String> wrapPrinterLine(String text, int columns) {
  if (columns < 1) throw ArgumentError.value(columns, 'columns');
  var remaining = text
      .replaceAll('\u20b1', 'PHP ')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
  final lines = <String>[];
  while (remaining.length > columns) {
    var cut = remaining.lastIndexOf(' ', columns);
    if (cut < columns ~/ 2) cut = columns;
    lines.add(remaining.substring(0, cut));
    remaining = remaining.substring(cut).trimLeft();
  }
  lines.add(remaining);
  return lines;
}

String samplePrinterReceipt(
        String shop, DateTime date, String mode, String paper) =>
    [
      shop,
      'MPOS RECEIPT TEST',
      date.toLocal().toString().substring(0, 19),
      '$mode / $paper / ESC-POS',
      '--------------------------------',
      'Item A x2     PHP 100.00',
      'Item B x1     PHP 25.50',
      'Long product name wrapping alignment check',
      '--------------------------------',
      'TOTAL: PHP 125.50',
      'CASH TENDERED: PHP 200.00',
      'CHANGE: PHP 74.50',
      '',
      'Thank you! Check text, totals,',
      'line breaks and paper feed.',
    ].join('\n');
