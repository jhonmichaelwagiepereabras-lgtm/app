import '../app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'invoice_document.dart';
import '../data/pos_database.dart';
import 'printer_page_stub.dart' if (dart.library.io) 'printer_page_native.dart';

String receiptText(Map<String, dynamic> sale, String store, String address,
        String footer) =>
    invoiceText(sale, store, address, footer);

Future<String> buildReceipt(Map<String, dynamic> sale, String shop) async {
  final config = await PosDatabase.instance.readSettings();
  return receiptText(
      sale,
      config['shop'] ?? shop,
      config['receipt_address'] ?? '',
      config['receipt_footer'] ?? tr('Thank you for shopping with us!'));
}

Future<void> showReceipt(
    BuildContext context, Map<String, dynamic> sale, String shop,
    {Future<void> Function()? onViewed}) async {
  try {
    final text = await buildReceipt(sale, shop);
    if (!context.mounted) return;
    final receiptClosed = Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                  appBar: AppBar(title: const LText('Receipt')),
                  bottomNavigationBar: SafeArea(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          PrinterSettingsPage(receipt: text))),
                              icon: const Icon(Icons.print_outlined),
                              label: const LText('Print receipt')))),
                  body: ListView(padding: const EdgeInsets.all(24), children: [
                    Card(
                        color: Colors.white,
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: ReceiptPreview(text: text))),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await Printing.sharePdf(
                                bytes: await invoicePdf(text),
                                filename:
                                    'invoice-${sale['invoice_number'] ?? 'legacy'}.pdf');
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Could not export PDF: $e')));
                            }
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Save / share PDF')),
                    OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Receipt copied. Paste it into your message to the customer.')));
                          }
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy digital receipt')),
                  ]),
                )));
    await WidgetsBinding.instance.endOfFrame;
    if (onViewed != null && context.mounted) await onViewed();
    await receiptClosed;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: LText('Could not open receipt: $e')));
    }
  }
}

class ReceiptPreview extends StatelessWidget {
  final String text;
  const ReceiptPreview({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final separator = lines.indexOf('--------------------------------');
    final header = separator < 0 ? lines : lines.take(separator).toList();
    final body = separator < 0 ? <String>[] : lines.skip(separator + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.storefront_outlined, size: 28, color: Colors.black87),
        for (final (index, line) in header.indexed)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(line,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.black87,
                      fontSize: index == 0
                          ? 18
                          : line == 'SALES INVOICE'
                              ? 16
                              : 12,
                      fontWeight: index == 0 || line == 'SALES INVOICE'
                          ? FontWeight.w600
                          : FontWeight.normal))),
        const Divider(height: 24),
        for (final line in body)
          if (line == '--------------------------------')
            const Divider(height: 20)
          else if (line.contains(' | '))
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, cell) in line.split(' | ').indexed)
                        Expanded(
                            flex: index == 0 ? 3 : 2,
                            child: Text(cell.replaceAll('PHP ', '\u20b1'),
                                textAlign: index == 0
                                    ? TextAlign.left
                                    : TextAlign.right,
                                style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: line.startsWith('GRAND TOTAL')
                                        ? 16
                                        : line.split(' | ').length == 4
                                            ? 11
                                            : 13,
                                    fontWeight:
                                        line.startsWith('GRAND TOTAL') ||
                                                line.startsWith('ITEM |')
                                            ? FontWeight.bold
                                            : FontWeight.normal))),
                    ]))
          else
            SelectableText(line,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.black87, fontSize: 12, height: 1.4)),
      ],
    );
  }
}

class ReceiptInformationPage extends StatefulWidget {
  final String shop;
  const ReceiptInformationPage({super.key, required this.shop});
  @override
  State<ReceiptInformationPage> createState() => _ReceiptInformationPageState();
}

class _ReceiptInformationPageState extends State<ReceiptInformationPage> {
  final name = TextEditingController(),
      address = TextEditingController(),
      footer = TextEditingController();
  final form = GlobalKey<FormState>();
  final tin = TextEditingController(),
      cashier = TextEditingController(),
      vatRate = TextEditingController(text: '12');
  String vatStatus = 'Non-VAT';
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final config = await PosDatabase.instance.readSettings();
      name.text = config['shop'] ?? widget.shop;
      address.text = config['receipt_address'] ?? '';
      tin.text = config['receipt_tin'] ?? '';
      cashier.text = config['cashier'] ?? 'Admin';
      vatStatus = config['vat_status'] ?? 'Non-VAT';
      vatRate.text = config['vat_rate'] ?? '12';
      footer.text =
          config['receipt_footer'] ?? tr('Thank you for shopping with us!');
    } catch (e) {
      error = 'Could not load receipt information: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    footer.dispose();
    tin.dispose();
    cashier.dispose();
    vatRate.dispose();
    super.dispose();
  }

  Widget labeledField(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: LText(label,
                  style: const TextStyle(fontSize: 12, height: 1.2))),
          field,
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Receipt information')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: form,
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  if (error != null)
                    LText(error!, style: const TextStyle(color: Colors.red)),
                  labeledField(
                      'Name of store',
                      TextFormField(
                          controller: name,
                          decoration: InputDecoration(),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? tr('Enter your store name')
                              : null)),
                  const SizedBox(height: 20),
                  labeledField(
                      'Store address',
                      TextFormField(
                          controller: address,
                          minLines: 2,
                          maxLines: 3,
                          decoration: InputDecoration())),
                  const SizedBox(height: 20),
                  labeledField(
                      'Closing remarks / greetings',
                      TextFormField(
                          controller: footer,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration())),
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: tin,
                      decoration:
                          const InputDecoration(labelText: 'Business TIN')),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                      initialValue: vatStatus,
                      decoration:
                          const InputDecoration(labelText: 'VAT status'),
                      items: ['Non-VAT', 'VAT Registered']
                          .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => setState(() => vatStatus = v!)),
                  if (vatStatus == 'VAT Registered') ...[
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: vatRate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'VAT rate (%) - prices include VAT'),
                        validator: (v) {
                          final value = double.tryParse(v ?? '');
                          return value == null ||
                                  !value.isFinite ||
                                  value <= 0 ||
                                  value > 100
                              ? 'Enter a rate greater than 0 and up to 100'
                              : null;
                        }),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: cashier,
                      decoration:
                          const InputDecoration(labelText: 'Cashier name / ID'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter cashier name / ID'
                          : null),
                  const SizedBox(height: 16),
                  const Text(
                      'Invoices are illustrative and are not BIR-authorized. VAT is a simple inclusive breakdown; statutory exemptions are not automated.',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: saving || error != null
                          ? null
                          : () async {
                              if (!form.currentState!.validate()) return;
                              setState(() => saving = true);
                              try {
                                await PosDatabase.instance.updateSettings({
                                  'shop': name.text.trim(),
                                  'receipt_address': address.text.trim(),
                                  'receipt_tin': tin.text.trim(),
                                  'cashier': cashier.text.trim(),
                                  'vat_status': vatStatus,
                                  'vat_rate': vatRate.text.trim(),
                                  'receipt_footer': footer.text.trim()
                                });
                                if (context.mounted) {
                                  Navigator.pop(context, name.text.trim());
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    saving = false;
                                    error =
                                        'Could not save receipt information: $e';
                                  });
                                }
                              }
                            },
                      child: LText(
                          saving ? 'Saving...' : 'Save receipt information')),
                ])),
      );
}
