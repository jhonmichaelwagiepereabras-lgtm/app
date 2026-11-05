import 'product_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/main.dart';
import 'package:coral_pos/app_language.dart';
import 'package:coral_pos/data/pos_database.dart';
import 'package:coral_pos/data/database_connection.dart';

void main() {
  testWidgets('Language switches both ways and persists after reopening',
      (tester) async {
    await tester.runAsync(() async {
      sqfliteFfiInit();
      PosDatabase.instance = PosDatabase(
          open: () => databaseFactoryFfiNoIsolate.openDatabase(
              inMemoryDatabasePath,
              options: posDatabaseOptions()));
      await PosDatabase.instance.database;
      addTearDown(() async {
        await PosDatabase.instance.close();
        appLanguage.value = 'en';
      });
      SharedPreferences.setMockInitialValues({'products': testProductsJson});
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Version 1.0.0'), 150);
      expect(find.text('MPOS'), findsWidgets);
      await tester.ensureVisible(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tagalog'));
      await tester.pumpAndSettle();
      expect(find.text('Mga Setting'), findsWidgets);
      expect(find.text('Impormasyon ng resibo'), findsOneWidget);
      expect((await PosDatabase.instance.readSettings())['language'], 'tl');
      await tester.pumpWidget(const SizedBox());
      appLanguage.value = 'en';
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      expect(appLanguage.value, 'tl');
      await tester.tap(find.text('Produkto'));
      await tester.pumpAndSettle();
      expect(find.text('Berry Cake'), findsWidgets);
      await tester.tap(find.text('Idagdag'));
      await tester.pumpAndSettle();
      expect(find.text('Pangalan ng produkto'), findsOneWidget);
      await tester.tap(find.text('Kanselahin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mga Setting'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Wika'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wika'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Receipt information'), -150);
      expect(find.text('Receipt information'), findsOneWidget);
      expect((await PosDatabase.instance.readSettings())['language'], 'en');
    });
  });
}
