import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'app_language.dart';
import 'business_day.dart';
import 'receipts/printer_page_stub.dart'
    if (dart.library.io) 'receipts/printer_page_native.dart';

String buildExitSummary(String shop, List<Map<String, dynamic>> sales,
    List<Map<String, dynamic>> products, DateTime now) {
  final today = transactionsForDay(sales, now);
  final revenue =
      today.fold<double>(0, (v, s) => v + (s['total'] as num).toDouble());
  final unitsSold =
      today.fold<int>(0, (v, s) => v + (s['count'] as num).toInt());
  final stock =
      products.fold<int>(0, (v, p) => v + (p['stock'] as num).toInt());
  final out = products.where((p) => (p['stock'] as num) == 0).length;
  String two(int n) => n.toString().padLeft(2, '0');
  final local = now.toLocal();
  return [
    shop,
    tr('Daily summary'),
    '${businessDayKey(local)} ${two(local.hour)}:${two(local.minute)}',
    '--------------------------------',
    '${tr('Total transactions')}: ${today.length}',
    '${tr('Units sold')}: $unitsSold',
    '${tr('Revenue')}: PHP ${revenue.toStringAsFixed(2)}',
    '--------------------------------',
    tr('Current stock'),
    '${tr('Products')}: ${products.length}',
    '${tr('Stock units')}: $stock',
    '${tr('Out of stock')}: $out',
    for (final p in products) '${p['name']}: ${p['stock']}',
  ].join('\n');
}

class ExitSummaryPage extends StatefulWidget {
  final String summary;
  final DateTime date;
  const ExitSummaryPage({super.key, required this.summary, required this.date});
  @override
  State<ExitSummaryPage> createState() => _ExitSummaryPageState();
}

class _ExitSummaryPageState extends State<ExitSummaryPage> {
  bool downloading = false;
  String? message;
  Future<void> download() async {
    setState(() {
      downloading = true;
      message = null;
    });
    try {
      final bytes = Uint8List.fromList(utf8.encode(widget.summary));
      final name = 'MPOS-summary-${businessDayKey(widget.date)}';
      final result = await FileSaver.instance.saveAs(
          name: name,
          bytes: bytes,
          fileExtension: 'txt',
          mimeType: MimeType.text);
      if (mounted) {
        setState(() => message =
            result == null ? tr('Download cancelled.') : tr('Report saved.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = tr('Could not save report. Please retry.'));
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Before you exit')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const LText('Print or download your daily summary before exiting.'),
          const SizedBox(height: 16),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(widget.summary,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.4)))),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: downloading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PrinterSettingsPage(
                                receipt: widget.summary, isReport: true))),
                icon: const Icon(Icons.print_outlined),
                label: const LText('Print report')),
            OutlinedButton.icon(
                onPressed: downloading ? null : download,
                icon: const Icon(Icons.download_outlined),
                label: LText(downloading ? 'Saving...' : 'Download report')),
          ]),
          if (message != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(message!)),
          const SizedBox(height: 20),
          const LText(
              'Completed sales and products stay saved. Unpaid cart items will be cleared. Exiting does not close the store day.'),
          const SizedBox(height: 16),
          FilledButton(
              onPressed:
                  downloading ? null : () => Navigator.pop(context, true),
              child: const LText('Exit app')),
          TextButton(
              onPressed:
                  downloading ? null : () => Navigator.pop(context, false),
              child: const LText('Cancel')),
        ]),
      );
}
