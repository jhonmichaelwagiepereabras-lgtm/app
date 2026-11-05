import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/monthly_trends.dart';

void main() {
  final products = <Map<String, dynamic>>[
    {'id': 'a', 'name': 'Feed A', 'category': 'Agrivet'},
    {'id': 'b', 'name': 'Feed B', 'category': 'Agrivet'},
    {'id': 'c', 'name': 'Hammer', 'category': 'Hardware'},
  ];
  Map<String, dynamic> sale(DateTime date, List<Map<String, dynamic>> items) =>
      {'date': date.toIso8601String(), 'items': items};
  Map<String, dynamic> item(String id, int quantity) =>
      {'product_id': id, 'quantity': quantity, 'name': 'Previous name'};
  test('Monthly leaders use quantities within each category and share ties',
      () {
    final sales = [
      sale(DateTime(2026, 11, 2), [item('a', 4), item('b', 2), item('c', 1)]),
      sale(DateTime(2026, 11, 3), [item('b', 2)]),
      sale(DateTime(2026, 10, 31), [item('b', 100)]),
    ];
    expect(monthlyBestSellers(products, sales, DateTime(2026, 11, 4)),
        {'a', 'b', 'c'});
    expect(monthlyBestSellers(products, sales, DateTime(2026, 12, 1)), isEmpty);
    sales.add(sale(DateTime(2026, 12, 1), [item('b', 1)]));
    expect(monthlyBestSellers(products, sales, DateTime(2026, 12, 2)), {'b'});
  });
  test(
      'Old sales map only unique names and category moves do not carry old trends',
      () {
    final sales = [
      sale(DateTime(2026, 11, 1), [
        {'name': 'Feed B', 'quantity': 3},
        {...item('a', 9), 'category': 'Food'},
        item('deleted', 100),
      ])
    ];
    expect(monthlyBestSellers(products, sales, DateTime(2026, 11, 2)), {'b'});
    expect(
        monthlyBestSellers([
          ...products,
          {'id': 'd', 'name': 'Feed B', 'category': 'Food'}
        ], sales, DateTime(2026, 11, 2)),
        isEmpty);
  });
}
