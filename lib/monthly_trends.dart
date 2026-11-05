/// Rank current products by units sold in the current local calendar month.
/// Tied leaders share a badge; categories with no sales have no winner.
Set<String> monthlyBestSellers(List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> sales, DateTime now) {
  final localNow = now.toLocal();
  final byId = {
    for (final product in products) product['id'] as String: product
  };
  final byName = <String, List<Map<String, dynamic>>>{};
  for (final product in products) {
    byName.putIfAbsent(product['name'] as String, () => []).add(product);
  }
  final quantities = <String, int>{};
  String categoryKey(String value) => value.trim().toLowerCase();
  for (final sale in sales) {
    final date = DateTime.tryParse(sale['date'] as String)?.toLocal();
    if (date == null ||
        date.year != localNow.year ||
        date.month != localNow.month ||
        date.isAfter(localNow)) {
      continue;
    }
    for (final item in sale['items']) {
      final id = item['product_id'] as String?;
      final matchingNames = byName[item['name']] ?? [];
      final product = id != null
          ? byId[id]
          : matchingNames.length == 1
              ? matchingNames.single
              : null;
      if (product == null) continue;
      final category = item['category'] as String?;
      if (category != null &&
          categoryKey(category) != categoryKey(product['category'] as String)) {
        continue;
      }
      final quantity = (item['quantity'] as num).toInt();
      if (quantity <= 0) continue;
      final productId = product['id'] as String;
      quantities[productId] = (quantities[productId] ?? 0) + quantity;
    }
  }
  final maximums = <String, int>{};
  for (final entry in quantities.entries) {
    final category = categoryKey(byId[entry.key]!['category'] as String);
    if (entry.value > (maximums[category] ?? 0)) {
      maximums[category] = entry.value;
    }
  }
  return {
    for (final entry in quantities.entries)
      if (entry.value ==
          maximums[categoryKey(byId[entry.key]!['category'] as String)])
        entry.key
  };
}
