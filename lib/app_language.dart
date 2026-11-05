import 'package:flutter/material.dart';

/// Persisted separately from user-entered product and receipt information.
final appLanguage = ValueNotifier<String>('en');
String tr(String text) {
  if (appLanguage.value != 'tl') return text;
  final exact = _tagalog[text];
  if (exact != null) return exact;
  for (final prefix in <String, String>{
    'Printer error: ': 'Error sa printer: ',
    'Bad state: ': '',
    'Could not open receipt: ': 'Hindi mabuksan ang resibo: ',
    'Could not load receipt information: ':
        'Hindi ma-load ang impormasyon ng resibo: ',
    'Could not save receipt information: ':
        'Hindi ma-save ang impormasyon ng resibo: ',
    'Could not load printer settings: ':
        'Hindi ma-load ang mga setting ng printer: ',
    'Discovery failed: ': 'Hindi mahanap ang mga printer: ',
  }.entries) {
    if (text.startsWith(prefix.key)) {
      return prefix.value + tr(text.substring(prefix.key.length));
    }
  }
  final selected = RegExp(r'^(\d+) items selected$').firstMatch(text);
  if (selected != null) return '${selected[1]} napiling produkto';
  final stock = RegExp(r'^● (\d+) Remaining$').firstMatch(text);
  if (stock != null) return '● ${stock[1]} natitira';
  final unread = RegExp(r'^(\d+) unviewed receipts$').firstMatch(text);
  if (unread != null) return '${unread[1]} hindi pa natingnang resibo';
  final items = RegExp(r'^(₱[\d.]+) · (\d+) items$').firstMatch(text);
  if (items != null) return '${items[1]} · ${items[2]} produkto';
  final inventory =
      RegExp(r'^(₱[\d.]+) · (\d+) in stock · (.+)$').firstMatch(text);
  if (inventory != null) {
    return '${inventory[1]} · ${inventory[2]} stock · ${inventory[3]}';
  }
  if (text.startsWith('Selected: ')) return 'Napili: ${text.substring(10)}';
  if (text.startsWith('Delete ') && text.endsWith('?')) {
    return 'Burahin ang ${text.substring(7)}';
  }
  return text;
}

class LText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  const LText(this.data,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: appLanguage,
        builder: (_, language, child) => Text(tr(data),
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow),
      );
}

