import 'printer_transport.dart';
import 'receipt_printing.dart';
import '../app_language.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:flutter_thermal_printer/network/network_print_result.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/pos_database.dart';

class PrinterSettingsPage extends StatefulWidget {
  final String? receipt;
  final bool isReport;
  const PrinterSettingsPage({super.key, this.receipt, this.isReport = false});
  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final plugin = FlutterThermalPrinter.instance;
  final host = TextEditingController(),
      port = TextEditingController(text: '9100');
  StreamSubscription<List<Printer>>? subscription;
  Timer? scanTimer;
  List<Printer> devices = [];
  Printer? selected;
  String mode = 'Bluetooth', paper = '58 mm', status = '';
  bool busy = false, scanning = false, loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final config = await PosDatabase.instance.readSettings();
      final saved =
          jsonDecode(config['printer'] ?? '{}') as Map<String, dynamic>;
      mode = saved['mode'] ?? mode;
      paper = saved['paper'] ?? paper;
      host.text = saved['host'] ?? '';
      port.text = saved['port'] ?? '9100';
      if (saved['device'] != null) {
        selected = Printer.fromJson(Map<String, dynamic>.from(saved['device']));
      }
    } catch (e) {
      status = 'Could not load printer settings: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> persist() => PosDatabase.instance.updateSettings({
        'printer': jsonEncode({
          'mode': mode,
          'paper': paper,
          'host': host.text.trim(),
          'port': port.text.trim(),
          'device': selected?.toJson()
        })
      });
  Future<void> action(Future<void> Function() work) async {
    setState(() {
      busy = true;
      status = '';
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => status = 'Printer error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() async {
    if (Platform.isAndroid && mode.startsWith('Bluetooth')) {
      final scanPermission = await Permission.bluetoothScan.request();
      final connectPermission = await Permission.bluetoothConnect.request();
      if (!scanPermission.isGranted || !connectPermission.isGranted) {
        // Older Android versions require location access instead.
        final location = await Permission.locationWhenInUse.request();
        if (!location.isGranted) {
          throw StateError(
              'Allow Nearby devices / Bluetooth permissions in phone settings.');
        }
      }
    }
    if (mode == 'Bluetooth') {
      if (!await PrintBluetoothThermal.bluetoothEnabled) {
        throw StateError('Turn on Bluetooth in phone settings.');
      }
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      if (mounted) {
        setState(() {
          devices = paired
              .map((p) => Printer(
                  name: p.name,
                  address: p.macAdress,
                  connectionType: ConnectionType.BLE))
              .toList();
          status = devices.isEmpty
              ? 'Pair your printer in phone Bluetooth settings first, then search again.'
              : 'Choose a paired printer below.';
        });
      }
      return;
    }
    await subscription?.cancel();
    subscription = plugin.devicesStream.listen((list) {
      if (mounted) {
        setState(() => devices = list
            .where((p) =>
                p.connectionType ==
                (mode == 'USB' ? ConnectionType.USB : ConnectionType.BLE))
            .toList());
      }
    }, onError: (Object e) {
      if (mounted) setState(() => status = 'Discovery failed: $e');
    });
    setState(() {
      scanning = true;
      devices = [];
      status = 'Searching for printers...';
    });
    await plugin.getPrinters(connectionTypes: [
      mode == 'USB' ? ConnectionType.USB : ConnectionType.BLE
    ]);
    scanTimer?.cancel();
    scanTimer = Timer(const Duration(seconds: 12), () async {
      await plugin.stopScan();
      if (mounted) {
        setState(() {
          scanning = false;
          status = devices.isEmpty
              ? 'No printers found. Check power, Bluetooth or USB OTG connection.'
              : 'Choose a printer below.';
        });
      }
    });
  }

  Future<void> printReceipt(bool test) async {
    if (scanning) {
      await plugin.stopScan();
      scanTimer?.cancel();
      if (mounted) setState(() => scanning = false);
    }
    final settings = await PosDatabase.instance.readSettings();
    final text = test
        ? samplePrinterReceipt(
            settings['shop'] ?? 'MPOS', DateTime.now(), mode, paper)
        : widget.receipt!;
    final bytes = await receiptPrintBytes(text, wide: paper == '80 mm');
    if (mode == 'Wi-Fi') {
      final number = int.tryParse(port.text);
      if (host.text.trim().isEmpty ||
          number == null ||
          number < 1 ||
          number > 65535) {
        throw StateError('Enter a printer IP address and valid port.');
      }
      final network =
          FlutterThermalPrinterNetwork(host.text.trim(), port: number);
      await transmitReceipt(
        bytes: bytes,
        connect: () async =>
            await network.connect() == NetworkPrintResult.success,
        write: (data) async {
          if (await network.printTicket(data, isDisconnect: false) !=
              NetworkPrintResult.success) {
            throw StateError(
                'Cannot reach printer. Check the IP, port and Wi-Fi network.');
          }
        },
        disconnect: () async {
          await network.disconnect();
        },
      );
    } else {
      if (selected == null) throw StateError('Choose a printer first.');
      final target = selected!;
      if (mode == 'Bluetooth') {
        await PrintBluetoothThermal.disconnect;
        await transmitReceipt(
          bytes: bytes,
          connect: () =>
              PrintBluetoothThermal.connect(macPrinterAddress: target.address!),
          write: (data) async {
            if (!await PrintBluetoothThermal.writeBytes(data)) {
              throw StateError('Receipt could not be sent.');
            }
          },
          disconnect: () async {
            await PrintBluetoothThermal.disconnect;
          },
        );
      } else {
        await transmitReceipt(
          bytes: bytes,
          connect: () => plugin.connect(target),
          write: (data) => plugin.printData(target, data, longData: true),
          disconnect: () => plugin.disconnect(target),
        );
      }
    }
    await persist();
    if (mounted) {
      setState(() =>
          status = 'Print data sent. Check the printer for your receipt.');
    }
  }

  @override
  void dispose() {
    scanTimer?.cancel();
    subscription?.cancel();
    if (scanning) {
      plugin.stopScan();
    }
    host.dispose();
    port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Printer settings')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(24), children: [
                const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LText(
                        'Use an ESC/POS receipt printer. Label and pocket printers may need a separate driver.')),
                DropdownButtonFormField<String>(
                    initialValue: mode,
                    decoration: InputDecoration(labelText: tr('Connection')),
                    items: ['Bluetooth', 'Bluetooth BLE', 'USB', 'Wi-Fi']
                        .map((m) => DropdownMenuItem(value: m, child: LText(m)))
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) async {
                            scanTimer?.cancel();
                            await subscription?.cancel();
                            if (scanning) await plugin.stopScan();
                            if (mounted) {
                              setState(() {
                                mode = v!;
                                selected = null;
                                devices = [];
                                scanning = false;
                                status = '';
                              });
                            }
                          }),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                    initialValue: paper,
                    decoration: InputDecoration(labelText: tr('Paper width')),
                    items: ['58 mm', '80 mm']
                        .map((p) => DropdownMenuItem(value: p, child: LText(p)))
                        .toList(),
                    onChanged: busy ? null : (v) => setState(() => paper = v!)),
                const SizedBox(height: 20),
                if (mode == 'Wi-Fi') ...[
                  TextField(
                      controller: host,
                      decoration: InputDecoration(
                          labelText: tr('Printer IP address'),
                          hintText: tr('192.168.1.100'))),
                  const SizedBox(height: 20),
                  TextField(
                      controller: port,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('Port'))),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LText(
                          'Connect your phone and ESC/POS printer to the same Wi-Fi network.')),
                ] else ...[
                  LText(mode == 'Bluetooth'
                      ? 'Pair your portable printer in phone Bluetooth settings, then search.'
                      : mode == 'Bluetooth BLE'
                          ? 'Turn on a compatible Bluetooth Low Energy (BLE) ESC/POS printer, then search. Use Bluetooth mode for paired Classic printers.'
                          : 'Connect an ESC/POS USB printer using a USB OTG cable and allow USB access.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: busy || scanning ? null : () => action(scan),
                      icon: const Icon(Icons.search),
                      label:
                          LText(scanning ? 'Searching...' : 'Search printers')),
                  if (selected != null)
                    ListTile(
                        title: LText(
                            'Selected: ${selected!.name ?? selected!.address ?? 'Printer'}')),
                  for (final p in devices)
                    ListTile(
                        title: Text(p.name ?? 'Thermal printer'),
                        subtitle:
                            LText(p.address ?? '${p.vendorId}:${p.productId}'),
                        trailing: selected?.uniqueId == p.uniqueId
                            ? const Icon(Icons.check)
                            : null,
                        onTap:
                            busy ? null : () => setState(() => selected = p)),
                ],
                const SizedBox(height: 16),
                if (status.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: LText(status)),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                              await persist();
                              if (mounted) {
                                setState(
                                    () => status = 'Printer settings saved.');
                              }
                            }),
                    child: const LText('Save printer settings')),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed:
                        busy ? null : () => action(() => printReceipt(true)),
                    child: const LText('Test print')),
                if (widget.receipt != null)
                  FilledButton.icon(
                      onPressed:
                          busy ? null : () => action(() => printReceipt(false)),
                      icon: const Icon(Icons.print_outlined),
                      label: LText(
                          widget.isReport ? 'Print report' : 'Print receipt')),
                if (busy)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator())),
              ]),
      );
}
