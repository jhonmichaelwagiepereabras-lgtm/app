import 'package:flutter/material.dart';
import 'app_language.dart';

String categoryKey(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
String canonicalCategory(String text, Iterable<String> categories) {
  final key = categoryKey(text);
  for (final category in categories) {
    if (categoryKey(category) == key) return category;
  }
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

List<String> matchingCategories(String query, Iterable<String> categories) {
  final key = categoryKey(query);
  if (key.length < 2) return [];
  final words = key.split(' ');
  final unique = <String, String>{};
  for (final category in categories) {
    final normalized = categoryKey(category);
    if (normalized != key && words.every(normalized.contains)) {
      unique.putIfAbsent(normalized, () => category);
    }
  }
  final results = unique.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return results.take(5).toList();
}

class CategoryInput extends StatefulWidget {
  final TextEditingController controller;
  final List<String> categories;
  const CategoryInput(
      {super.key, required this.controller, required this.categories});
  @override
  State<CategoryInput> createState() => _CategoryInputState();
}

class _CategoryInputState extends State<CategoryInput> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
    focus.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(refresh);
    focus.removeListener(refresh);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = focus.hasFocus
        ? matchingCategories(widget.controller.text, widget.categories)
        : <String>[];
    final suggestion = suggestions.isEmpty ? null : suggestions.first;
    final typed = widget.controller.text;
    final suffix = suggestion != null &&
            suggestion.toLowerCase().startsWith(typed.toLowerCase())
        ? suggestion.substring(typed.length)
        : null;
    void accept() {
      if (suggestion == null) return;
      widget.controller.text = suggestion;
      widget.controller.selection =
          TextSelection.collapsed(offset: suggestion.length);
    }

    const inputStyle = TextStyle(fontSize: 16, height: 1.25);
    return Stack(children: [
      TextFormField(
        key: const ValueKey('product-category'),
        controller: widget.controller,
        focusNode: focus,
        style: inputStyle,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: tr('e.g. Clothing'),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
          suffixIcon: suggestion == null
              ? null
              : suffix == null
                  ? SizedBox(
                      width: 100,
                      child: TextButton(
                        key: const ValueKey('accept-category-suggestion'),
                        onPressed: accept,
                        child: Text(suggestion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                      ))
                  : IconButton(
                      key: const ValueKey('accept-category-suggestion'),
                      tooltip: '${tr('Use category')}: $suggestion',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onPressed: accept,
                      icon: const Icon(Icons.check, color: Color(0xFFFF7958)),
                    ),
        ),
        validator: (v) => v == null || v.trim().isEmpty
            ? tr('Enter a category')
            : categoryKey(v) == 'all menu'
                ? tr('Choose another name')
                : null,
      ),
      if (suffix != null)
        Positioned(
          top: 16,
          left: 12,
          right: 36,
          child: IgnorePointer(
              child: ExcludeSemantics(
                  child: ClipRect(
                      child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: typed,
                  style: const TextStyle(color: Colors.transparent)),
              TextSpan(
                  text: suffix, style: const TextStyle(color: Colors.grey)),
            ]),
            key: const ValueKey('inline-category-suggestion'),
            style: inputStyle,
            maxLines: 1,
            overflow: TextOverflow.clip,
          )))),
        ),
    ]);
  }
}
