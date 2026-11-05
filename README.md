# MPOS

Flutter point of sale inspired by the supplied coral mobile design.

## Run

```sh
flutter pub get
flutter run -d chrome --web-port 8080
```

For Android, connect a device/emulator and use `flutter run`. iOS requires macOS and Xcode.

## Features

- Search and category filters, responsive product grid, stock-aware cart.
- Add/edit/delete products, prices, quantities, and photos from your device.
- Review orders and record received payments; stock updates automatically.
- Daily, monthly and annual revenue reports, product pie chart and itemized sales history.
- Store name setting and local persistence for products, photos, and sales.

Products show text placeholders until a photo is uploaded. Prices use Philippine pesos. This app records payments collected separately; it does not process card payments. Storage is local to one device/browser, with no cloud synchronization. Browser site-data clearing or app removal can erase records. Back up business records separately before production use.

## Verify

```sh
flutter analyze
flutter test
flutter build web
```

## SQLite storage

Products, photos, sales, sale items and settings are stored in `coral_pos.db`. Tables are created automatically, and existing SharedPreferences data is imported once, leaving the original preferences intact. Inventory and sales commit together in a transaction. SharedPreferences remains only for legacy migration.

Android/iOS use sqflite; Windows uses sqflite_common_ffi. Web uses sqflite_common_ffi_web and the included web/sqlite3.wasm and web/sqflite_sw.js assets. Browser data belongs to the site origin, so keep the same development port. After updating SQLite web packages, regenerate binaries using `dart run sqflite_common_ffi_web:setup --force`.

Receipt information is configured in Settings: store name, address, and closing greeting. Transactions retain their original phone time and offer View / print receipt. Printer settings support paired Bluetooth Classic on Android, Bluetooth BLE, USB OTG and Wi-Fi ESC/POS printers on 58 mm or 80 mm paper. Pair Classic printers in phone settings first. Wi-Fi uses the printer IP and port (normally 9100). Use Test print to verify compatibility; physical printer output requires testing on your printer. Printing is available in the installed app, not the web build. Receipts use PHP in printer text mode; non-ASCII characters currently print as question marks.

## Language

Settings > Language switches between English and Tagalog and saves the choice in SQLite. Product names, categories, store details and custom greetings stay as entered. The display name is MPOS, version 1.0.0. Existing package identifiers and database filenames are retained to preserve installed user data.

## Closing the store day

Use Settings > Close POS at the end of store hours. This blocks checkout and saves the closed status. Reopen POS allows more sales on the same day. On the next local calendar day according to the phone, the POS opens again automatically and Transactions shows only that day's records. Products, stock, revenue and historical transactions remain in SQLite; revenue reports can still include previous dates. Closing does not delete sales or reset inventory. Overnight store-hour schedules are not configured by this manual closing function.

## Monthly best sellers

Product cards show a Best seller badge for the current month's unit-sales leader in each category. Ties share the badge, and categories without sales have no badge. Rankings reset on the next local calendar month while sales history remains intact. New sale items retain product IDs and category snapshots; legacy items use unique product names when possible.

## Receipt review status

Today's unviewed receipts highlight their transaction cards and appear in a count on the Transactions tab and page. Opening the receipt from its transaction or the sale notification marks it viewed and saves the status in SQLite. Expanding a transaction alone does not mark it viewed. Older receipts default to unviewed because no prior view history was tracked.

## Exit summary

Settings > Exit app and the Android back action open a daily summary before closing. It lists today's transaction count, units sold and revenue, plus current inventory totals and each product's remaining quantity. Print report uses the configured thermal printer; Download report opens a Save As dialog for a UTF-8 .txt file. The app stays open until Exit app is selected, and Cancel returns to the POS.

Product forms use the available phone width above the keyboard. Category entry suggests up to five matching existing names after two characters, including multiword matches. Selecting a suggestion reuses its spelling; capitalization and extra-space variants are normalized when saving.

## Sales invoices and receipt history

Settings > Receipt information configures the business name, address, TIN, VAT status, inclusive VAT rate and cashier name/ID. New sales retain a snapshot of these details for later reprinting. Invoice numbers increment within this device's saved history; older transactions remain labelled Legacy / unnumbered. Clearing all app data resets the history and numbering.

Review sale uses the original cash checkout: item list, total, cash tendered and change. The expanded payment, discount and customer fields are no longer shown. Historical receipts retain previously recorded payment and discount details. The VAT breakdown is a simple inclusive calculation on the saved total.

Receipts include item quantities, unit prices, subtotals, discounts, taxes, grand total, amount received, change and transaction reference. View a receipt to print on the existing 58 mm/80 mm ESC/POS path, save/share a PDF or copy its text for a customer message. Transactions > All sales / reprint history searches all saved dates. Refund/void entries are audit records only: they retain the original sale and record the full amount, time and reason, without moving money, changing stock or adjusting sales reports. Invoices carry an illustrative/non-authorized notice.

## App logo

The logo source is assets/mobilepos.png. It is bundled in the app and used in the header and MPOS information card. Launcher icons for Android (including adaptive icons), iOS, Windows and web are generated with dart run flutter_launcher_icons. Rebuild the native app after updating icons.

## Clear data

Settings > Clear data asks for explicit confirmation before deleting products, photos, stock, transactions, reports and store/receipt/printer configuration on this device. The selected language stays. Resetting clears the legacy preferences and keeps the migration marker, so old sample or migrated records do not return on restart. This action does not delete reports previously exported to other folders. Implementation tests use temporary databases only.

Fresh installations start with an empty product catalog and MPOS as the default store name. No demo products are seeded. Clearing data also leaves the catalog empty after restart. Existing saved products are retained until the owner deletes or clears them.

## Category display

Settings > Show category icons toggles between the existing word buttons (default) and circular icons above category names. With icons enabled, press and hold a category to select an emblem, enter a short symbol, or choose a logo photo. Choices and the switch are saved in SQLite. Turning icons off preserves the choices; Clear data removes them.
