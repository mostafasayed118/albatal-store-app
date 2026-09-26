import 'dart:io';
import 'dart:typed_data';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/invoice/invoice_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Document-level money pins for [InvoicePdfBuilder].
///
/// The sibling invoice_pdf_test only asserts PDF shape — non-empty bytes, the
/// `%PDF` header, the isolate path — so a formatting regression in a cell or in
/// the grand total would ship silently. These assertions read the REAL
/// compressed output instead: the invoice renders Helvetica (the pdf package's
/// built-in font), so its content streams carry literal ASCII text operators
/// once the Flate streams are inflated. Only `dart:io`'s zlib decoder is used,
/// so no dependency was added and nothing in `lib/` had to be reshaped for
/// testability.
///
/// Mutation-checked: switching the three invoice call sites back to the compact
/// `Money.format()` fails the first two tests below while the older
/// invoice_pdf_test still passes 4/4 — i.e. these pins carry coverage the suite
/// did not have.
void main() {
  group('InvoicePdfBuilder money strings', () {
    test('unit price, line total and grand total render at two decimals',
        () async {
      final text = await _textOf(_order(
        total: const Money(360000), // 3600.00 EGP
        items: [_item('Royal Silk', qty: 2, unitMinor: 49950)], // 499.50
      ));

      _renders(text, '499.50'); // unit price cell
      _renders(text, '999.00'); // line cell = 499.50 x 2
      _renders(text, '3600.00'); // grand total
      _renders(text, 'EGP'); // ...with its currency suffix
    });

    test('whole-pound amounts keep their trailing decimals on the document',
        () async {
      // 1200.00 EGP. The compact UI form (Money.format) prints "1200", so this
      // pins the document style, not merely the piaster handling.
      final text = await _textOf(_order(
        total: const Money(120000),
        items: [_item('Silk', qty: 1, unitMinor: 120000)],
      ));

      _renders(text, '1200.00');
      _lacks(text, '1200', reason: 'never a bare whole-pound amount');
    });

    test('fractional piasters survive into the document', () async {
      // The number from the original bug: 998.75 EGP must not print as 998.
      final text = await _textOf(_order(
        total: const Money(99875),
        items: [_item('Metered Silk', qty: 1, unitMinor: 99875)],
      ));

      _renders(text, '998.75');
      _lacks(text, '998', reason: 'truncating the piasters is the regression');
    });

    test('the cells stay digits-only because the headers name the currency',
        () async {
      // "Unit (EGP)" and "Line (EGP)" head the columns, so the cells pass
      // symbol: '' and the currency may appear exactly once — on the grand
      // total. Repeating it in the cells would break this count.
      final text = await _textOf(_order(
        total: const Money(360000),
        items: [_item('Royal Silk', qty: 2, unitMinor: 49950)],
      ));

      expect(_runs(text, 'EGP'), 1,
          reason: 'only the grand total carries the currency');
      expect(_runs(text, 'EGY'), 0,
          reason: 'the invoice is an EGP document, not the EGY UI label');
    });
  });
}

AdminOrderItem _item(String name, {required int qty, required int unitMinor}) =>
    AdminOrderItem(
      productName: name,
      size: '2m',
      color: 'Emerald',
      quantity: qty,
      unitPrice: Money(unitMinor),
    );

AdminOrder _order({
  required List<AdminOrderItem> items,
  required Money total,
}) =>
    AdminOrder(
      id: 'ORD-INV-1',
      status: AdminOrderStatus.paid,
      total: total,
      placedAt: DateTime.utc(2026, 9, 12),
      customerName: 'Nour Hassan',
      itemCount: items.fold<int>(0, (v, i) => v + i.quantity),
      items: items,
    );

Future<String> _textOf(AdminOrder order) async =>
    _normalize(await const InvoicePdfBuilder().build(order));

/// Asserts the document renders a text run of [value], e.g. `[(499.50)]TJ`.
///
/// These use boolean expectations on purpose: the raw document text is far too
/// large to be useful as a matcher's "Actual" dump on failure.
void _renders(String text, String value) => expect(
      text.contains(_run(value)),
      isTrue,
      reason: 'expected the rendered run ${_run(value)} in the document',
    );

void _lacks(String text, String value, {required String reason}) => expect(
      text.contains(_run(value)),
      isFalse,
      reason: '$reason (found ${_run(value)})',
    );

int _runs(String text, String value) =>
    RegExp(RegExp.escape(_run(value))).allMatches(text).length;

String _run(String value) => '[($value)]TJ';

/// Whitespace is irrelevant to operator meaning and the pdf package splits
/// multi-word runs, so collapsing it makes each run match exact.
String _normalize(Uint8List bytes) =>
    _inflated(bytes).replaceAll(RegExp(r'\s+'), '');

/// Concatenates every Flate-decodable stream in the PDF. Streams that are not
/// zlib payloads (embedded images, font descriptors) are skipped.
String _inflated(Uint8List bytes) {
  final out = StringBuffer();
  var cursor = 0;
  while (true) {
    final start = _indexOf(bytes, 'stream', cursor);
    if (start < 0) break;
    var dataStart = start + 'stream'.length;
    if (bytes[dataStart] == 0x0D) dataStart++;
    if (bytes[dataStart] == 0x0A) dataStart++;
    final end = _indexOf(bytes, 'endstream', dataStart);
    if (end < 0) break;
    try {
      out.write(String.fromCharCodes(
          ZLibCodec().decode(bytes.sublist(dataStart, end))));
    } on FormatException {
      // Not a zlib stream — nothing to read from it.
    } on ArgumentError {
      // Truncated or otherwise undecodable — nothing to read from it.
    }
    cursor = end + 'endstream'.length;
  }
  return out.toString();
}

int _indexOf(Uint8List bytes, String needle, int from) {
  final codes = needle.codeUnits;
  for (var i = from; i <= bytes.length - codes.length; i++) {
    var matched = true;
    for (var j = 0; j < codes.length; j++) {
      if (bytes[i + j] != codes[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return i;
  }
  return -1;
}
