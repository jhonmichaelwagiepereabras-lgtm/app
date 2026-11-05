import 'category_emblem.dart';
import 'category_input.dart';
import 'exit_summary.dart';
import 'monthly_trends.dart';
import 'dart:async';
import 'business_day.dart';
import 'app_language.dart';
import 'dart:convert';
import 'cash_checkout_dialog.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, listEquals;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'data/pos_database.dart';
import 'receipts/receipt.dart';
import 'receipts/sales_history_page.dart';
import 'receipts/printer_page_stub.dart'
    if (dart.library.io) 'receipts/printer_page_native.dart';

const coral = Color(0xFFFF7958);
void main() => runApp(const PosApp());

class Product {
  String id, name, category, emoji;
  double price;
  int stock;
  String? photo;
  Product(this.id, this.name, this.price, this.stock, this.category, this.emoji,
      [this.photo]);
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
        'category': category,
        'emoji': emoji,
        'photo': photo
      };
  factory Product.fromJson(Map<String, dynamic> j) => Product(
      j['id'],
      j['name'],
      (j['price'] as num).toDouble(),
      j['stock'],
      j['category'],
      j['emoji'],
      j['photo']);
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, language, child) => MaterialApp(
          locale: Locale(language == 'tl' ? 'fil' : 'en'),
          supportedLocales: const [Locale('en'), Locale('fil')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          debugShowCheckedModeBanner: false,
          title: 'MPOS',
          theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: coral),
              scaffoldBackgroundColor: const Color(0xFFFAFAFC),
              fontFamily: 'Roboto',
              inputDecorationTheme: InputDecorationTheme(
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  floatingLabelAlignment: FloatingLabelAlignment.start,
                  alignLabelWithHint: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none))),
          home: const PosHome()));
}

class PosHome extends StatefulWidget {
  const PosHome({super.key});
  @override
  State<PosHome> createState() => _PosHomeState();
}

