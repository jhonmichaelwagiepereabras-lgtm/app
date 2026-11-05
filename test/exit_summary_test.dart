import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/exit_summary.dart';

void main() {
  test('Exit summary uses today sales and current inventory', () {
    final now = DateTime(2026, 11, 3, 15, 30);
    final text = buildExitSummary(
        'My Store',
        [
          {
            'date': DateTime(2026, 11, 3, 12).toIso8601String(),
            'total': 150.0,
            'count': 3
          },
          {
            'date': DateTime(2026, 11, 3, 14).toIso8601String(),
            'total': 50.0,
            'count': 1
          },
          {
            'date': DateTime(2026, 11, 2).toIso8601String(),
            'total': 900.0,
            'count': 20
          },
        ],
        [
          {'name': 'Feed', 'stock': 12},
          {'name': 'Hammer', 'stock': 0},
        ],
        now);
    expect(text, contains('Total transactions: 2'));
    expect(text, contains('Revenue: PHP 200.00'));
    expect(text, contains('Units sold: 4'));
    expect(text, contains('Stock units: 12'));
    expect(text, contains('Out of stock: 1'));
    expect(text, contains('Feed: 12'));
    expect(text, contains('Hammer: 0'));
    expect(text, isNot(contains('900.00')));
  });
  testWidgets('Exit preview offers report actions and waits for explicit exit',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ExitSummaryPage(
                                  summary: 'Daily summary',
                                  date: DateTime(2026, 11, 3))));
                    },
                    child: const Text('Open exit'))))));
    await tester.tap(find.text('Open exit'));
    await tester.pumpAndSettle();
    expect(find.text('Print report'), findsOneWidget);
    expect(find.text('Download report'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('Open exit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit app'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
