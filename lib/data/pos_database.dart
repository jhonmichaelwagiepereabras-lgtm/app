import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_connection.dart';

/// SQLite storage. Each snapshot commits inventory, sales and settings together.
class PosDatabase {
  static PosDatabase instance = PosDatabase();
  final Future<Database> Function() _open;
  Future<Database>? _database;
  PosDatabase({Future<Database> Function()? open})
      : _open = open ?? openPosDatabase;
  Future<Database> get database => _database ??= _openRecoverably();

  Future<Database> _openRecoverably() async {
    try {
      return await _open();
    } catch (_) {
      // Do not cache a failed connection: Retry must attempt a fresh open.
      _database = null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> load(
      List<Map<String, dynamic>> defaults, String defaultShop) async {
    final db = await database;
    if ((await db
            .query('settings', where: 'key = ?', whereArgs: ['initialized']))
        .isEmpty) {
      // Read legacy data before writing; leave the original preferences untouched.
      final prefs = await SharedPreferences.getInstance();
      final legacyProducts = prefs.getString('products');
      final legacySales = prefs.getString('sales');
      await write(
        legacyProducts == null
            ? defaults
            : (jsonDecode(legacyProducts) as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
        legacySales == null
            ? []
            : (jsonDecode(legacySales) as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
        prefs.getString('shop') ?? defaultShop,
      );
    }
    final products = await db.query('products', orderBy: 'rowid');
    final rows = await db.query('sales', orderBy: 'id');
    final items = await db.query('sale_items', orderBy: 'id');
    final sales = rows
        .map((s) => <String, dynamic>{
              if (s['receipt_data'] != null)
                ...Map<String, dynamic>.from(
                    jsonDecode(s['receipt_data'] as String)),
              'date': s['date'],
              'total': s['total'],
              'count': s['count'],
              'cash_tendered': s['cash_tendered'],
              'change_due': s['change_due'],
              'receipt_viewed': s['receipt_viewed'] == 1,
              'items': items
                  .where((i) => i['sale_id'] == s['id'])
                  .map((i) => {
                        'product_id': i['product_id'],
                        'category': i['category'],
                        'name': i['name'],
                        'quantity': i['quantity'],
                        'price': i['price']
                      })
                  .toList(),
            })
        .toList();
    final shop =
        await db.query('settings', where: 'key = ?', whereArgs: ['shop']);
    return {'products': products, 'sales': sales, 'shop': shop.first['value']};
  }

  Future<void> write(List<Map<String, dynamic>> products,
      List<Map<String, dynamic>> sales, String shop,
      {Map<String, String> extraSettings = const {}}) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('sale_items');
      batch.delete('sales');
      batch.delete('products');
      for (final product in products) {
        batch.insert('products', product);
      }
      for (int i = 0; i < sales.length; i++) {
        final sale = sales[i];
        batch.insert('sales', {
          'id': i + 1,
          'date': sale['date'],
          'total': sale['total'],
          'count': sale['count'],
          'cash_tendered': sale['cash_tendered'],
          'change_due': sale['change_due'],
          'receipt_viewed': sale['receipt_viewed'] == true ? 1 : 0,
          'receipt_data': jsonEncode({
            for (final entry in sale.entries)
              if (![
                'items',
                'date',
                'total',
                'count',
                'cash_tendered',
                'change_due',
                'receipt_viewed'
              ].contains(entry.key))
                entry.key: entry.value
          }),
        });
        for (final item in sale['items']) {
          batch.insert('sale_items', {
            'sale_id': i + 1,
            'product_id': item['product_id'],
            'category': item['category'],
            'name': item['name'],
            'quantity': item['quantity'],
            'price': item['price']
          });
        }
      }
      batch.insert('settings', {'key': 'shop', 'value': shop},
          conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('settings', {'key': 'initialized', 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      extraSettings.forEach((key, value) => batch.insert(
          'settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace));
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, String>> readSettings() async {
    final rows = await (await database).query('settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String
    };
  }

  Future<void> updateSettings(Map<String, String> settings) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      settings.forEach((key, value) => batch.insert(
          'settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace));
      await batch.commit(noResult: true);
    });
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) await (await db).close();
  }

  /// User-confirmed reset. Keep the migration marker so legacy/sample data
  /// cannot reappear on the next launch.
  Future<void> clearAllData() async {
    final db = await database;
    final settings = await readSettings();
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['products', 'sales', 'shop']) {
      await prefs.remove(key);
    }
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('sale_items');
      batch.delete('sales');
      batch.delete('products');
      batch.delete('settings');
      batch.insert('settings', {'key': 'initialized', 'value': '1'});
      batch.insert('settings', {'key': 'shop', 'value': 'MPOS'});
      if (settings['language'] != null) {
        batch.insert(
            'settings', {'key': 'language', 'value': settings['language']});
      }
      await batch.commit(noResult: true);
    });
  }
}
