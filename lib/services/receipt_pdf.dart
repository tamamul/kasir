import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/receipt_data.dart';
import '../utils/format.dart';

/// Bikin PDF struk dengan lebar kertas ala thermal 80mm. pw.Document ini
/// dipakai baik buat dibagikan sebagai file PDF maupun buat dicetak lewat
/// dialog print sistem (yang otomatis mendukung banyak printer, termasuk
/// beberapa printer thermal yang terdaftar sebagai printer sistem/AirPrint).
pw.Document buildReceiptPdf(ReceiptData data) {
  final doc = pw.Document();
  const lebar = 80 * PdfPageFormat.mm;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(lebar, double.infinity, marginAll: 10),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(data.namaToko, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            if (data.alamatToko.isNotEmpty) pw.Text(data.alamatToko, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            if (data.teleponToko.isNotEmpty) pw.Text(data.teleponToko, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 6),
            pw.Divider(),
            pw.Text(data.noNota, style: const pw.TextStyle(fontSize: 9)),
            pw.Text(data.tanggal, style: const pw.TextStyle(fontSize: 9)),
            if (data.namaPelanggan != null && data.namaPelanggan!.isNotEmpty)
              pw.Text('Pelanggan: ${data.namaPelanggan}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Kasir: ${data.kasir}', style: const pw.TextStyle(fontSize: 9)),
            pw.Divider(),
            for (final item in data.items) ...[
              pw.Text(item.nama, style: const pw.TextStyle(fontSize: 9)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${item.qty} x ${rupiah(item.harga)}', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(rupiah(item.subtotal), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
            pw.Divider(),
            _baris('TOTAL', rupiah(data.total), bold: true),
            _baris('Bayar', rupiah(data.bayar)),
            if (data.sisaPiutang != null && data.sisaPiutang! > 0)
              _baris('Sisa Piutang', rupiah(data.sisaPiutang), bold: true)
            else
              _baris('Kembali', rupiah(data.kembali)),
            if (data.footerStruk.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.Text(data.footerStruk, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            ],
          ],
        );
      },
    ),
  );

  return doc;
}

pw.Widget _baris(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(label, style: style), pw.Text(value, style: style)],
  );
}