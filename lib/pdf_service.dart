import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateProfessionalLabels(
    List<Map<String, dynamic>> books,
  ) async {
    final pdf = pw.Document();

    // Standard A4 is 210 x 297 mm.
    // We will use a 3x8 grid (24 labels per page)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(
          10,
        ), // Minimal margin for maximum label space
        build: (context) => [
          pw.GridView(
            crossAxisCount: 3,
            childAspectRatio: 0.7, // Adjust to fit your physical label height
            children: books.map((book) {
              return pw.Container(
                margin: const pw.EdgeInsets.all(2),
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(2),
                  ),
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    // Professional Branding
                    pw.Text(
                      "Imperial College of Pharmacy",
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                    pw.SizedBox(height: 4),

                    // High-Quality QR Code
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: (book['acc_no'] ?? 'N/A').toString(),
                      width: 55,
                      height: 55,
                    ),
                    pw.SizedBox(height: 4),

                    // Bold Accession Number
                    pw.Text(
                      "ACC: ${book['acc_no']}",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    // Short Metadata
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "${book['title']}".toUpperCase(),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                    pw.Text(
                      "${book['author']} | ${book['publisher']}",
                      maxLines: 1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 5,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'ICP_Library_Labels_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
