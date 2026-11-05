import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/main.dart';
import 'package:coral_pos/data/pos_database.dart';
import 'package:coral_pos/data/database_connection.dart';
import 'product_fixture.dart';

void main() {
  testWidgets(
      'Category icon setting defaults off, customizes and persists across restarts',
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
      SharedPreferences.setMockInitialValues({'products': testProductsJson});
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-icon-Snack')), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Snack'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-category-icons')));
      await tester.pumpAndSettle();
      expect((await PosDatabase.instance.readSettings())['show_category_icons'],
          '1');
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-icon-Snack')), findsOneWidget);
      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('category-icon-Snack'))));
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('\u{1F33E}'));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect((await PosDatabase.instance.readSettings())['category_emblems'],
          contains('snack'));
      expect(find.text('\u{1F33E}'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-category-icons')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Snack'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-category-icons')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('\u{1F33E}'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Field Supplies');
      await tester.enterText(find.byType(TextFormField).at(1), '25');
      await tester.enterText(find.byType(TextFormField).at(2), '10');
      await tester.enterText(
          find.byKey(const ValueKey('product-category')), 'Hardware');
      await tester.ensureVisible(
          find.byKey(const ValueKey('choose-product-category-icon')));
      await tester
          .tap(find.byKey(const ValueKey('choose-product-category-icon')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('\u{1F528}'));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      final db = await PosDatabase.instance.database;
      expect(
          (await db.query('products',
                  where: 'name = ?', whereArgs: ['Field Supplies']))
              .single['category'],
          'Hardware');
      expect((await PosDatabase.instance.readSettings())['category_emblems'],
          contains('hardware'));
    });
  });
}
