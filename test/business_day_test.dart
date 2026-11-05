import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/business_day.dart';

void main() {
  test('Closing lasts only for the current phone calendar day', () {
    final closing = DateTime(2026, 11, 3, 22);
    final key = businessDayKey(closing);
    expect(isBusinessDayClosed(key, DateTime(2026, 11, 3, 23, 59)), isTrue);
    expect(isBusinessDayClosed(key, DateTime(2026, 11, 4)), isFalse);
    expect(isBusinessDayClosed('', closing), isFalse);
  });
  test('A new day hides old transactions without deleting history', () {
    final sales = <Map<String, dynamic>>[
      {'date': DateTime(2026, 11, 3, 23, 59).toIso8601String(), 'total': 100.0},
      {'date': DateTime(2026, 11, 4, 0, 1).toIso8601String(), 'total': 50.0},
    ];
    expect(
        transactionsForDay(sales, DateTime(2026, 11, 4)).single['total'], 50.0);
    expect(transactionsForDay(sales, DateTime(2026, 11, 5)), isEmpty);
    expect(sales.length, 2);
    expect(sales.fold<double>(0, (v, sale) => v + (sale['total'] as double)),
        150.0);
  });
}
