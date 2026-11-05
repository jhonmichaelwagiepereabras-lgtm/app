import '../app_language.dart';
import 'package:flutter/material.dart';

class PrinterSettingsPage extends StatelessWidget {
  final String? receipt;
  final bool isReport;
  const PrinterSettingsPage({super.key, this.receipt, this.isReport = false});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const LText('Printer settings')),
      body: const Padding(
          padding: EdgeInsets.all(24),
          child: LText(
              'Bluetooth, USB and Wi-Fi thermal printing are available in the installed Android app. Open the app on your phone to connect a printer.')));
}
