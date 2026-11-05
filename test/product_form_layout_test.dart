import 'product_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/main.dart';
import 'package:coral_pos/data/pos_database.dart';
import 'package:coral_pos/data/database_connection.dart';

void main() {
  testWidgets(
      'Product form uses phone width and keeps actions above the keyboard',
      (tester) async {
    await tester.runAsync(() async {
      tester.view.physicalSize = const Size(360, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
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
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final dialog = tester.getRect(find.byType(AlertDialog));
      expect(dialog.width, greaterThanOrEqualTo(330));
      expect(
          tester.getBottomRight(find.text('Save product')).dy, lessThan(540));
      await tester
          .ensureVisible(find.byKey(const ValueKey('product-category')));
      await tester.enterText(
          find.byKey(const ValueKey('product-category')), 'sn');
      await tester.pumpAndSettle();
      expect(find.text('Snack'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
