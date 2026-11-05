import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/data/database_connection.dart';
import 'package:coral_pos/data/pos_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Migrates once, persists across reopening, and rolls back invalid writes',
      () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('coral_pos_test_');
    final path = '${directory.path}/pos.db';
    PosDatabase createStore() => PosDatabase(
        open: () => databaseFactoryFfiNoIsolate.openDatabase(path,
            options: posDatabaseOptions()));
    var store = createStore();
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });
    final product = <String, dynamic>{
      'id': 'p1',
      'name': 'Animal feed',
      'price': 50.0,
      'stock': 12,
      'category': 'Agrivet',
      'emoji': '',
      'photo': base64Encode([1, 2, 3])
    };
    final sale = <String, dynamic>{
      'invoice_number': 1,
      'receipt_store': 'Original store',
      'customer_name': 'Juan',
      'adjustments': [
        {'type': 'Refund', 'amount': 50.0, 'reason': 'Returned'}
      ],
      'date': DateTime.now().toIso8601String(),
      'total': 50.0,
      'cash_tendered': 100.0,
      'change_due': 50.0,
      'count': 1,
      'items': [
        {'name': 'Animal feed', 'price': 50.0, 'quantity': 1}
      ]
    };
    SharedPreferences.setMockInitialValues({
      'products': jsonEncode([product]),
      'sales': jsonEncode([sale]),
      'shop': 'My shop'
    });
    final migrated = await store.load([], 'Default');
    expect((migrated['products'] as List).single['photo'], product['photo']);
    expect((migrated['sales'] as List).single['items'].single['name'],
        'Animal feed');
    await store.updateSettings({
      'receipt_address': '123 Main Street',
      'receipt_footer': 'Thank you!',
      'printer': '{"mode":"USB"}',
    });
    await store.write([
      {...product, 'stock': 11}
    ], [
      sale
    ], 'Updated shop');
    await expectLater(
        store.write([
          {...product, 'stock': -1}
        ], [], 'Invalid shop'),
        throwsA(isA<DatabaseException>()));
    await store.close();
    store = createStore();
    final restored = await store.load([], 'Default');
    final restoredSale = (restored['sales'] as List).single;
    expect(restoredSale['invoice_number'], 1);
    expect(restoredSale['receipt_store'], 'Original store');
    expect(restoredSale['customer_name'], 'Juan');
    expect(restoredSale['adjustments'].single['reason'], 'Returned');
    expect(restored['shop'], 'Updated shop');
    expect((await store.readSettings())['receipt_footer'], 'Thank you!');
    expect((await store.readSettings())['printer'], contains('USB'));
    expect((restored['products'] as List).single['stock'], 11);
    expect((restored['sales'] as List).length, 1);
    expect((restored['sales'] as List).single['cash_tendered'], 100.0);
    expect((restored['sales'] as List).single['change_due'], 50.0);
    // An empty database snapshot stays empty instead of importing old data again.
    await store.write([], [], 'Empty shop');
    await store.close();
    store = createStore();
    expect((await store.load([product], 'Default'))['products'], isEmpty);
  });
  test('A failed open is retried with a fresh connection', () async {
    sqfliteFfiInit();
    var attempts = 0;
    final store = PosDatabase(open: () async {
      attempts++;
      if (attempts == 1) throw StateError('Temporary open failure');
      return databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath,
          options: posDatabaseOptions());
    });
    addTearDown(store.close);
    await expectLater(store.database, throwsStateError);
    final db = await store.database;
    expect(attempts, 2);
    expect(await db.query('products'), isEmpty);
  });
  test('Version 1 sales upgrade preserves existing transactions', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('coral_upgrade_');
    final path = '${directory.path}/pos.db';
    final old = await databaseFactoryFfiNoIsolate.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE sales (id INTEGER PRIMARY KEY, date TEXT NOT NULL, total REAL NOT NULL, count INTEGER NOT NULL)');
              await db.insert('sales',
                  {'date': '2026-11-03T12:00:00', 'total': 50.0, 'count': 1});
            }));
    await old.close();
    final upgraded = await databaseFactoryFfiNoIsolate.openDatabase(path,
        options: posDatabaseOptions());
    try {
      final row = (await upgraded.query('sales')).single;
      expect(row['total'], 50.0);
      expect(row['cash_tendered'], isNull);
      expect(row['change_due'], isNull);
    } finally {
      await upgraded.close();
      await directory.delete(recursive: true);
    }
  });
  for (final existing in [
    ['cash_tendered'],
    ['cash_tendered', 'change_due']
  ]) {
    test('Upgrade tolerates existing payment columns: ${existing.join(', ')}',
        () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('mpos_upgrade_');
      final path = '${directory.path}/pos.db';
      final old = await databaseFactoryFfiNoIsolate.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) async {
                final extra = existing.map((name) => ', $name REAL').join();
                await db.execute(
                    'CREATE TABLE sales (id INTEGER PRIMARY KEY, date TEXT NOT NULL, total REAL NOT NULL, count INTEGER NOT NULL$extra)');
                await db.insert('sales', {
                  'date': '2026-11-03T12:00:00',
                  'total': 50.0,
                  'count': 1,
                  'cash_tendered': 100.0,
                  if (existing.contains('change_due')) 'change_due': 50.0
                });
              }));
      await old.close();
      final upgraded = await databaseFactoryFfiNoIsolate.openDatabase(path,
          options: posDatabaseOptions());
      try {
        final row = (await upgraded.query('sales')).single;
        expect(row['total'], 50.0);
        expect(row['cash_tendered'], 100.0);
        expect(
            row['change_due'], existing.contains('change_due') ? 50.0 : null);
        expect(await upgraded.getVersion(), 5);
      } finally {
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    });
  }
  test('Version 2 upgrade preserves sale items and adds product identity',
      () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('mpos_trends_');
    final path = '${directory.path}/pos.db';
    final old = await databaseFactoryFfiNoIsolate.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE sale_items (id INTEGER PRIMARY KEY, sale_id INTEGER, name TEXT, quantity INTEGER, price REAL)');
              await db.insert('sale_items',
                  {'sale_id': 1, 'name': 'Feed', 'quantity': 5, 'price': 20.0});
            }));
    await old.close();
    final upgraded = await databaseFactoryFfiNoIsolate.openDatabase(path,
        options: posDatabaseOptions());
    try {
      final row = (await upgraded.query('sale_items')).single;
      expect(row['name'], 'Feed');
      expect(row['quantity'], 5);
      expect(row.containsKey('product_id'), isTrue);
      expect(row.containsKey('category'), isTrue);
      expect(row['product_id'], isNull);
    } finally {
      await upgraded.close();
      await directory.delete(recursive: true);
    }
  });
}
