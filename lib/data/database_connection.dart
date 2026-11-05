import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'database_native.dart' if (dart.library.js_interop) 'database_web.dart'
    as platform;

Future<Database> openPosDatabase() async {
  final factory = platform.posDatabaseFactory();
  final path = kIsWeb
      ? 'coral_pos.db'
      : p.join(await factory.getDatabasesPath(), 'coral_pos.db');
  return factory.openDatabase(path, options: posDatabaseOptions());
}

OpenDatabaseOptions posDatabaseOptions() => OpenDatabaseOptions(
      version: 5,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          final columns = (await db.rawQuery('PRAGMA table_info(sales)'))
              .map((column) => column['name'])
              .toSet();
          if (columns.isNotEmpty && !columns.contains('receipt_data')) {
            await db.execute('ALTER TABLE sales ADD COLUMN receipt_data TEXT');
          }
        }
        if (oldVersion < 2) {
          final columns = (await db.rawQuery('PRAGMA table_info(sales)'))
              .map((column) => column['name'])
              .toSet();
          for (final name in ['cash_tendered', 'change_due']) {
            if (!columns.contains(name)) {
              await db.execute('ALTER TABLE sales ADD COLUMN $name REAL');
            }
          }
        }
        if (oldVersion < 3) {
          final columns = (await db.rawQuery('PRAGMA table_info(sale_items)'))
              .map((c) => c['name'])
              .toSet();
          if (columns.isNotEmpty) {
            for (final name in ['product_id', 'category']) {
              if (!columns.contains(name)) {
                await db
                    .execute('ALTER TABLE sale_items ADD COLUMN $name TEXT');
              }
            }
          }
        }
        if (oldVersion < 4) {
          final columns = (await db.rawQuery('PRAGMA table_info(sales)'))
              .map((column) => column['name'])
              .toSet();
          if (columns.isNotEmpty && !columns.contains('receipt_viewed')) {
            await db.execute(
                'ALTER TABLE sales ADD COLUMN receipt_viewed INTEGER NOT NULL DEFAULT 0');
          }
        }
      },
      // Some older installations already contain newer columns.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE products (id TEXT PRIMARY KEY, name TEXT NOT NULL, price REAL NOT NULL CHECK(price >= 0), stock INTEGER NOT NULL CHECK(stock >= 0), category TEXT NOT NULL, emoji TEXT NOT NULL, photo TEXT)');
        await db.execute(
            'CREATE TABLE sales (id INTEGER PRIMARY KEY, date TEXT NOT NULL, total REAL NOT NULL, count INTEGER NOT NULL, cash_tendered REAL, change_due REAL, receipt_viewed INTEGER NOT NULL DEFAULT 0, receipt_data TEXT)');
        await db.execute(
            'CREATE TABLE sale_items (id INTEGER PRIMARY KEY, sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE, name TEXT NOT NULL, quantity INTEGER NOT NULL, price REAL NOT NULL, product_id TEXT, category TEXT)');
        await db.execute('CREATE INDEX sales_date ON sales(date)');
        await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
