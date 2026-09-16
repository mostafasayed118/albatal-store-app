import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../entities/admin_order.dart';

/// Branded invoice PDF generator (feature-batch §16).
///
/// Pure Dart — no platform channels, no network: fully unit-testable.
/// The document build runs on a background isolate via [Isolate.run] so
/// layout work for large invoices never janks the UI thread; only
/// `printing`'s share/print sheet stays on the main isolate (platform
/// channels must not cross isolates).
///
/// Typography falls back to Helvetica (the pdf package's built-in font)
/// because Montserrat/Inter TTFs would add ~1 MB to the bundle — no
/// asset loading is involved, so nothing has to be pre-fetched on the
/// main side. The emerald/gold brand colours come from DESIGN.md tokens.
final class InvoicePdfBuilder {
  const InvoicePdfBuilder();

  static const _emerald = PdfColor.fromInt(0xFF064E3B);
  static const _gold = PdfColor.fromInt(0xFF904D00);

  /// Builds the invoice bytes for [order]. Throws [ArgumentError] when
  /// the order has no line items — an invoice without lines is a bug,
  /// not a document.
  ///
  /// The `pdf` construction itself is pure Dart, so it is spawned off
  /// the main isolate with [Isolate.run]. [AdminOrder] is an immutable
  /// DTO graph (strings, ints, enums, DateTime) — sendable as-is; no
  /// widgets, controllers, or platform objects cross the boundary.
  Future<Uint8List> build(AdminOrder order) async {
    if (order.items.isEmpty) {
      throw ArgumentError('invoice requires at least one line item');
    }
    return Isolate.run(() => buildDocument(order));
  }

  /// Pure document construction — runs entirely on the background
  /// isolate. Static so the [Isolate.run] closure captures only the
  /// [order] payload, never `this`.
  static Future<Uint8List> buildDocument(AdminOrder order) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(order),
            pw.SizedBox(height: 24),
            _meta(order),
            pw.SizedBox(height: 16),
            _itemsTable(order),
            pw.Spacer(),
            _totals(order),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _header(AdminOrder order) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Al Batal Elite',
                  style: const pw.TextStyle(
                      fontSize: 24,
                      color: _emerald,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Premium Fabrics',
                  style: const pw.TextStyle(fontSize: 10, color: _gold)),
            ],
          ),
          pw.Text('INVOICE',
              style: const pw.TextStyle(fontSize: 18, color: _emerald)),
        ],
      );

  static pw.Widget _meta(AdminOrder order) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Order: ${order.id}'),
          pw.Text('Date: ${order.placedAt.toUtc().toIso8601String()}'),
          if (order.customerName != null && order.customerName!.isNotEmpty)
            pw.Text('Customer: ${order.customerName}'),
        ],
      );

  static pw.Widget _itemsTable(AdminOrder order) =>
      pw.TableHelper.fromTextArray(
        headerStyle: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
        headerDecoration: const pw.BoxDecoration(color: _emerald),
        cellStyle: const pw.TextStyle(fontSize: 10),
        headers: ['Item', 'Size', 'Color', 'Qty', 'Unit (EGP)', 'Line (EGP)'],
        data: order.items
            .map((item) => [
                  item.productName,
                  item.size,
                  item.color,
                  item.quantity.toString(),
                  item.unitPrice.formatExact(symbol: ''),
                  (item.unitPrice * item.quantity).formatExact(symbol: ''),
                ])
            .toList(),
      );

  static pw.Widget _totals(AdminOrder order) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Total: ${order.total.formatExact()}',
          style: const pw.TextStyle(
              fontSize: 14, color: _emerald, fontWeight: pw.FontWeight.bold),
        ),
      );
}
