import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'app_language.dart';

String defaultCategoryEmblem(String name) {
  final text = name.toLowerCase();
  if (text == 'all menu') return '\u{1F6CD}';
  if (RegExp(r'agrivet|feed|farm|agri|patuka').hasMatch(text)) {
    return '\u{1F33E}';
  }
  if (RegExp(r'hardware|tool|construction').hasMatch(text)) return '\u{1F6E0}';
  if (RegExp(r'snack|cake|bread|dessert').hasMatch(text)) return '\u{1F370}';
  if (RegExp(r'drink|beverage|juice|coffee|inumin').hasMatch(text)) {
    return '\u{1F964}';
  }
  if (RegExp(r'food|meal|pagkain').hasMatch(text)) return '\u{1F354}';
  if (RegExp(r'cloth|apparel|damit').hasMatch(text)) return '\u{1F455}';
  if (RegExp(r'medicine|pharma|gamot').hasMatch(text)) return '\u{1F48A}';
  if (RegExp(r'beauty|cosmetic').hasMatch(text)) return '\u{1F484}';
  return '\u{1F4E6}';
}

class CategoryEmblem extends StatelessWidget {
  final String value;
  const CategoryEmblem({super.key, required this.value});
  @override
  Widget build(BuildContext context) {
    if (value.startsWith('image:')) {
      try {
        return Image.memory(base64Decode(value.substring(6)),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) =>
                const Icon(Icons.category_outlined));
      } catch (_) {
        return const Icon(Icons.category_outlined);
      }
    }
    return Text(value, style: const TextStyle(fontSize: 26));
  }
}

Future<String?> chooseCategoryEmblem(
    BuildContext context, String current) async {
  final controller =
      TextEditingController(text: current.startsWith('image:') ? '' : current);
  String? error;
  final result = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: const LText('Category icon'),
                content: SizedBox(
                    width: 340,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            '\u{1F6CD}',
                            '\u{1F4E6}',
                            '\u{1F33E}',
                            '\u{1F331}',
                            '\u{1F414}',
                            '\u{1F404}',
                            '\u{1F43E}',
                            '\u{1F528}',
                            '\u{1F529}',
                            '\u{1F6E0}',
                            '\u{1F370}',
                            '\u{1F354}',
                            '\u{1F964}',
                            '\u{1F455}',
                            '\u{1F48A}',
                            '\u{1F484}',
                            '\u{1F4F1}',
                            '\u{1F4DA}'
                          ]
                              .map((emoji) => ActionChip(
                                  label: Text(emoji,
                                      style: const TextStyle(fontSize: 24)),
                                  onPressed: () =>
                                      Navigator.pop(dialog, emoji)))
                              .toList()),
                      const SizedBox(height: 16),
                      TextField(
                          key: const ValueKey('custom-category-emoji'),
                          controller: controller,
                          maxLength: 4,
                          keyboardType: TextInputType.text,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: (_) => update(() {}),
                          decoration: InputDecoration(
                              labelText: tr('Keyboard emoji / custom emblem'),
                              helperText: tr(
                                  'Tap Browse emojis if your keyboard has no emoji key.'),
                              helperMaxLines: 3)),
                      TextButton.icon(
                          key: const ValueKey('browse-category-emojis'),
                          icon: const Icon(Icons.emoji_emotions_outlined),
                          label: const LText('Browse emojis'),
                          onPressed: () async {
                            FocusScope.of(dialog).unfocus();
                            final emoji = await showModalBottomSheet<String>(
                                context: dialog,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (sheet) => Padding(
                                    padding: EdgeInsets.only(
                                        bottom: MediaQuery.viewInsetsOf(sheet)
                                            .bottom),
                                    child: SafeArea(
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                          Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      16, 8, 8, 0),
                                              child: Row(children: [
                                                const Expanded(
                                                    child: LText(
                                                        'Choose an emoji')),
                                                IconButton(
                                                    onPressed: () =>
                                                        Navigator.pop(sheet),
                                                    icon: const Icon(
                                                        Icons.close)),
                                              ])),
                                          EmojiPicker(
                                              key: const ValueKey(
                                                  'category-emoji-picker'),
                                              onEmojiSelected: (_, emoji) =>
                                                  Navigator.pop(
                                                      sheet, emoji.emoji),
                                              config: Config(
                                                  height: math.max(
                                                      0.0,
                                                      math.min(
                                                          MediaQuery.sizeOf(sheet)
                                                                  .height *
                                                              .4,
                                                          MediaQuery.sizeOf(sheet)
                                                                  .height -
                                                              MediaQuery.viewInsetsOf(sheet)
                                                                  .bottom -
                                                              MediaQuery.paddingOf(sheet)
                                                                  .vertical -
                                                              80)),
                                                  checkPlatformCompatibility:
                                                      false,
                                                  searchViewConfig:
                                                      const SearchViewConfig(
                                                          inputTextStyle:
                                                              TextStyle(color: Colors.black87),
                                                          hintTextStyle: TextStyle(color: Colors.black54)),
                                                  categoryViewConfig: const CategoryViewConfig(initCategory: Category.SMILEYS),
                                                  emojiViewConfig: const EmojiViewConfig(columns: 7, emojiSizeMax: 28))),
                                        ]))));
                            if (dialog.mounted && emoji != null) {
                              update(() {
                                controller.text = emoji;
                                controller.selection = TextSelection.collapsed(
                                    offset: emoji.length);
                              });
                            }
                          }),
                      if (controller.text.trim().isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                                width: 48,
                                height: 48,
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: CategoryEmblem(
                                        value: controller.text.trim())))),
                      TextButton.icon(
                          onPressed: () async {
                            try {
                              final file = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 256,
                                  maxHeight: 256,
                                  imageQuality: 80);
                              if (file == null) return;
                              final data = await file.readAsBytes();
                              if (dialog.mounted) {
                                Navigator.pop(
                                    dialog, 'image:${base64Encode(data)}');
                              }
                            } catch (_) {
                              if (dialog.mounted) {
                                update(() => error = tr(
                                    'Photo could not be opened. Check photo permissions.'));
                              }
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const LText('Choose category logo')),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const LText('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          Navigator.pop(dialog, controller.text.trim());
                        }
                      },
                      child: const LText('Save'))
                ],
              )));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}