class _PosHomeState extends State<PosHome> with WidgetsBindingObserver {
  List<Product> products = [];
  List<Map<String, dynamic>> sales = [];
  final Map<String, int> cart = {};
  int page = 0;
  String category = 'All Menu', query = '', shop = 'MPOS';
  String reportPeriod = 'Daily';
  DateTime reportDate = DateTime.now();
  String? closedDay;
  String currentDay = businessDayKey(DateTime.now());
  Timer? dayTimer;
  bool closing = false;
  bool get posClosed => isBusinessDayClosed(closedDay, DateTime.now());
  List<Map<String, dynamic>> get todayTransactions =>
      transactionsForDay(sales, DateTime.now());
  int get unreadReceiptCount =>
      todayTransactions.where((sale) => sale['receipt_viewed'] != true).length;
  bool showCategoryIcons = false;
  bool categoryStyleSaving = false;
  Map<String, String> categoryEmblems = {};
  bool ready = false;
  String? storageError;
  double get total =>
      products.fold(0, (v, p) => v + p.price * (cart[p.id] ?? 0));
  int get count => cart.values.fold(0, (a, b) => a + b);
  double get revenue =>
      sales.fold(0, (v, s) => v + (s['total'] as num).toDouble());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dayTimer = Timer.periodic(const Duration(seconds: 1), (_) => refreshDay());
    load();
  }

  @override
  void dispose() {
    dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshDay();
  }

  void refreshDay() {
    final day = businessDayKey(DateTime.now());
    if (mounted && day != currentDay) {
      setState(() {
        if (businessDayKey(reportDate) == currentDay) {
          reportDate = DateTime.now();
        }
        currentDay = day;
        cart.clear();
      });
    }
  }

  Future<void> togglePos() async {
    if (closing) return;
    final reopen = posClosed;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: LText(reopen ? 'Reopen POS?' : 'Close POS for today?'),
              content: LText(reopen
                  ? 'Resume sales for today.'
                  : 'Unpaid cart items will be cleared. Products, stock and sales history are kept. The POS reopens automatically on the next phone calendar day.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const LText('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: LText(reopen ? 'Reopen POS' : 'Close POS'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => closing = true);
    try {
      final value = reopen ? '' : businessDayKey(DateTime.now());
      await PosDatabase.instance.updateSettings({'closed_business_day': value});
      if (mounted) {
        setState(() {
          closedDay = value;
          cart.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: LText('Could not update POS status. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => closing = false);
    }
  }

  bool databaseAvailable = false;
  Future<void> load() async {
    if (mounted) setState(() => ready = false);
    try {
      final data = await PosDatabase.instance
          .load(products.map((p) => p.toJson()).toList(), shop);
      products = (data['products'] as List)
          .map((j) => Product.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      sales = (data['sales'] as List)
          .map((j) => Map<String, dynamic>.from(j))
          .toList();
      shop = data['shop'] as String;
      final settings = await PosDatabase.instance.readSettings();
      appLanguage.value = settings['language'] == 'tl' ? 'tl' : 'en';
      closedDay = settings['closed_business_day'];
      showCategoryIcons = settings['show_category_icons'] == '1';
      categoryEmblems = Map<String, String>.from(
          jsonDecode(settings['category_emblems'] ?? '{}'));
      currentDay = businessDayKey(DateTime.now());
      databaseAvailable = true;
      storageError = null;
    } catch (error, stackTrace) {
      debugPrint('SQLite initialization failed: $error\n$stackTrace');
      storageError = 'Could not load the database. $error';
    }
    if (mounted) setState(() => ready = true);
  }

  Future<bool> save({Map<String, String> extraSettings = const {}}) async {
    try {
      if (!databaseAvailable) throw StateError('Database unavailable');
      await PosDatabase.instance.write(
          products.map((p) => p.toJson()).toList(),
          (jsonDecode(jsonEncode(sales)) as List)
              .map((j) => Map<String, dynamic>.from(j))
              .toList(),
          shop,
          extraSettings: extraSettings);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: LText(
                'Unable to save to SQLite. Please check available storage and retry.')));
      }
      return false;
    }
  }

  void adjust(Product p, int delta) {
    final next = (cart[p.id] ?? 0) + delta;
    if (next < 0 || next > p.stock) return;
    setState(() {
      if (next == 0) {
        cart.remove(p.id);
      } else {
        cart[p.id] = next;
      }
    });
  }

  Widget photo(Product p, {double size = 64}) {
    final placeholder = Center(
        child: Padding(
      padding: const EdgeInsets.all(6),
      child: Text(p.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: size > 30 ? 20 : 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8D4B38))),
    ));
    if (p.photo != null) {
      try {
        return Image.memory(base64Decode(p.photo!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, e, s) => placeholder);
      } catch (_) {}
    }
    return placeholder;
  }

  Widget labeledInput(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child:
                LText(label, style: const TextStyle(fontSize: 12, height: 1.2)),
          ),
          field,
        ],
      );

  Future<void> edit([Product? product]) async {
    final name = TextEditingController(text: product?.name ?? '');
    final price =
        TextEditingController(text: product?.price.toStringAsFixed(2) ?? '');
    final stock = TextEditingController(text: product?.stock.toString() ?? '0');
    final categoryInput = TextEditingController(text: product?.category ?? '');
    bool stockTapped = false;
    bool savingProduct = false;
    String? chosenCategoryIcon;
    String? picture = product?.photo, error;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    insetPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    title: LText(
                        product == null ? 'Add a product' : 'Edit product'),
                    content: SizedBox(
                        width: 520,
                        child: Form(
                            key: form,
                            child: SingleChildScrollView(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  Semantics(
                                    button: true,
                                    label: picture == null
                                        ? 'Add product photo'
                                        : 'Replace product photo',
                                    child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () async {
                                          try {
                                            final file = await ImagePicker()
                                                .pickImage(
                                                    source: ImageSource.gallery,
                                                    maxWidth: 1000,
                                                    imageQuality: 80);
                                            if (!dialogContext.mounted) return;
                                            if (file != null) {
                                              final Uint8List bytes =
                                                  await file.readAsBytes();
                                              update(() {
                                                picture = base64Encode(bytes);
                                                error = null;
                                              });
                                            }
                                          } catch (_) {
                                            if (!dialogContext.mounted) return;
                                            update(() => error =
                                                'Photo could not be opened. Check photo permissions.');
                                          }
                                        },
                                        child: Container(
                                            height:
                                                MediaQuery.viewInsetsOf(context)
                                                            .bottom >
                                                        0
                                                    ? 64
                                                    : 120,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                                color: const Color(0xFFFFEEE5),
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: picture == null
                                                ? const Center(
                                                    child: Icon(
                                                        Icons
                                                            .add_photo_alternate_outlined,
                                                        size: 44,
                                                        color: coral))
                                                : Image.memory(
                                                    base64Decode(picture!),
                                                    fit: BoxFit.cover))),
                                  ),
                                  const SizedBox(height: 20),
                                  if (picture != null)
                                    TextButton(
                                        onPressed: () =>
                                            update(() => picture = null),
                                        child: const LText('Remove photo')),
                                  if (error != null)
                                    Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 0, 16, 20),
                                        child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: LText(error!,
                                                style: const TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                    height: 1.4)))),
                                  TextFormField(
                                      controller: name,
                                      decoration: InputDecoration(
                                          labelText: tr('Product name')),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                              ? tr('Enter a name')
                                              : null),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                      controller: price,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: InputDecoration(
                                          labelText: tr('Price (₱)')),
                                      validator: (v) {
                                        final n = double.tryParse(v ?? '');
                                        return n == null || !n.isFinite || n < 0
                                            ? tr('Enter a valid price')
                                            : null;
                                      }),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: labeledInput(
                                              'Stock quantity',
                                              TextFormField(
                                                controller: stock,
                                                onTap: () {
                                                  if (!stockTapped) {
                                                    stock.clear();
                                                    stockTapped = true;
                                                  }
                                                },
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                    isDense: true,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 16)),
                                                validator: (v) => int.tryParse(
                                                                v ?? '') ==
                                                            null ||
                                                        int.parse(v!) <
                                                            (cart[product
                                                                    ?.id] ??
                                                                0)
                                                    ? tr(
                                                        'Invalid stock quantity')
                                                    : null,
                                              ))),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          flex: 2,
                                          child: labeledInput(
                                              'Category',
                                              CategoryInput(
                                                  controller: categoryInput,
                                                  categories: products
                                                      .map((p) => p.category)
                                                      .toList()))),
                                    ],
                                  ),
                                  if (showCategoryIcons)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: TextButton.icon(
                                            key: const ValueKey(
                                                'choose-product-category-icon'),
                                            onPressed: () async {
                                              if (categoryInput.text
                                                  .trim()
                                                  .isEmpty) {
                                                update(() => error =
                                                    tr('Enter a category'));
                                                return;
                                              }
                                              final value =
                                                  await chooseCategoryEmblem(
                                                      dialogContext,
                                                      chosenCategoryIcon ??
                                                          categoryEmblems[
                                                              categoryKey(
                                                                  categoryInput
                                                                      .text)] ??
                                                          defaultCategoryEmblem(
                                                              categoryInput
                                                                  .text));
                                              if (dialogContext.mounted &&
                                                  value != null) {
                                                update(() {
                                                  chosenCategoryIcon = value;
                                                  error = null;
                                                });
                                              }
                                            },
                                            icon: chosenCategoryIcon == null
                                                ? const Icon(
                                                    Icons.category_outlined)
                                                : SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: FittedBox(
                                                        child: CategoryEmblem(
                                                            value:
                                                                chosenCategoryIcon!))),
                                            label: LText(
                                                chosenCategoryIcon == null
                                                    ? 'Choose category icon'
                                                    : 'Change category icon'))),
                                ])))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const LText('Cancel')),
                      FilledButton(
                          onPressed: savingProduct
                              ? null
                              : () async {
                                  if (!form.currentState!.validate()) return;
                                  update(() => savingProduct = true);
                                  final previous =
                                      products.map((p) => p.toJson()).toList();
                                  final finalCategory = canonicalCategory(
                                      categoryInput.text,
                                      products.map((p) => p.category));
                                  final updatedEmblems = {
                                    ...categoryEmblems,
                                    if (chosenCategoryIcon != null)
                                      categoryKey(finalCategory):
                                          chosenCategoryIcon!
                                  };
                                  setState(() {
                                    if (product == null) {
                                      products.add(Product(
                                          DateTime.now()
                                              .microsecondsSinceEpoch
                                              .toString(),
                                          name.text.trim(),
                                          double.parse(price.text),
                                          int.parse(stock.text),
                                          canonicalCategory(categoryInput.text,
                                              products.map((p) => p.category)),
                                          '\u{1F4E6}',
                                          picture));
                                    } else {
                                      final target = products.firstWhere(
                                          (p) => p.id == product.id);
                                      target.name = name.text.trim();
                                      target.price = double.parse(price.text);
                                      target.stock = int.parse(stock.text);
                                      target.category = canonicalCategory(
                                          categoryInput.text,
                                          products.map((p) => p.category));
                                      target.photo = picture;
                                    }
                                  });
                                  final saved = await save(extraSettings: {
                                    if (chosenCategoryIcon != null)
                                      'category_emblems':
                                          jsonEncode(updatedEmblems),
                                  });
                                  if (!saved) {
                                    if (mounted) {
                                      setState(() => products = previous
                                          .map(Product.fromJson)
                                          .toList());
                                    }
                                    if (dialogContext.mounted) {
                                      update(() => savingProduct = false);
                                    }
                                    return;
                                  }
                                  if (mounted && chosenCategoryIcon != null) {
                                    setState(
                                        () => categoryEmblems = updatedEmblems);
                                  }
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                },
                          child: const LText('Save product'))
                    ])));
    // Controllers belong to the dialog and are released after its closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    price.dispose();
    stock.dispose();
    categoryInput.dispose();
  }

  Future<void> checkout() async {
    if (count == 0 || posClosed || closing) return;
    final checkoutDay = businessDayKey(DateTime.now());
    Map<String, String> receiptSettings;
    try {
      receiptSettings = await PosDatabase.instance.readSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load receipt information: $e')));
      }
      return;
    }
    if (!mounted) return;
    Map<String, dynamic> paymentDetails = {};
    final cashTendered = await showDialog<double>(
      context: context,
      builder: (_) => CashCheckoutDialog(
          onDetails: (details) => paymentDetails = details,
          total: total,
          items: products
              .where((p) => cart.containsKey(p.id))
              .map((p) => <String, dynamic>{
                    'name': p.name,
                    'quantity': cart[p.id],
                    'price': p.price
                  })
              .toList()),
    );
    if (cashTendered == null || !mounted || posClosed || closing) return;
    if (checkoutDay != businessDayKey(DateTime.now())) {
      refreshDay();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              LText('A new day has started. Please review your order again.')));
      return;
    }
    final previousCart = Map<String, int>.from(cart);
    final paidTotal =
        (paymentDetails['grand_total'] as num?)?.toDouble() ?? total;
    final invoiceNumber = sales.fold<int>(
            sales.length,
            (n, s) => (s['invoice_number'] as int? ?? 0) > n
                ? s['invoice_number'] as int
                : n) +
        1;
    setState(() {
      sales.insert(0, {
        ...paymentDetails,
        'invoice_number': invoiceNumber,
        'transaction_reference':
            'MPOS-${DateTime.now().microsecondsSinceEpoch}',
        'receipt_store': receiptSettings['shop'] ?? shop,
        'receipt_address': receiptSettings['receipt_address'] ?? '',
        'receipt_tin': receiptSettings['receipt_tin'] ?? '',
        'vat_status': receiptSettings['vat_status'] ?? 'Non-VAT',
        'vat_rate': double.tryParse(receiptSettings['vat_rate'] ?? '') ?? 12,
        'cashier': receiptSettings['cashier'] ?? 'Admin',
        'receipt_footer':
            receiptSettings['receipt_footer'] ?? 'Thank you for shopping!',
        'date': DateTime.now().toIso8601String(),
        'total': paidTotal,
        'cash_tendered': cashTendered,
        'change_due':
            ((cashTendered * 100).round() - (paidTotal * 100).round()) / 100,
        'count': count,
        'receipt_viewed': false,
        'items': products
            .where((p) => cart.containsKey(p.id))
            .map((p) => {
                  'product_id': p.id,
                  'category': p.category,
                  'name': p.name,
                  'quantity': cart[p.id],
                  'price': p.price
                })
            .toList()
      });
      for (final p in products) {
        p.stock -= cart[p.id] ?? 0;
      }
      cart.clear();
    });
    final saved = await save();
    if (!saved) {
      setState(() {
        sales.removeAt(0);
        for (final p in products) {
          p.stock += previousCart[p.id] ?? 0;
        }
        cart.addAll(previousCart);
      });
      return;
    }
    if (mounted) {
      final completedSale = sales.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          persist: false,
          duration: const Duration(seconds: 10),
          content:
              const LText('Sale completed. Inventory and reports updated.'),
          action: SnackBarAction(
              label: tr('Receipt'),
              onPressed: () => viewTransactionReceipt(completedSale))));
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, language, child) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) exitApp();
          },
          child: Scaffold(
              body: !ready
                  ? const Center(child: CircularProgressIndicator())
                  : !databaseAvailable
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                          LText(storageError ?? 'Database unavailable'),
                          TextButton(
                              onPressed: load, child: const LText('Retry')),
                        ]))
                      : SafeArea(
                          child: Column(children: [
                          Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(24, 24, 24, 22),
                              decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [coral, Color(0xFFFFAE8C)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.vertical(
                                      bottom: Radius.circular(30))),
                              child: Row(children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset('assets/mobilepos.png',
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.contain)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(shop,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold)),
                                      LText(
                                          [
                                            'Let’s serve something good',
                                            'Your business at a glance',
                                            'Manage your menu',
                                            'Every transaction, in one place',
                                            'Make it yours'
                                          ][page],
                                          style: const TextStyle(
                                              color: Colors.white))
                                    ])),
                              ])),
                          if (storageError != null)
                            MaterialBanner(
                                content: LText(storageError!),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          setState(() => storageError = null),
                                      child: const LText('Dismiss'))
                                ]),
                          Expanded(
                              child: IndexedStack(index: page, children: [
                            menu(),
                            revenuePage(),
                            productsPage(),
                            reports(),
                            settings()
                          ])),
                        ])),
              bottomNavigationBar: LayoutBuilder(
                  builder: (context, constraints) => NavigationBarTheme(
                      data: NavigationBarThemeData(
                          labelTextStyle: WidgetStateProperty.resolveWith(
                              (states) => TextStyle(
                                  fontSize: (constraints.maxWidth /
                                          40 /
                                          MediaQuery.textScalerOf(context)
                                              .scale(1))
                                      .clamp(8.0, 11.0),
                                  height: 1.2,
                                  letterSpacing: 0,
                                  color: states.contains(WidgetState.selected)
                                      ? const Color(0xFF241815)
                                      : const Color(0xFF8A7771),
                                  fontWeight:
                                      states.contains(WidgetState.selected)
                                          ? FontWeight.w700
                                          : FontWeight.w400)),
                          iconTheme: WidgetStateProperty.resolveWith(
                              (states) => IconThemeData(color: states.contains(WidgetState.selected) ? const Color(0xFF241815) : const Color(0xFF8A7771)))),
                      child: NavigationBar(selectedIndex: page, onDestinationSelected: (v) => setState(() => page = v), indicatorColor: const Color(0xFFFFE5DC), destinations: [
                        NavigationDestination(
                            icon: Icon(Icons.grid_view_rounded),
                            label: tr('Menu')),
                        NavigationDestination(
                            icon: Icon(Icons.account_balance_wallet_outlined),
                            label: tr('Revenue')),
                        NavigationDestination(
                            icon: Icon(Icons.add_box_outlined),
                            label: tr('Products')),
                        NavigationDestination(
                            icon: Badge.count(
                                key: const ValueKey('unread-receipt-badge'),
                                count: unreadReceiptCount,
                                isLabelVisible: unreadReceiptCount > 0,
                                child: const Icon(Icons.receipt_long_outlined)),
                            label: tr('Transactions')),
                        NavigationDestination(
                            icon: Icon(Icons.settings_outlined),
                            label: tr('Settings'))
                      ]))))));

  Widget menu() {
    if (posClosed) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.storefront_outlined, size: 48, color: coral),
                const SizedBox(height: 16),
                const LText('POS closed',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const LText(
                    'Sales resume on the next phone calendar day. Your products and sales history are saved.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                OutlinedButton(
                    onPressed: () => setState(() => page = 4),
                    child: const LText('Settings')),
              ])));
    }
    final bestSellers = monthlyBestSellers(
        products.map((p) => p.toJson()).toList(), sales, DateTime.now());
    final visible = products
        .where((p) =>
            (category == 'All Menu' || p.category == category) &&
            p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(
                child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                        hintText: tr('Search products'),
                        prefixIcon: Icon(Icons.search),
                        fillColor: Colors.white))),
            const SizedBox(width: 10),
            IconButton.filled(
                style: IconButton.styleFrom(
                    backgroundColor: coral,
                    minimumSize: const Size(28, 28),
                    padding: const EdgeInsets.all(4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => edit(),
                icon: const Icon(Icons.add, size: 18))
          ])),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final name in <String>{
              'All Menu',
              for (final p in products) p.category
            })
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: showCategoryIcons
                    ? Semantics(
                        selected: category == name,
                        button: true,
                        child: Tooltip(
                          message: tr('Hold to change category icon'),
                          child: InkWell(
                            key: ValueKey('category-icon-$name'),
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => category = name),
                            onLongPress: () => editCategoryEmblem(name),
                            child: SizedBox(
                                width: 90,
                                child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Column(children: [
                                      CircleAvatar(
                                          radius: 24,
                                          backgroundColor: category == name
                                              ? const Color(0xFFFFD8C8)
                                              : const Color(0xFFFFF0E6),
                                          child: ClipOval(
                                              child: CategoryEmblem(
                                                  value: categoryEmblems[
                                                          categoryKey(name)] ??
                                                      defaultCategoryEmblem(
                                                          name)))),
                                      const SizedBox(height: 6),
                                      name == 'All Menu'
                                          ? LText(name,
                                              maxLines: 2,
                                              textAlign: TextAlign.center)
                                          : Text(name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center),
                                    ]))),
                          ),
                        ))
                    : ChoiceChip(
                        label: name == 'All Menu' ? LText(name) : Text(name),
                        showCheckmark: false,
                        selected: category == name,
                        selectedColor: const Color(0xFFFFD8C8),
                        onSelected: (_) => setState(() => category = name),
                      ),
              ),
          ])),
      const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Align(
              alignment: Alignment.centerLeft,
              child: LText('Today’s Special Menu',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
      Expanded(
          child: visible.isEmpty
              ? const Center(
                  child:
                      LText('No products found. Add a product to get started.'))
              : LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          mainAxisExtent: constraints.maxWidth <= 600
                              ? math.max(
                                  150.0, (constraints.maxHeight - 12) / 2)
                              : null,
                          crossAxisCount: constraints.maxWidth > 900 ? 5 : 3,
                          childAspectRatio: .79,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 12),
                      itemCount: visible.length,
                      itemBuilder: (_, i) => productCard(visible[i],
                          bestSeller: bestSellers.contains(visible[i].id))))),
      if (count > 0)
        Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                    onTap: checkout,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                LText('$count items selected',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                const LText('Review order & collect payment',
                                    style: TextStyle(
                                        color: Colors.white60, fontSize: 12))
                              ])),
                          LText('₱${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20)),
                          const SizedBox(width: 12),
                          const CircleAvatar(
                              backgroundColor: coral,
                              child: Icon(Icons.shopping_bag_outlined,
                                  color: Colors.white))
                        ]))))),
    ]);
  }

  Widget productCard(Product p, {bool bestSeller = false}) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Stack(fit: StackFit.expand, children: [
          Container(
              color: const Color(0xFFF0EFED),
              width: double.infinity,
              child: photo(p)),
          if (bestSeller)
            Positioned(
                top: 6,
                left: 6,
                right: 6,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: coral, borderRadius: BorderRadius.circular(8)),
                    child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: LText('Best seller',
                            maxLines: 1,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold))),
                  ),
                )),
        ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: LText(p.stock == 0 ? 'Sold out' : '● ${p.stock} Remaining',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9,
                    height: 1.1,
                    color:
                        p.stock == 0 ? Colors.red : Colors.orange.shade800))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, height: 1.15, fontWeight: FontWeight.w600))),
        Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 6, 3),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LText('₱${p.price.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, height: 1.1, fontWeight: FontWeight.w600)),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if ((cart[p.id] ?? 0) > 0) ...[
                  quantityButton(Icons.remove, () => adjust(p, -1)),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: LText('${cart[p.id]}',
                          style: const TextStyle(fontSize: 12))),
                ],
                quantityButton(Icons.add,
                    p.stock > (cart[p.id] ?? 0) ? () => adjust(p, 1) : null)
              ])
            ]))
      ]));
  Widget quantityButton(IconData icon, VoidCallback? action) => SizedBox(
      width: 18,
      height: 20,
      child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: action,
          icon: Icon(icon, size: 11),
          style: IconButton.styleFrom(
              minimumSize: const Size(18, 18),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: action == null ? Colors.grey.shade200 : coral,
              foregroundColor: Colors.white)));
  Widget title(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: LText(text,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)));
  Widget metric(String label, String value, IconData icon) => Card(
      color: Colors.white,
      elevation: 0,
      child: ListTile(
          contentPadding: const EdgeInsets.all(18),
          leading: CircleAvatar(
              backgroundColor: const Color(0xFFFFE5DC),
              child: Icon(icon, color: coral)),
          title: LText(label),
          subtitle: LText(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252525)))));
  Widget revenuePage() {
    final filtered = sales.where((sale) {
      final date = DateTime.parse(sale['date']).toLocal();
      return date.year == reportDate.year &&
          (reportPeriod == 'Annual' || date.month == reportDate.month) &&
          (reportPeriod != 'Daily' || date.day == reportDate.day);
    }).toList();
    final sum =
        filtered.fold<double>(0, (v, sale) => v + (sale['total'] as num));
    final amounts = <String, double>{};
    for (final sale in filtered) {
      for (final item in sale['items']) {
        final name = item['name'] as String;
        amounts[name] = (amounts[name] ?? 0) +
            (item['price'] as num).toDouble() *
                (item['quantity'] as num).toDouble();
      }
    }
    final entries = amounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final names = <String>{
      for (final sale in sales)
        for (final item in sale['items']) item['name'] as String
    }.toList()
      ..sort();
    Color colorFor(String name) =>
        HSVColor.fromAHSV(1, (names.indexOf(name) * 137.508) % 360, .65, .85)
            .toColor();
    final dateLabel = reportPeriod == 'Annual'
        ? '${reportDate.year}'
        : reportPeriod == 'Monthly'
            ? '${reportDate.year}-${reportDate.month.toString().padLeft(2, '0')}'
            : '${reportDate.year}-${reportDate.month.toString().padLeft(2, '0')}-${reportDate.day.toString().padLeft(2, '0')}';
    final chartTotal = entries.fold<double>(0, (v, e) => v + e.value);
    return ListView(padding: const EdgeInsets.all(20), children: [
      title('Revenue report'),
      DropdownButtonFormField<String>(
        key: const ValueKey('report-period'),
        initialValue: reportPeriod,
        decoration: InputDecoration(labelText: tr('Report period')),
        items: ['Daily', 'Monthly', 'Annual']
            .map((p) => DropdownMenuItem(value: p, child: LText(p)))
            .toList(),
        onChanged: (value) => setState(() => reportPeriod = value!),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async {
          final date = await showDatePicker(
              context: context,
              initialDate: reportDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(DateTime.now().year + 1, 12, 31));
          if (date != null && mounted) setState(() => reportDate = date);
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: LText(dateLabel),
      ),
      const SizedBox(height: 12),
      metric('$reportPeriod revenue', '\u20b1${sum.toStringAsFixed(2)}',
          Icons.account_balance_wallet_outlined),
      metric('Completed sales', '${filtered.length}', Icons.receipt_long),
      metric(
          'Average sale',
          '\u20b1${(filtered.isEmpty ? 0 : sum / filtered.length).toStringAsFixed(2)}',
          Icons.trending_up),
      const SizedBox(height: 16),
      Card(
          color: Colors.white,
          elevation: 0,
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LText('Product revenue share',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const LText(
                        'Each slice shows a product share of revenue for this period.'),
                    const SizedBox(height: 20),
                    if (entries.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                              child:
                                  LText('No product revenue for this period.')))
                    else ...[
                      Center(
                          child: Semantics(
                              label:
                                  'Product revenue wheel chart. Amounts and percentages are listed below.',
                              child: SizedBox(
                                  width: 220,
                                  height: 220,
                                  child: CustomPaint(
                                      painter: RevenueWheelPainter(
                                          entries.map((e) => e.value).toList(),
                                          entries
                                              .map((e) => colorFor(e.key))
                                              .toList()),
                                      child: Center(
                                          child: SizedBox(
                                              width: 112,
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const LText('Revenue',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.grey)),
                                                    const SizedBox(height: 4),
                                                    FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                            '₱${chartTotal.toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                                fontSize: 22,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold))),
                                                  ]))))))),
                      const SizedBox(height: 20),
                      for (final entry in entries)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                      color: colorFor(entry.key),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(entry.key)),
                              const SizedBox(width: 8),
                              LText(
                                  '\u20b1${entry.value.toStringAsFixed(2)} / ${(entry.value / chartTotal * 100).toStringAsFixed(1)}%'),
                            ])),
                    ],
                  ]))),
    ]);
  }

  Widget productsPage() =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Expanded(child: title('Your products')),
          FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const LText('Add'))
        ]),
        if (products.isEmpty)
          const LText('Your menu is empty. Add your first product.'),
        for (final p in products)
          Card(
              color: Colors.white,
              elevation: 0,
              child: ListTile(
                  leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: photo(p, size: 30))),
                  title: Text(p.name),
                  subtitle: LText(
                      '₱${p.price.toStringAsFixed(2)} · ${p.stock} in stock · ${p.category}'),
                  onTap: () => edit(p),
                  trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          edit(p);
                        } else {
                          final yes = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                      title: LText('Delete ${p.name}?'),
                                      content: const LText(
                                          'This removes the product from your menu and cart. Past sales are kept.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const LText('Cancel')),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const LText('Delete'))
                                      ]));
                          if (yes == true) {
                            setState(() {
                              products.remove(p);
                              cart.remove(p.id);
                            });
                            save();
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: LText('Edit product')),
                            PopupMenuItem(
                                value: 'delete', child: LText('Delete product'))
                          ])))
      ]);
  Future<void> markTransactionViewed(Map<String, dynamic> sale) async {
    if (!mounted || sale['receipt_viewed'] == true) return;
    setState(() => sale['receipt_viewed'] = true);
    if (!await save() && mounted) {
      setState(() => sale['receipt_viewed'] = false);
    }
  }

  Future<void> viewTransactionReceipt(Map<String, dynamic> sale) async {
    await showReceipt(context, sale, shop,
        onViewed: () => markTransactionViewed(sale));
  }

  Future<void> markAllTransactionsViewed() async {
    final unread = todayTransactions
        .where((sale) => sale['receipt_viewed'] != true)
        .toList();
    if (unread.isEmpty) return;
    setState(() {
      for (final sale in unread) {
        sale['receipt_viewed'] = true;
      }
    });
    if (!await save() && mounted) {
      setState(() {
        for (final sale in unread) {
          sale['receipt_viewed'] = false;
        }
      });
    }
  }

  Widget reports() => ListView(padding: const EdgeInsets.all(20), children: [
        title('Transactions'),
        if (unreadReceiptCount > 0)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                        label: LText('$unreadReceiptCount unviewed receipts'),
                        backgroundColor: const Color(0xFFFFE5DC)),
                    TextButton(
                        onPressed: markAllTransactionsViewed,
                        child: const LText('Mark all as viewed',
                            style: TextStyle(fontSize: 12))),
                  ])),
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LText("Today's transactions")),
        TextButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('All sales / reprint history'),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SalesHistoryPage(
                        sales: sales,
                        shop: shop,
                        recordAdjustment: (sale, entry) async {
                          final previous = sale['adjustments'];
                          sale['adjustments'] = [
                            ...(previous as List? ?? []),
                            entry
                          ];
                          final saved = await save();
                          if (!saved) {
                            sale['adjustments'] = previous;
                          }
                          if (mounted) setState(() {});
                          return saved;
                        })))),
        metric('Total transactions', '${todayTransactions.length}',
            Icons.receipt_long_outlined),
        if (todayTransactions.isEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                  child: LText(
                      'No transactions yet. Complete an order to see it here.'))),
        for (final s in todayTransactions)
          Card(
              key: ValueKey('transaction-${s['date']}'),
              color: s['receipt_viewed'] == true
                  ? Colors.white
                  : const Color(0xFFFFEFE6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: s['receipt_viewed'] == true
                          ? Colors.transparent
                          : coral)),
              elevation: 0,
              child: ExpansionTile(
                  title: LText(
                      '₱${(s['total'] as num).toStringAsFixed(2)} · ${s['count']} items'),
                  subtitle: LText(DateTime.parse(s['date'])
                      .toLocal()
                      .toString()
                      .substring(0, 16)),
                  children: [
                    TextButton.icon(
                        onPressed: () => viewTransactionReceipt(s),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const LText('View / print receipt')),
                    for (final item in s['items'])
                      ListTile(
                          title: Text(item['name']),
                          subtitle: LText(
                              '${item['quantity']} × ₱${(item['price'] as num).toStringAsFixed(2)}'),
                          trailing: LText(
                              '₱${((item['quantity'] as num) * (item['price'] as num)).toStringAsFixed(2)}'))
                  ]))
      ]);
  bool exitFlowActive = false;
  Future<void> exitApp() async {
    if (exitFlowActive || !databaseAvailable) return;
    exitFlowActive = true;
    try {
      if (!await save() || !mounted) return;
      final now = DateTime.now();
      final confirmed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ExitSummaryPage(
                date: now,
                summary: buildExitSummary(shop, sales,
                    products.map((p) => p.toJson()).toList(), now)),
          ));
      if (confirmed != true || !mounted) return;
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: LText(
                'Close this window or use your device controls to exit.')));
        return;
      }
      if (!await save() || !mounted) return;
      await SystemNavigator.pop();
    } finally {
      exitFlowActive = false;
    }
  }

  Future<void> setCategoryIcons(bool enabled) async {
    if (categoryStyleSaving) return;
    setState(() => categoryStyleSaving = true);
    try {
      await PosDatabase.instance
          .updateSettings({'show_category_icons': enabled ? '1' : '0'});
      if (mounted) setState(() => showCategoryIcons = enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: LText('Could not save category settings. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => categoryStyleSaving = false);
    }
  }

  Future<void> editCategoryEmblem(String name) async {
    final key = categoryKey(name);
    final value = await chooseCategoryEmblem(
        context, categoryEmblems[key] ?? defaultCategoryEmblem(name));
    if (value == null || !mounted) return;
    final updated = {...categoryEmblems, key: value};
    try {
      await PosDatabase.instance
          .updateSettings({'category_emblems': jsonEncode(updated)});
      if (mounted) setState(() => categoryEmblems = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: LText('Could not save category settings. Please retry.')));
      }
    }
  }

  bool clearingData = false;
  Future<void> clearData() async {
    if (clearingData) return;
    clearingData = true;
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                title: const LText('Clear all data?'),
                content: const LText(
                    'This permanently deletes products, photos, stock, transactions, sales reports and store, receipt and printer settings on this device. Your language choice is kept. This cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const LText('Cancel')),
                  FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(c, true),
                      child: const LText('Clear all data')),
                ],
              ));
      if (confirmed != true || !mounted) return;
      setState(() => ready = false);
      await PosDatabase.instance.clearAllData();
      if (!mounted) return;
      setState(() {
        products.clear();
        sales.clear();
        cart.clear();
        shop = 'MPOS';
        showCategoryIcons = false;
        categoryEmblems.clear();
        closedDay = null;
        category = 'All Menu';
        query = '';
        reportPeriod = 'Daily';
        reportDate = DateTime.now();
        currentDay = businessDayKey(DateTime.now());
        storageError = null;
        ready = true;
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: LText('All data cleared.')));
    } catch (_) {
      if (mounted) {
        setState(() => ready = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: LText('Could not clear data. Please retry.')));
      }
    } finally {
      clearingData = false;
    }
  }

  Widget settings() => ListView(padding: const EdgeInsets.all(20), children: [
        title('Settings'),
        Card(
            color: Colors.white,
            elevation: 0,
            child: SwitchListTile(
              key: const ValueKey('show-category-icons'),
              title: const LText('Show category icons'),
              subtitle: const LText(
                  'Show icons above category names. Hold a category to choose an emblem or logo.'),
              value: showCategoryIcons,
              onChanged: categoryStyleSaving ? null : setCategoryIcons,
            )),
        Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: Icon(
                  posClosed ? Icons.lock_outline : Icons.storefront_outlined,
                  color: coral),
              title: LText(posClosed ? 'Reopen POS' : 'Close POS'),
              subtitle:
                  LText(posClosed ? 'Closed for today' : 'End the store day'),
              trailing: closing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: closing ? null : togglePos,
            )),
        Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined, color: coral),
              title: const LText('Receipt information'),
              subtitle: Text(shop),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final name = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReceiptInformationPage(shop: shop)));
                if (name != null && mounted) setState(() => shop = name);
              },
            )),
        Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.print_outlined, color: coral),
              title: const LText('Printer settings'),
              subtitle: const LText('Bluetooth, USB or Wi-Fi thermal printer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrinterSettingsPage())),
            )),
        Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.language, color: coral),
              title: const LText('Language'),
              subtitle: Text(appLanguage.value == 'tl' ? 'Tagalog' : 'English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final selected = await showDialog<String>(
                    context: context,
                    builder: (c) => SimpleDialog(
                          title: const LText('Choose language'),
                          children: [
                            for (final entry
                                in {'en': 'English', 'tl': 'Tagalog'}.entries)
                              SimpleDialogOption(
                                  onPressed: () => Navigator.pop(c, entry.key),
                                  child: Row(children: [
                                    Expanded(child: Text(entry.value)),
                                    if (appLanguage.value == entry.key)
                                      const Icon(Icons.check, color: coral),
                                  ])),
                          ],
                        ));
                if (selected == null) return;
                try {
                  await PosDatabase.instance
                      .updateSettings({'language': selected});
                  appLanguage.value = selected;
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            LText('Unable to save language. Please retry.')));
                  }
                }
              },
            )),
        Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.exit_to_app, color: coral),
              title: const LText('Exit app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: exitApp,
            )),
        Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading:
                  const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const LText('Clear data',
                  style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.chevron_right),
              onTap: clearData,
            )),
        Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
                leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/mobilepos.png',
                        width: 40, height: 40, fit: BoxFit.contain)),
                title: const LText('MPOS'),
                subtitle: const LText('Version 1.0.0'))),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('mobile pos2026',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey))),
      ]);
}

class RevenueWheelPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  RevenueWheelPainter(this.values, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final outerRadius = math.min(size.width, size.height) / 2 - 2;
    final thickness = outerRadius * .34;
    final radius = outerRadius - thickness / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness);
      start += sweep;
    }
    if (values.length > 1) {
      start = -math.pi / 2;
      for (final value in values) {
        final direction = Offset(math.cos(start), math.sin(start));
        canvas.drawLine(
            center + direction * (outerRadius - thickness),
            center + direction * outerRadius,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 2);
        start += value / total * math.pi * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant RevenueWheelPainter oldDelegate) =>
      !listEquals(values, oldDelegate.values) ||
      !listEquals(colors, oldDelegate.colors);
}
