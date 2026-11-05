import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coral_pos/category_emblem.dart';

void main() {
  for (final browser in [false, true]) {
    testWidgets(
        'Custom emoji selection saves intact (in-app browser: $browser)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      String? selected;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        selected =
                            await chooseCategoryEmblem(context, '\u{1F4E6}');
                      },
                      child: const Text('Choose icon'))))));
      await tester.tap(find.text('Choose icon'));
      await tester.pumpAndSettle();
      final emoji = browser
          ? '\u{1F600}'
          : '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}';
      if (browser) {
        await tester.ensureVisible(
            find.byKey(const ValueKey('browse-category-emojis')));
        await tester.tap(find.byKey(const ValueKey('browse-category-emojis')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('category-emoji-picker')),
            findsOneWidget);
        await tester.tap(find.byIcon(Icons.search).last);
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(
            bottom: 300 * tester.view.devicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final search = find.descendant(
            of: find.byKey(const ValueKey('category-emoji-picker')),
            matching: find.byType(TextField));
        await tester.enterText(search, 'grinning');
        await tester.pumpAndSettle();
        expect(find.text('grinning'), findsOneWidget);
        final keyboardTop = tester.view.physicalSize.height /
                tester.view.devicePixelRatio -
            300;
        expect(tester.getBottomLeft(search).dy, lessThanOrEqualTo(keyboardTop));
        expect(tester.getBottomLeft(find.text(emoji).first).dy,
            lessThanOrEqualTo(keyboardTop));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(emoji).first);
        tester.view.resetViewInsets();
      } else {
        await tester.enterText(
            find.byKey(const ValueKey('custom-category-emoji')), emoji);
      }
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
          find.byKey(const ValueKey('custom-category-emoji')));
      expect(field.controller!.text, emoji);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(selected, emoji);
    });
  }
}
