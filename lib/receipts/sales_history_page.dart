import 'package:flutter/material.dart';
import 'receipt.dart';

class SalesHistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> sales;
  final String shop;
  final Future<bool> Function(Map<String, dynamic>, Map<String, dynamic>)
      recordAdjustment;
  const SalesHistoryPage(
      {super.key,
      required this.sales,
      required this.shop,
      required this.recordAdjustment});
  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  String query = '';
  bool saving = false;
  Future<void> record(Map<String, dynamic> sale) async {
    final reason = TextEditingController();
    String type = 'Refund';
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (_, update) => AlertDialog(
                  title: const Text('Record refund / void'),
                  content: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Record a full transaction reversal after completing it with the customer. This audit record does not move money, restock products or change sales reports.'),
                        DropdownButtonFormField<String>(
                            initialValue: type,
                            items: ['Refund', 'Void']
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => update(() => type = v!)),
                        TextFormField(
                            controller: reason,
                            decoration: const InputDecoration(
                                labelText: 'Reason / external reference'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter a reason'
                                : null),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(dialog, true);
                          }
                        },
                        child: const Text('Save audit record'))
                  ],
                )));
    final reasonText = reason.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    reason.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => saving = true);
    final saved = await widget.recordAdjustment(sale, {
      'type': type,
      'reason': reasonText,
      'date': DateTime.now().toIso8601String(),
      'amount': sale['total'],
    });
    if (mounted) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              saved ? 'Audit record saved' : 'Could not save audit record')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sales history')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                  decoration: const InputDecoration(
                      labelText: 'Search invoice, date or customer',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => query = v.toLowerCase()))),
          Expanded(
              child: ListView(children: [
            for (final sale in widget.sales)
              if ('${sale['invoice_number']?.toString().padLeft(6, '0') ?? 'Legacy'} ${sale['date']} ${sale['customer_name'] ?? ''} ${sale['transaction_reference'] ?? ''}'
                  .toLowerCase()
                  .contains(query))
                Card(
                    child: ExpansionTile(
                        title: Text(
                            'Invoice ${sale['invoice_number']?.toString().padLeft(6, '0') ?? 'Legacy'} - PHP ${(sale['total'] as num).toStringAsFixed(2)}'),
                        subtitle: Text('${sale['date']}'),
                        children: [
                      TextButton.icon(
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('View / reprint / share'),
                          onPressed: () =>
                              showReceipt(context, sale, widget.shop)),
                      for (final entry in (sale['adjustments'] as List? ?? []))
                        ListTile(
                            title: Text(
                                '${entry['type']} - PHP ${(entry['amount'] as num).toStringAsFixed(2)}'),
                            subtitle:
                                Text('${entry['date']}\n${entry['reason']}')),
                      TextButton(
                          onPressed: saving ||
                                  (sale['adjustments'] as List? ?? [])
                                      .isNotEmpty
                              ? null
                              : () => record(sale),
                          child:
                              const Text('Record refund / void (audit only)')),
                    ])),
          ])),
        ]),
      );
}
