import 'product_fixture.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/main.dart';
import 'package:coral_pos/data/pos_database.dart';
import 'package:coral_pos/data/database_connection.dart';

void main() {
  testWidgets('Close persists, blocks sales and preserves stock and history',
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
        'products': testProductsJson,
        'sales': jsonEncode([
          {
            'date': DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'total': 100.0,
            'count': 1,
            'items': [
              {'name': 'Old product', 'price': 100.0, 'quantity': 1}
            ],
          }
        ])
      });
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transactions'));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Old product'), findsNothing);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close POS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close POS').last);
      await tester.pumpAndSettle();
      expect(find.text('Closed for today'), findsOneWidget);
      final db = await PosDatabase.instance.database;
      expect((await db.query('sales')).length, 1);
      expect(
          (await db.query('products', where: 'id = ?', whereArgs: ['1']))
              .single['stock'],
          10);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      expect(find.text('POS closed'), findsOneWidget);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reopen POS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reopen POS').last);
      await tester.pumpAndSettle();
      expect(find.text('End the store day'), findsOneWidget);
      expect((await PosDatabase.instance.readSettings())['closed_business_day'],
          '');
    });
  });
}
