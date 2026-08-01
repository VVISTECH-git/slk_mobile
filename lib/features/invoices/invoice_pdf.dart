import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/invoice.dart';

final _n = NumberFormat('#,##0.00', 'en_IN');
String _amt(num v) => _n.format(v);

/// Build a GST tax-invoice PDF matching the web layout: business header, buyer,
/// itemised lines with CGST/SGST, totals, and amount in words.
Future<List<int>> buildInvoicePdf(InvoiceFull inv, Map<String, dynamic> business) async {
  final doc = pw.Document();
  final b = business;
  String s(String k, [String d = '']) => (b[k] as String?)?.trim().isNotEmpty == true ? b[k] as String : d;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ---- Header ----
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(s('legalName', 'Sri Lakshmi Kalamkari'),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    if (s('brand').isNotEmpty) pw.Text(s('brand')),
                    if (s('address').isNotEmpty) pw.Text(s('address'), style: const pw.TextStyle(fontSize: 9)),
                    pw.Row(children: [
                      if (s('gstin').isNotEmpty) pw.Text('GSTIN: ${s('gstin')}  ', style: const pw.TextStyle(fontSize: 9)),
                      if (s('phone').isNotEmpty) pw.Text('Ph: ${s('phone')}', style: const pw.TextStyle(fontSize: 9)),
                    ]),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(inv.invoiceNumber, style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(inv.createdAt, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.Divider(),

            // ---- Buyer + store ----
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill to', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text(inv.customer.name?.isNotEmpty == true ? inv.customer.name! : 'Walk-in customer'),
                      if (inv.customer.phone?.isNotEmpty == true) pw.Text('Ph: ${inv.customer.phone}', style: const pw.TextStyle(fontSize: 9)),
                      if (inv.customer.gstin?.isNotEmpty == true) pw.Text('GSTIN: ${inv.customer.gstin}', style: const pw.TextStyle(fontSize: 9)),
                      if (inv.customer.address?.isNotEmpty == true) pw.Text(inv.customer.address!, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (inv.storeName != null) pw.Text('Store: ${inv.storeName}', style: const pw.TextStyle(fontSize: 9)),
                    if (inv.staffName != null) pw.Text('Billed by: ${inv.staffName}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Payment: ${inv.paymentMode.toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // ---- Items table ----
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFB5533B)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              headers: ['Item', 'HSN', 'Qty', 'Rate', 'Taxable', 'GST', 'Amount'],
              data: inv.items
                  .map((it) => [
                        '${it.productName}\n${it.sku}${it.variantLabel != null && it.variantLabel != '—' ? ' · ${it.variantLabel}' : ''}',
                        it.hsnCode ?? '-',
                        '${it.quantity}',
                        _amt(it.unitPrice),
                        _amt(it.taxableValue),
                        '${_amt(it.cgst + it.sgst)}\n@${it.gstRate.toStringAsFixed(0)}%',
                        _amt(it.lineTotal),
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 10),

            // ---- Totals ----
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 240,
                child: pw.Column(
                  children: [
                    _totRow('Taxable value', _amt(inv.taxableValue)),
                    _totRow('CGST', _amt(inv.cgst)),
                    _totRow('SGST', _amt(inv.sgst)),
                    if (inv.discount > 0) _totRow('Discount', '- ${_amt(inv.discount)}'),
                    pw.Divider(),
                    _totRow('Grand Total', '₹ ${_amt(inv.total)}', bold: true),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Amount in words: ${_inWords(inv.total)} rupees only',
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),

            pw.Spacer(),
            pw.Divider(),
            pw.Text('Thank you for shopping with us. Goods once sold are subject to store policy.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _totRow(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(
    fontSize: bold ? 12 : 9,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    ),
  );
}

// ---- Amount in words (Indian system) ----
String _inWords(double amount) {
  final n = amount.round();
  if (n == 0) return 'Zero';
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  String twoDigits(int v) {
    if (v < 20) return ones[v];
    return '${tens[v ~/ 10]}${v % 10 != 0 ? ' ${ones[v % 10]}' : ''}';
  }

  String threeDigits(int v) {
    final h = v ~/ 100;
    final rest = v % 100;
    return '${h > 0 ? '${ones[h]} Hundred${rest != 0 ? ' ' : ''}' : ''}${rest != 0 ? twoDigits(rest) : ''}';
  }

  final crore = n ~/ 10000000;
  final lakh = (n % 10000000) ~/ 100000;
  final thousand = (n % 100000) ~/ 1000;
  final hundred = n % 1000;

  final parts = <String>[];
  if (crore > 0) parts.add('${twoDigits(crore)} Crore');
  if (lakh > 0) parts.add('${twoDigits(lakh)} Lakh');
  if (thousand > 0) parts.add('${twoDigits(thousand)} Thousand');
  if (hundred > 0) parts.add(threeDigits(hundred));
  return parts.join(' ').trim();
}
