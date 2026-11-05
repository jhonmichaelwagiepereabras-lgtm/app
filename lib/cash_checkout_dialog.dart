import 'app_language.dart';
import 'package:flutter/material.dart';

class CashCheckoutDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double total;
  final ValueChanged<Map<String, dynamic>>? onDetails;
  const CashCheckoutDialog(
      {super.key, required this.items, required this.total, this.onDetails});
  @override
  State<CashCheckoutDialog> createState() => _CashCheckoutDialogState();
}

class _CashCheckoutDialogState extends State<CashCheckoutDialog> {
  final cash = TextEditingController();
  int? get cashCents {
    final text = cash.text.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) return null;
    return (value * 100).round();
  }

  int get totalCents => (widget.total * 100).round();
  bool get valid => cashCents != null && cashCents! >= totalCents;
  @override
  void dispose() {
    cash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const LText('Review sale'),
        content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (final item in widget.items)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: LText(
                                      '${item['name']} × ${item['quantity']}',
                                      style: const TextStyle(fontSize: 13))),
                              const SizedBox(width: 12),
                              LText(
                                  '₱${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 13)),
                            ])),
                  const Divider(height: 24),
                  Row(children: [
                    const Expanded(
                        child: LText('Total',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    LText('₱${(totalCents / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold))
                  ]),
                  const SizedBox(height: 20),
                  const Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 6),
                      child: LText('Cash tendered',
                          style: TextStyle(fontSize: 12))),
                  TextField(
                      key: const ValueKey('cash-tendered'),
                      controller: cash,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          prefixText: '₱ ',
                          hintText: tr('0.00'),
                          errorText: cash.text.isEmpty || valid
                              ? null
                              : cashCents == null
                                  ? tr(
                                      'Enter a valid amount (up to 2 decimals)')
                                  : tr('Cash must cover the total'))),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Expanded(child: LText('Change')),
                    LText(
                        valid
                            ? '₱${((cashCents! - totalCents) / 100).toStringAsFixed(2)}'
                            : '—',
                        key: const ValueKey('cash-change'),
                        style: const TextStyle(fontWeight: FontWeight.bold))
                  ]),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const LText('Back')),
          FilledButton(
              onPressed: valid
                  ? () {
                      widget.onDetails?.call({
                        'subtotal': widget.total,
                        'discount': 0.0,
                        'payment_method': 'Cash',
                        'grand_total': totalCents / 100,
                      });
                      Navigator.pop(context, cashCents! / 100);
                    }
                  : null,
              child: const LText('Payment received'))
        ],
      );
}
