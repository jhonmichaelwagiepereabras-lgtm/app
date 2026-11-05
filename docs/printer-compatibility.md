# MPOS printer compatibility

Status: documentation review plus automated ESC/POS output tests. None of these models has been physically certified with MPOS. A successful Bluetooth connection or successful byte write does not confirm that a printer understood the receipt.

MPOS currently sends basic ESC/POS text receipts over Android paired Bluetooth Classic, BLE, USB, or raw Wi-Fi TCP (usually port 9100). It supports 58 mm / 80 mm continuous receipt rolls, ASCII text, wrapping, centered headers, totals, cash tendered, change and paper feed. It does not implement TSPL/ZPL labels, AirPrint, StarPRNT-native or proprietary pocket-printer commands. Custom non-ASCII text is currently replaced with question marks; peso values use PHP.

| Requested printer | Assessment for current MPOS |
| --- | --- |
| Epson Mobilink TM-P20II / TM-P80II | ESC/POS command support is documented. Candidates for receipt testing with the correct interface variant, Bluetooth mode and paper width. Not hardware verified. |
| Star SM-S220i / SM-T300i | Candidates ONLY in ESC/POS emulation mode. StarPRNT mode uses a different protocol. Not hardware verified. |
| Bixolon SPP-R200III | Candidate for basic receipt commands based on its command manual. Verify exact model, interface, emulation and paper settings. Not hardware verified. |
| Rollo Wireless / unspecified Bluetooth Rollo | Not implemented by this ESC/POS driver. Rollo X1040 documentation describes a shipping-label/AirPrint path. An exact model and a separate driver or OS print integration are needed. |
| Phomemo M220 / M110 | Not implemented. Manufacturer directs these label printers to Print Master. Do not assume they accept ESC/POS receipts. |
| MUNBYN 4x6 Bluetooth | Model is unspecified, so compatibility cannot be certified. Example RW402B/RW403B manuals list ZPL/TSPL rather than ESC/POS. Requires model-specific label support. |
| Phomemo T02 / M02 Pro | Not implemented. Manufacturer documents its own pocket-printer app workflow; raw ESC/POS support has not been established. |
| PeriPage A6 | Not implemented. Manufacturer documents PeriPage/PeriMonkey app printing; raw ESC/POS support has not been established. |

## Physical test procedure

1. Print the printer's self-test/configuration page. Confirm model, firmware, command mode, paper width and connection type. Enable ESC/POS emulation where available.
2. On Android pair Classic printers in phone settings, then choose Bluetooth in MPOS. BLE devices use Bluetooth BLE. USB needs OTG and USB approval. Wi-Fi needs the correct IP/port and the same local network.
3. Select 58 mm or 80 mm and run Settings > Printer settings > Test print. The new sample includes item lines, long-text wrapping, total PHP 125.50, cash PHP 200.00, change PHP 74.50 and paper feed; it deliberately avoids an automatic cut command.
4. Inspect the physical output. Record pass/fail for legibility, alignment, wrapping, amounts and feed. Repeat with a real sale receipt and a long stock summary.
5. Verify reconnect after printer power-off and phone restart. Test each actual connection variant separately; a Wi-Fi pass does not certify Bluetooth or USB.

## Manufacturer references

- Epson P20II: https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/tmp20ii.html
- Epson P80II: https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/tmp80ii.html
- Star emulation: https://starmicronics.com/help-center/knowledge-base/tag/esc-pos/
- Bixolon command manual: https://www.bixolon.com/_upload/manual/Manual_SPP-R200III_Command_english_Rev_1_00.pdf
- Rollo X1040: https://www.rollo.com/product/rollo-wireless-printer
- Phomemo connections: https://help.phomemo.com/portal/en/kb/articles/bluetooth-connection-to-your-mobile-device
- Phomemo pocket printers: https://help.phomemo.com/portal/en/kb/articles/mini-printer-and-portable-user-s-guide
- MUNBYN RW402B: https://editor.munbyn.com/download/RW402B/RW402B%20User%20Manual.pdf
- MUNBYN RW403B: https://editor.munbyn.com/download/RW403B/RW403B%20User%20Manual.pdf
- PeriPage: https://www.peripageglobal.com/apps/frequently-asked-questions

## Simulations

The automated transport tests use fake connect/write/disconnect callbacks with real generated ESC/POS receipt bytes. They exercise Bluetooth Classic, BLE, USB and Wi-Fi paths at both 58 mm and 80 mm, plus offline-printer, Bluetooth-permission and interrupted-write failures. No radio, USB device or network printer is contacted. These tests verify software orchestration only, not any manufacturer's firmware, Bluetooth service UUIDs, USB endpoints, pairing or printed output. Run flutter test test/printer_transport_test.dart test/receipt_printing_test.dart to repeat.
