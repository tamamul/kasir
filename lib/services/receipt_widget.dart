import 'package:flutter/material.dart';
import '../models/receipt_data.dart';
import '../utils/format.dart';

/// Tampilan struk ala thermal printer (lebar sempit, font monospace).
/// Dipakai untuk preview di layar DAN sebagai widget yang di-capture jadi
/// gambar / dikirim ke printWidget() printer thermal.
class ReceiptWidget extends StatelessWidget {
  final ReceiptData data;
  const ReceiptWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black);
    final bold = style.copyWith(fontWeight: FontWeight.bold);

    return Container(
      width: 300,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(data.namaToko, textAlign: TextAlign.center, style: bold.copyWith(fontSize: 14)),
          if (data.alamatToko.isNotEmpty) Text(data.alamatToko, textAlign: TextAlign.center, style: style),
          if (data.teleponToko.isNotEmpty) Text(data.teleponToko, textAlign: TextAlign.center, style: style),
          const _Dashed(),
          Text(data.noNota, style: style),
          Text(data.tanggal, style: style),
          if (data.namaPelanggan != null && data.namaPelanggan!.isNotEmpty) Text('Pelanggan: ${data.namaPelanggan}', style: style),
          Text('Kasir: ${data.kasir}', style: style),
          const _Dashed(),
          for (final item in data.items) ...[
            Text(item.nama, style: style),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${item.qty} x ${rupiah(item.harga)}', style: style),
                Text(rupiah(item.subtotal), style: style),
              ],
            ),
          ],
          const _Dashed(),
          _baris('TOTAL', rupiah(data.total), bold),
          _baris('Bayar', rupiah(data.bayar), style),
          if (data.sisaPiutang != null && data.sisaPiutang! > 0)
            _baris('Sisa Piutang', rupiah(data.sisaPiutang), bold.copyWith(color: Colors.red))
          else
            _baris('Kembali', rupiah(data.kembali), style),
          if (data.footerStruk.isNotEmpty) ...[
            const _Dashed(),
            Text(data.footerStruk, textAlign: TextAlign.center, style: style),
          ],
        ],
      ),
    );
  }

  Widget _baris(String label, String value, TextStyle style) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / 6).floor();
          return Text('-' * count, style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
        },
      ),
    );
  }
}