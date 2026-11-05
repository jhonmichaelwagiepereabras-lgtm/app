import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/category_input.dart';

void main() {
  test('Matches two characters and multiple category words without duplicates',
      () {
    final categories = [
      'Animal Feeds',
      'Hardware Supplies',
      ' animal   feeds ',
      'Pet Food'
    ];
    expect(matchingCategories('a', categories), isEmpty);
    expect(matchingCategories('an', categories), ['Animal Feeds']);
    expect(matchingCategories('animal fe', categories), ['Animal Feeds']);
    expect(matchingCategories('sup hard', categories), ['Hardware Supplies']);
    expect(matchingCategories('new category', categories), isEmpty);
    expect(canonicalCategory('  ANIMAL   feeds ', categories), 'Animal Feeds');
  });
  testWidgets('Selecting a suggestion fills the field and hides suggestions',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(16),
                child: CategoryInput(controller: controller, categories: const [
                  'Animal Feeds',
                  'Hardware Supplies'
                ])))));
    await tester.enterText(
        find.byKey(const ValueKey('product-category')), 'animal fe');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inline-category-suggestion')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accept-category-suggestion')));
    await tester.pumpAndSettle();
    expect(controller.text, 'Animal Feeds');
    expect(
        find.byKey(const ValueKey('inline-category-suggestion')), findsNothing);
    expect(
        find.byKey(const ValueKey('accept-category-suggestion')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
