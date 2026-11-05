import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/main.dart';
import 'package:coral_pos/data/pos_database.dart';
import 'package:coral_pos/data/database_connection.dart';

void main() {
  testWidgets(
      'Clear data requires confirmation and leaves no legacy or sample records',
      (tester) async {
    await tester.runAsync(() async {
      sqfliteFfiInit();
      PosDatabase.instance = PosDatabase(
          open: () => databaseFactoryFfiNoIsolate.openDatabase(
              inMemoryDatabasePath,
              options: posDatabaseOptions()));
      await PosDatabase.instance.database;
      addTearDown(() async => PosDatabase.instance.close());
      SharedPreferences.setMockInitialValues({
        'products': jsonEncode([
          {
            'id': '1',
            'name': 'Test feed',
            'price': 50.0,
            'stock': 5,
            'category': 'Agrivet',
            'emoji': '',
            'photo': null
          }
        ]),
        'shop': 'Test Store',
        'sales': jsonEncode([
          {
            'date': DateTime.now().toIso8601String(),
            'total': 50.0,
            'count': 1,
            'items': [
              {'name': 'Test feed', 'quantity': 1, 'price': 50.0}
            ]
          }
        ])
      });
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      await PosDatabase.instance.updateSettings({
        'receipt_address': 'Test address',
        'show_category_icons': '1',
        'category_emblems': '{"agrivet":"custom"}',
        'printer': 'test device',
        'language': 'en'
      });
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Clear data'), 150);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final db = await PosDatabase.instance.database;
      expect((await db.query('products')).length, 1);
      await tester.tap(find.text('Clear data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear all data'));
      await tester.pumpAndSettle();
      for (final table in ['products', 'sales', 'sale_items']) {
        expect(await db.query(table), isEmpty);
      }
      final settings = await PosDatabase.instance.readSettings();
      expect(settings, {'initialized': '1', 'shop': 'MPOS', 'language': 'en'});
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['products', 'sales', 'shop']) {
        expect(prefs.getString(key), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      expect(find.text('No products found. Add a product to get started.'),
          findsOneWidget);
      expect((await db.query('products')), isEmpty);
    });
  });
}
