/// Shared connection lifecycle; callbacks allow testing without printer hardware.
Future<void> transmitReceipt({
  required List<int> bytes,
  required Future<bool> Function() connect,
  required Future<void> Function(List<int>) write,
  required Future<void> Function() disconnect,
}) async {
  if (bytes.isEmpty) throw ArgumentError('Receipt data must not be empty');
  if (!await connect()) {
    throw StateError('Could not connect to the selected printer.');
  }
  try {
    await write(List<int>.unmodifiable(bytes));
  } finally {
    await disconnect();
  }
}
