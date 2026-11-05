import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/main.dart';
import 'package:coral_pos/data/pos_database.dart';
import 'package:coral_pos/data/database_connection.dart';

void main() {
  for (final manual in [false, true]) {
    testWidgets('Unread receipt status persists (manual: $manual)',
        (tester) async {
      await tester.runAsync(() async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        sqfliteFfiInit();
        PosDatabase.instance = PosDatabase(
            open: () => databaseFactoryFfiNoIsolate.openDatabase(
                inMemoryDatabasePath,
                options: posDatabaseOptions()));
        await PosDatabase.instance.database;
        addTearDown(() async => PosDatabase.instance.close());
        final now = DateTime.now();
        Map<String, dynamic> sale(DateTime date) => {
              'date': date.toIso8601String(),
              'total': 8.0,
              'count': 1,
              'items': [
                {'name': 'Berry Cake', 'price': 8.0, 'quantity': 1}
              ]
            };
        SharedPreferences.setMockInitialValues({
          'sales': jsonEncode([
            sale(now),
            if (manual) sale(now.subtract(const Duration(microseconds: 1))),
            sale(now.subtract(const Duration(days: 1)))
          ])
        });
        await tester.pumpWidget(const PosApp());
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<Badge>(
                    find.byKey(const ValueKey('unread-receipt-badge')))
                .isLabelVisible,
            isTrue);
        await tester.tap(find.text('Transactions'));
        await tester.pumpAndSettle();
        expect(
            find.text(manual ? '2 unviewed receipts' : '1 unviewed receipts'),
            findsOneWidget);
        final cardFinder =
            find.byKey(ValueKey('transaction-${now.toIso8601String()}'));
        expect(tester.widget<Card>(cardFinder).color, const Color(0xFFFFEFE6));
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pumpAndSettle();
        expect(
            find.text(manual ? '2 unviewed receipts' : '1 unviewed receipts'),
            findsOneWidget);
        if (manual) {
          await tester.ensureVisible(find.text('Mark all as viewed'));
          await tester.tap(find.text('Mark all as viewed'));
          await tester.pumpAndSettle();
          expect(find.text('Mark all as viewed'), findsNothing);
          expect(find.text('Print receipt'), findsNothing);
        } else {
          await tester.ensureVisible(find.text('View / print receipt'));
          await tester.tap(find.text('View / print receipt'));
          await tester.pumpAndSettle();
          expect(find.text('Print receipt'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        expect(
            find.text(manual ? '2 unviewed receipts' : '1 unviewed receipts'),
            findsNothing);
        expect(tester.widget<Card>(cardFinder).color, Colors.white);
        expect(
            tester
                .widget<Badge>(
                    find.byKey(const ValueKey('unread-receipt-badge')))
                .isLabelVisible,
            isFalse);
        final restored = await PosDatabase.instance.load([], 'Default');
        expect((restored['sales'] as List).first['receipt_viewed'], isTrue);
        expect((restored['sales'] as List).last['receipt_viewed'], isFalse);
        if (manual) {
          expect((restored['sales'] as List)[1]['receipt_viewed'], isTrue);
        }
      });
    });
  }
}
