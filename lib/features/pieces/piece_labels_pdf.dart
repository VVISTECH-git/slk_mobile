import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Build + open the print dialog for a sheet of QR tags, one per piece code.
Future<void> printPieceLabels({
  required List<String> codes,
  required String productName,
  String? variantLabel,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(16),
      build: (ctx) => [
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: codes
              .map(
                (c) => pw.Container(
                  width: 168,
                  height: 92,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: c, width: 66, height: 66),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(productName,
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                                maxLines: 2, overflow: pw.TextOverflow.clip),
                            if (variantLabel != null && variantLabel.isNotEmpty)
                              pw.Text(variantLabel, style: const pw.TextStyle(fontSize: 7)),
                            pw.SizedBox(height: 3),
                            pw.Text(c, style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}