const _tagalog = <String, String>{
  'Browse emojis': 'Pumili ng emoji',
  'Choose an emoji': 'Pumili ng emoji',
  'Tap Browse emojis if your keyboard has no emoji key.':
      'Pindutin ang Pumili ng emoji kung walang emoji key ang keyboard.',
  'Keyboard emoji / custom emblem': 'Emoji sa keyboard / sariling sagisag',
  'Use your keyboard emoji key to choose any emoji, then tap Save.':
      'Gamitin ang emoji key ng keyboard upang pumili ng emoji, pagkatapos pindutin ang I-save.',
  'Choose category icon': 'Pumili ng icon ng kategorya',
  'Change category icon': 'Palitan ang icon ng kategorya',
  'Show category icons': 'Ipakita ang mga icon ng kategorya',
  'Show icons above category names. Hold a category to choose an emblem or logo.':
      'Ipakita ang mga icon sa ibabaw ng pangalan. Pindutin nang matagal ang kategorya upang pumili ng sagisag o logo.',
  'Hold to change category icon': 'Pindutin nang matagal para palitan ang icon',
  'Category icon': 'Icon ng kategorya',
  'Custom emblem': 'Sariling sagisag',
  'Choose category logo': 'Pumili ng logo ng kategorya',
  'Could not save category settings. Please retry.':
      'Hindi ma-save ang mga setting ng kategorya. Subukan muli.',
  'Clear data': 'Burahin ang datos',
  'Clear all data?': 'Burahin ang lahat ng datos?',
  'Clear all data': 'Burahin ang lahat ng datos',
  'All data cleared.': 'Nabura na ang lahat ng datos.',
  'Could not clear data. Please retry.':
      'Hindi mabura ang datos. Subukan muli.',
  'This permanently deletes products, photos, stock, transactions, sales reports and store, receipt and printer settings on this device. Your language choice is kept. This cannot be undone.':
      'Permanenteng mabubura ang mga produkto, larawan, stock, transaksiyon, ulat ng benta at mga setting ng tindahan, resibo at printer sa device na ito. Mananatili ang napiling wika. Hindi na ito maibabalik.',
  'Use category': 'Gamitin ang kategorya',
  'Use an ESC/POS receipt printer. Label and pocket printers may need a separate driver.':
      'Gumamit ng ESC/POS receipt printer. Maaaring kailangan ng hiwalay na driver ang label at pocket printer.',
  'Mark all as viewed': 'Markahang natingnan lahat',
  'Before you exit': 'Bago lumabas',
  'Daily summary': 'Buod ng araw',
  'Units sold': 'Dami ng naibenta',
  'Current stock': 'Kasalukuyang stock',
  'Stock units': 'Kabuuang dami ng stock',
  'Out of stock': 'Ubos na stock',
  'Print report': 'I-print ang ulat',
  'Download report': 'I-download ang ulat',
  'Print or download your daily summary before exiting.':
      'I-print o i-download ang buod ng araw bago lumabas.',
  'Download cancelled.': 'Kinansela ang pag-download.',
  'Report saved.': 'Na-save ang ulat.',
  'Could not save report. Please retry.':
      'Hindi ma-save ang ulat. Subukan muli.',
  'Mark as viewed': 'Markahan bilang natingnan',
  'Best seller': 'Pinakamabenta',
  'Exit app': 'Lumabas sa app',
  'Exit app?': 'Lumabas sa app?',
  'Completed sales and products stay saved. Unpaid cart items will be cleared. Exiting does not close the store day.':
      'Mananatiling naka-save ang mga produkto at natapos na benta. Aalisin ang mga hindi pa bayad na item sa cart. Hindi nito isasara ang araw ng tindahan.',
  'Close this window or use your device controls to exit.':
      'Isara ang window na ito o gamitin ang mga kontrol ng device upang lumabas.',
  'A new day has started. Please review your order again.':
      'Nagsimula na ang bagong araw. Suriin muli ang iyong order.',
  'Close POS': 'Isara ang POS',
  'Reopen POS': 'Buksan muli ang POS',
  'Close POS for today?': 'Isara ang POS para sa araw na ito?',
  'Reopen POS?': 'Buksan muli ang POS?',
  'Closed for today': 'Sarado para sa araw na ito',
  'End the store day': 'Tapusin ang araw ng tindahan',
  'POS closed': 'Sarado ang POS',
  "Today's transactions": 'Mga transaksiyon ngayong araw',
  'Resume sales for today.': 'Ipagpatuloy ang pagbebenta ngayong araw.',
  'Unpaid cart items will be cleared. Products, stock and sales history are kept. The POS reopens automatically on the next phone calendar day.':
      'Aalisin ang mga hindi pa bayad na item sa cart. Mananatili ang mga produkto, stock at kasaysayan ng benta. Awtomatikong bubukas ang POS sa susunod na araw ayon sa telepono.',
  'Sales resume on the next phone calendar day. Your products and sales history are saved.':
      'Magpapatuloy ang pagbebenta sa susunod na araw ayon sa telepono. Naka-save ang mga produkto at kasaysayan ng benta.',
  'Could not update POS status. Please retry.':
      'Hindi ma-update ang katayuan ng POS. Subukan muli.',
  'TOTAL': 'KABUUAN',
  'CASH TENDERED': 'HALAGANG IBINAYAD',
  'CHANGE': 'SUKLI',
  'Thank you for shopping with us!': 'Salamat sa inyong pamimili!',
  'Unable to save language. Please retry.':
      'Hindi ma-save ang wika. Subukan muli.',
  'Turn on Bluetooth in phone settings.':
      'Buksan ang Bluetooth sa mga setting ng telepono.',
  'Choose a printer first.': 'Pumili muna ng printer.',
  'Could not connect to the paired printer.':
      'Hindi makakonekta sa naka-pair na printer.',
  'Could not connect to the selected printer.':
      'Hindi makakonekta sa napiling printer.',
  'Receipt could not be sent.': 'Hindi maipadala ang resibo.',
  'Enter a printer IP address and valid port.':
      'Ilagay ang IP address ng printer at wastong port.',
  'Cannot reach printer. Check the IP, port and Wi-Fi network.':
      'Hindi maabot ang printer. Suriin ang IP, port at Wi-Fi network.',
  'Allow Nearby devices / Bluetooth permissions in phone settings.':
      'Payagan ang Nearby devices / Bluetooth sa mga setting ng telepono.',
  'Menu': 'Menu',
  'All Menu': 'Lahat',
  'Revenue': 'Kita',
  'Products': 'Produkto',
  'Transactions': 'Transaksiyon',
  'Settings': 'Mga Setting',
  'Language': 'Wika',
  'English': 'English',
  'Tagalog': 'Tagalog',
  'Choose language': 'Pumili ng wika',
  'Version 1.0.0': 'Bersiyon 1.0.0',
  'Let’s serve something good': 'Handa nang magbenta',
  'Ready for your next sale': 'Handa sa susunod na benta',
  'Your business at a glance': 'Pangkalahatang ulat ng negosyo',
  'Manage your menu': 'Pamahalaan ang mga produkto',
  'Every transaction, in one place': 'Lahat ng transaksiyon sa isang lugar',
  'Make it yours': 'Iangkop sa iyong negosyo',
  'Today’s Special Menu': 'Mga Produkto',
  'Product catalog': 'Mga Produkto',
  'Search products': 'Maghanap ng produkto',
  'Add': 'Idagdag',
  'Add a product': 'Magdagdag ng produkto',
  'Edit product': 'I-edit ang produkto',
  'Delete product': 'Burahin ang produkto',
  'Delete': 'Burahin',
  'Product name': 'Pangalan ng produkto',
  'Price (₱)': 'Presyo (₱)',
  'Stock quantity': 'Dami ng stock',
  'Category': 'Kategorya',
  'e.g. Clothing': 'hal. Damit',
  'Save product': 'I-save ang produkto',
  'Remove photo': 'Alisin ang larawan',
  'Cancel': 'Kanselahin',
  'Save': 'I-save',
  'Enter a name': 'Maglagay ng pangalan',
  'Enter a valid price': 'Maglagay ng wastong presyo',
  'Invalid stock quantity': 'Hindi wastong dami ng stock',
  'Enter a category': 'Maglagay ng kategorya',
  'Choose another name': 'Pumili ng ibang pangalan',
  'Sold out': 'Ubos na',
  'Your products': 'Iyong mga produkto',
  'No products found. Add a product to get started.':
      'Walang nakitang produkto. Magdagdag ng produkto upang magsimula.',
  'Your menu is empty. Add your first product.':
      'Wala pang produkto. Idagdag ang iyong unang produkto.',
  'This removes the product from your menu and cart. Past sales are kept.':
      'Aalisin ang produkto sa listahan at cart. Mananatili ang mga dating benta.',
  'Review order & collect payment': 'Suriin ang order at tanggapin ang bayad',
  'Review sale': 'Suriin ang benta',
  'Total': 'Kabuuan',
  'Cash tendered': 'Halagang ibinayad',
  'Change': 'Sukli',
  'Back': 'Bumalik',
  'Payment received': 'Natanggap ang bayad',
  'Enter a valid amount (up to 2 decimals)':
      'Maglagay ng wastong halaga (hanggang 2 desimal)',
  'Cash must cover the total': 'Kulang ang ibinayad sa kabuuang halaga',
  'Sale completed. Inventory and reports updated.':
      'Tapos na ang benta. Na-update ang stock at mga ulat.',
  'Receipt': 'Resibo',
  'Retry': 'Subukan muli',
  'Dismiss': 'Isara',
  'Database unavailable': 'Hindi magamit ang database',
  'Unable to save to SQLite. Please check available storage and retry.':
      'Hindi na-save ang datos. Suriin ang espasyo ng device at subukan muli.',
  'Photo could not be opened. Check photo permissions.':
      'Hindi mabuksan ang larawan. Suriin ang pahintulot sa mga larawan.',
  'Revenue report': 'Ulat ng kita',
  'Report period': 'Panahon ng ulat',
  'Daily': 'Arawan',
  'Monthly': 'Buwanan',
  'Annual': 'Taunan',
  'Daily revenue': 'Kita sa araw',
  'Monthly revenue': 'Kita sa buwan',
  'Annual revenue': 'Kita sa taon',
  'Completed sales': 'Natapos na benta',
  'Average sale': 'Karaniwang halaga ng benta',
  'Product revenue share': 'Bahagi ng kita bawat produkto',
  'Each slice shows a product share of revenue for this period.':
      'Ipinapakita ng bawat bahagi ang kita ng produkto sa napiling panahon.',
  'No product revenue for this period.':
      'Walang kita mula sa produkto sa panahong ito.',
  'Total transactions': 'Kabuuang transaksiyon',
  'No transactions yet. Complete an order to see it here.':
      'Wala pang transaksiyon. Tapusin ang isang order upang makita rito.',
  'View / print receipt': 'Tingnan / i-print ang resibo',
  'Receipt information': 'Impormasyon ng resibo',
  'Name of store': 'Pangalan ng tindahan',
  'Store address': 'Address ng tindahan',
  'Closing remarks / greetings': 'Pangwakas na mensahe / pagbati',
  'Enter your store name': 'Ilagay ang pangalan ng tindahan',
  'Save receipt information': 'I-save ang impormasyon ng resibo',
  'Saving...': 'Sine-save...',
  'Printer settings': 'Mga setting ng printer',
  'Bluetooth, USB or Wi-Fi thermal printer':
      'Thermal printer sa Bluetooth, USB o Wi-Fi',
  'Connection': 'Koneksiyon',
  'Paper width': 'Lapad ng papel',
  'Printer IP address': 'IP address ng printer',
  'Port': 'Port',
  'Search printers': 'Maghanap ng printer',
  'Searching...': 'Naghahanap...',
  'Save printer settings': 'I-save ang mga setting ng printer',
  'Test print': 'Subukang mag-print',
  'Print receipt': 'I-print ang resibo',
  'Printer settings saved.': 'Na-save ang mga setting ng printer.',
  'Searching for printers...': 'Naghahanap ng mga printer...',
  'Choose a printer below.': 'Pumili ng printer sa ibaba.',
  'No printers found. Check power, Bluetooth or USB OTG connection.':
      'Walang nakitang printer. Suriin ang power, Bluetooth o USB OTG.',
  'Choose a paired printer below.': 'Pumili ng naka-pair na printer sa ibaba.',
  'Pair your printer in phone Bluetooth settings first, then search again.':
      'I-pair muna ang printer sa Bluetooth settings ng telepono, pagkatapos maghanap muli.',
  'Pair your portable printer in phone Bluetooth settings, then search.':
      'I-pair ang portable printer sa Bluetooth settings ng telepono, pagkatapos maghanap.',
  'Turn on a compatible Bluetooth Low Energy (BLE) ESC/POS printer, then search. Use Bluetooth mode for paired Classic printers.':
      'Buksan ang katugmang BLE ESC/POS printer at maghanap. Gamitin ang Bluetooth para sa naka-pair na Classic printer.',
  'Connect an ESC/POS USB printer using a USB OTG cable and allow USB access.':
      'Ikonekta ang ESC/POS USB printer gamit ang USB OTG at payagan ang USB access.',
  'Connect your phone and ESC/POS printer to the same Wi-Fi network.':
      'Ikonekta ang telepono at ESC/POS printer sa iisang Wi-Fi network.',
  'Print data sent. Check the printer for your receipt.':
      'Naipadala ang datos. Tingnan ang resibo sa printer.',
};
