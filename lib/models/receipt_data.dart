class ReceiptItem {
  final String nama;
  final num qty;
  final num harga;
  final num subtotal;

  ReceiptItem({required this.nama, required this.qty, required this.harga, required this.subtotal});

  factory ReceiptItem.fromMap(Map<String, dynamic> m) {
    return ReceiptItem(
      nama: (m['nama'] ?? m['nama_produk'] ?? '').toString(),
      qty: num.tryParse(m['qty'].toString()) ?? 0,
      harga: num.tryParse(m['harga'].toString()) ?? 0,
      subtotal: num.tryParse(m['subtotal'].toString()) ?? 0,
    );
  }
}

class ReceiptData {
  final String namaToko;
  final String alamatToko;
  final String teleponToko;
  final String footerStruk;
  final String noNota;
  final String tanggal;
  final String? namaPelanggan;
  final String kasir;
  final List<ReceiptItem> items;
  final num total;
  final num bayar;
  final num kembali;
  final num? sisaPiutang; // null kalau bukan transaksi piutang / sudah lunas

  ReceiptData({
    required this.namaToko,
    required this.alamatToko,
    required this.teleponToko,
    required this.footerStruk,
    required this.noNota,
    required this.tanggal,
    this.namaPelanggan,
    required this.kasir,
    required this.items,
    required this.total,
    required this.bayar,
    required this.kembali,
    this.sisaPiutang,
  });
}
