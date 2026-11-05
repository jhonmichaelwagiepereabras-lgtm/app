import 'product_fixture.dart';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/data/pos_database.dart';
import 'package:coral_pos/data/database_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coral_pos/main.dart';

void main() {
  setUp(() async {
    sqfliteFfiInit();
    PosDatabase.instance = PosDatabase(
        open: () => databaseFactoryFfiNoIsolate
            .openDatabase(inMemoryDatabasePath, options: posDatabaseOptions()));
    await PosDatabase.instance.database;
  });
  tearDown(() async => PosDatabase.instance.close());
  testWidgets('Completed sale updates revenue and stock', (tester) async {
    late SnackBar confirmation;
    await tester.runAsync(() async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'products': testProductsJson});
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 items selected'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cash-tendered')), '10');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment received'));
      await tester.pumpAndSettle();
      expect(find.text('● 9 Remaining'), findsOneWidget);
      expect(find.text('Best seller'), findsOneWidget);
      await tester.tap(find.text('Revenue'));
      await tester.pumpAndSettle();
      expect(find.text('₱8.00'), findsWidgets);
      final db = await PosDatabase.instance.database;
      expect((await db.query('sale_items')).first['name'], 'Berry Cake');
      expect((await db.query('sale_items')).first['product_id'], '1');
      expect((await db.query('sale_items')).first['category'], 'Snack');
      confirmation = tester.widget<SnackBar>(find.byType(SnackBar));
    });
    // Start the real app notification on the test clock to verify its timeout.
    final messenger =
        tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger));
    messenger.removeCurrentSnackBar();
    await tester.pumpAndSettle();
    messenger.showSnackBar(confirmation);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('Sale completed. Inventory and reports updated.'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Sale completed. Inventory and reports updated.'),
        findsNothing);
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('Total transactions'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('Revenue reports filter by day, month and year', (tester) async {
    await tester.runAsync(() async {
      final now = DateTime.now();
      Map<String, dynamic> sale(DateTime date, double amount) => {
            'date': date.toIso8601String(),
            'total': amount,
            'count': 1,
            'items': [
              {'name': 'Test product', 'quantity': 1, 'price': amount}
            ],
          };
      SharedPreferences.setMockInitialValues({
        'sales': jsonEncode([
          sale(now, 10),
          sale(DateTime(now.year, now.month, now.day == 1 ? 2 : 1), 20),
          sale(DateTime(now.year, now.month == 1 ? 2 : 1, 1), 30),
          sale(DateTime(now.year - 1, 1, 1), 100),
        ])
      });
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revenue'));
      await tester.pumpAndSettle();
      expect(find.text('Daily revenue'), findsOneWidget);
      expect(find.text('\u20b110.00'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('report-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly').last);
      await tester.pumpAndSettle();
      expect(find.text('Monthly revenue'), findsOneWidget);
      expect(find.text('\u20b130.00'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('report-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annual').last);
      await tester.pumpAndSettle();
      expect(find.text('Annual revenue'), findsOneWidget);
      expect(find.text('\u20b160.00'), findsWidgets);
    });
  });
}
