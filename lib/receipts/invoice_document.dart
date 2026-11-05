import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const receiptSeparator = '--------------------------------';
const invoiceNotice =
    'Illustrative invoice only - not a BIR-authorized invoice.';

String invoiceMoney(num value) => 'PHP ${value.toStringAsFixed(2)}';

/// One representation shared by the preview, thermal output and PDF.
String invoiceText(
    Map<String, dynamic> sale, String store, String address, String footer) {
  final date = DateTime.parse(sale['date'] as String).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final total = sale['total'] as num;
  final discount = sale['discount'] as num? ?? 0;
  final vat = sale['vat_status'] == 'VAT Registered';
  final rate = sale['vat_rate'] as num? ?? 12;
  final tax = vat ? (total - total / (1 + rate / 100)) : 0;
  final number = sale['invoice_number'];
  final rows = <String>[
    sale['receipt_store'] as String? ?? store,
    if ((sale['receipt_address'] ?? address).toString().isNotEmpty)
      (sale['receipt_address'] ?? address).toString(),
    'TIN: ${(sale['receipt_tin'] as String?)?.isNotEmpty == true ? sale['receipt_tin'] : 'Not configured'}',
    vat
        ? 'VAT REGISTERED'
        : sale['vat_status'] == 'Non-VAT'
            ? 'NON-VAT REGISTERED'
            : 'TAX STATUS NOT RECORDED',
    'SALES INVOICE',
    receiptSeparator,
    'Invoice No. | ${number == null ? 'Legacy / unnumbered' : number.toString().padLeft(6, '0')}',
    'Date | ${date.year}-${two(date.month)}-${two(date.day)}',
    'Time | ${two(date.hour)}:${two(date.minute)}:${two(date.second)}',
    'Cashier | ${sale['cashier'] ?? 'Not recorded'}',
    receiptSeparator,
    'ITEM | QTY | PRICE | TOTAL',
    for (final item in sale['items'])
      '${item['name']} | ${item['quantity']} | ${(item['price'] as num).toStringAsFixed(2)} | ${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(2)}',
    receiptSeparator,
    'Subtotal | ${invoiceMoney(sale['subtotal'] as num? ?? total + discount)}',
    'Discount${discount > 0 ? ' (${sale['discount_type'] ?? 'Other'})' : ''} | ${invoiceMoney(discount)}',
    if (vat) ...[
      'VATable sales | ${invoiceMoney(total - tax)}',
      'VAT (${rate.toStringAsFixed(0)}%, inclusive) | ${invoiceMoney(tax)}',
    ] else
      sale['vat_status'] == 'Non-VAT'
          ? 'Tax | Non-VAT (no VAT charged)'
          : 'Tax | Not recorded',
    receiptSeparator,
    'GRAND TOTAL | ${invoiceMoney(total)}',
    receiptSeparator,
    'Payment Method | ${sale['payment_method'] ?? 'Cash'}',
    if (sale['cash_tendered'] != null)
      'Amount Received | ${invoiceMoney(sale['cash_tendered'] as num)}',
    if (sale['change_due'] != null)
      'Change | ${invoiceMoney(sale['change_due'] as num)}',
    if ((sale['payment_reference'] ?? '').toString().isNotEmpty)
      'Payment Ref. | ${sale['payment_reference']}',
    for (final entry in {
      'Customer': 'customer_name',
      'Customer TIN': 'customer_tin',
      'Customer Address': 'customer_address'
    }.entries)
      if ((sale[entry.value] ?? '').toString().isNotEmpty)
        '${entry.key} | ${sale[entry.value]}',
    'Transaction Ref. | ${sale['transaction_reference'] ?? 'Legacy ${sale['date']}'}',
    for (final entry in (sale['adjustments'] as List? ?? [])) ...[
      '${entry['type']} audit | ${invoiceMoney(entry['amount'] as num)}',
      'Recorded | ${entry['date']}',
      'Reason | ${entry['reason']}',
      'Audit only - original sale totals retained.',
    ],
    receiptSeparator,
    sale['receipt_footer'] as String? ?? footer,
    'Powered by MPOS',
    invoiceNotice,
  ];
  return rows.join('\n');
}

Future<Uint8List> invoicePdf(String text) async {
  final doc = pw.Document();
  var header = true;
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(24),
    build: (_) => [
      for (final line in text.split('\n'))
        if (line == receiptSeparator) ...[
          pw.Divider(color: PdfColors.grey400),
          ...(() {
            header = false;
            return <pw.Widget>[];
          })(),
        ] else if (line.contains(' | '))
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final (index, cell) in line.split(' | ').indexed)
                    pw.Expanded(
                        flex: index == 0 ? 3 : 2,
                        child: pw.Text(cell,
                            textAlign: index == 0
                                ? pw.TextAlign.left
                                : pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: line.startsWith('GRAND TOTAL')
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal)))
                ],
              ))
        else
          pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(line,
                  textAlign: header ? pw.TextAlign.center : pw.TextAlign.left,
                  style:
                      pw.TextStyle(fontSize: line == invoiceNotice ? 8 : 10))),
    ],
  ));
  return doc.save();
}
