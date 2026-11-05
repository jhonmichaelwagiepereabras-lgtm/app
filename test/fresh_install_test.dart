import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:coral_pos/main.dart';
import 'package:coral_pos/data/pos_database.dart';
import 'package:coral_pos/data/database_connection.dart';

void main() {
  testWidgets('Fresh installation starts with no demo products',
      (tester) async {
    await tester.runAsync(() async {
      sqfliteFfiInit();
      PosDatabase.instance = PosDatabase(
          open: () => databaseFactoryFfiNoIsolate.openDatabase(
              inMemoryDatabasePath,
              options: posDatabaseOptions()));
      await PosDatabase.instance.database;
      addTearDown(() async => PosDatabase.instance.close());
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const PosApp());
      await tester.pumpAndSettle();
      expect(find.text('No products found. Add a product to get started.'),
          findsOneWidget);
      expect(find.text('Berry Cake'), findsNothing);
      final db = await PosDatabase.instance.database;
      expect(await db.query('products'), isEmpty);
      expect(await db.query('sales'), isEmpty);
      expect((await PosDatabase.instance.readSettings())['shop'], 'MPOS');
    });
  });
}
