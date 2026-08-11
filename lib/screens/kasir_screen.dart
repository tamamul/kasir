import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/data_cache.dart';
import '../services/auth_service.dart';
import '../models/receipt_data.dart';
import '../utils/format.dart';
import 'barcode_scanner_screen.dart';
import 'struk_preview_screen.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _CartItem {
  final int produkId;
  final String nama;
  final double harga;
  int qty;
  _CartItem({required this.produkId, required this.nama, required this.harga, this.qty = 1});
  double get subtotal => harga * qty;
}

class _KasirScreenState extends State<KasirScreen> {
  final _searchCtrl = TextEditingController();
  final _bayarCtrl = TextEditingController();
  final _pelangganCtrl = TextEditingController();
  final List<_CartItem> _cart = [];
  bool _loadingBayar = false;

  double get _total => _cart.fold(0, (sum, i) => sum + i.subtotal);
  double get _kembali => (double.tryParse(_bayarCtrl.text) ?? 0) - _total;

  Future<void> _bukaScanner() async {
    final hasil = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (hasil != null) _scanBarcode(hasil);
  }

  void _scanBarcode(String barcode) {
    if (barcode.trim().isEmpty) return;
    final cache = context.read<DataCache>();
    final produk = cache.produkByBarcode(barcode.trim());
    if (produk != null) {
      _tambahKeKeranjang(produk);
      _searchCtrl.clear();
      setState(() {});
    } else {
      // Barcode tidak ketemu persis -> tampilkan sebagai kata kunci pencarian,
      // siapa tahu itu sebenarnya ID produk yang diketik manual.
      _searchCtrl.text = barcode.trim();
      setState(() {});
      _snack('Barcode "$barcode" tidak ditemukan persis — menampilkan hasil pencarian terdekat');
    }
  }

  void _tambahKeKeranjang(Map<String, dynamic> produk) {
    final id = int.parse(produk['id'].toString());
    final existing = _cart.where((i) => i.produkId == id);
    setState(() {
      if (existing.isNotEmpty) {
        existing.first.qty += 1;
      } else {
        _cart.add(_CartItem(
          produkId: id,
          nama: produk['nama'].toString(),
          harga: double.parse(produk['harga_jual'].toString()),
        ));
      }
    });
  }

  void _ubahQty(_CartItem item, int delta) {
    setState(() {
      item.qty += delta;
      if (item.qty <= 0) _cart.remove(item);
    });
  }

  void _hapusItem(_CartItem item) {
    setState(() => _cart.remove(item));
  }

  Future<void> _bayar() async {
    if (_cart.isEmpty) {
      _snack('Keranjang masih kosong');
      return;
    }
    final bayar = double.tryParse(_bayarCtrl.text) ?? 0;
    if (bayar < _total) {
      _snack('Uang bayar kurang dari total belanja — kalau mau nyicil, pakai menu Piutang');
      return;
    }

    setState(() => _loadingBayar = true);
    final res = await ApiClient.call('prosesPenjualan', {
      'pelanggan': _pelangganCtrl.text,
      'bayar': bayar,
      'items': _cart.map((i) => {'produk_id': i.produkId, 'qty': i.qty}).toList(),
    });
    if (!mounted) return;
    setState(() => _loadingBayar = false);

    if (!res.isSuccess) {
      _snack('Gagal: ${res.message}');
      return;
    }

    final cache = context.read<DataCache>();
    for (final item in _cart) {
      cache.applyLocalStokChange(item.produkId, -item.qty);
    }

    _bukaStruk(res.data, cache);
    setState(() {
      _cart.clear();
      _bayarCtrl.clear();
      _pelangganCtrl.clear();
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _bukaStruk(Map<String, dynamic> data, DataCache cache) {
    final penjualan = data['penjualan'];
    final items = (data['items'] as List<dynamic>).map((i) => ReceiptItem.fromMap(i)).toList();
    final pengaturan = cache.pengaturan;
    final kasir = context.read<AuthService>().user?['username']?.toString() ?? '';

    final receipt = ReceiptData(
      namaToko: (pengaturan['nama_toko'] ?? 'Toko').toString(),
      alamatToko: (pengaturan['alamat'] ?? '').toString(),
      teleponToko: (pengaturan['telepon'] ?? '').toString(),
      footerStruk: (pengaturan['footer_struk'] ?? '').toString(),
      noNota: penjualan['no_nota'].toString(),
      tanggal: penjualan['tanggal'].toString(),
      namaPelanggan: penjualan['pelanggan']?.toString(),
      kasir: kasir,
      items: items,
      total: num.tryParse(penjualan['total'].toString()) ?? 0,
      bayar: num.tryParse(penjualan['bayar'].toString()) ?? 0,
      kembali: num.tryParse(penjualan['kembali'].toString()) ?? 0,
    );

    Navigator.push(context, MaterialPageRoute(builder: (_) => StrukPreviewScreen(data: receipt)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final pencarian = _buildPencarian();
        final keranjang = _buildKeranjang();
        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 3, child: pencarian),
              const VerticalDivider(width: 1),
              Expanded(flex: 2, child: keranjang),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: pencarian),
            const Divider(height: 1),
            SizedBox(height: 360, child: keranjang),
          ],
        );
      },
    );
  }

  Widget _buildPencarian() {
    return Consumer<DataCache>(
      builder: (context, cache, _) {
        final hasil = cache.searchProduk(_searchCtrl.text);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari nama, ID, atau barcode produk...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: cache.syncing
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _scanBarcode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _bukaScanner,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Icon(Icons.qr_code_scanner),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: hasil.isEmpty
                    ? Center(
                        child: Text(
                          cache.produk.isEmpty
                              ? 'Menunggu data produk tersinkron...'
                              : 'Cari, scan, atau ketik ID produk untuk mulai',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.4,
                        ),
                        itemCount: hasil.length,
                        itemBuilder: (_, i) {
                          final p = hasil[i] as Map<String, dynamic>;
                          return Card(
                            child: InkWell(
                              onTap: () => _tambahKeKeranjang(p),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(p['nama'].toString(),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(rupiah(p['harga_jual']), style: const TextStyle(color: Colors.grey)),
                                    Text('ID: ${p['id']} • Stok: ${p['stok']}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeranjang() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Keranjang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Belum ada item', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (_, i) {
                      final item = _cart[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(
                                      '${rupiah(item.harga)} x ${item.qty} = ${rupiah(item.subtotal)}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _ubahQty(item, -1),
                              ),
                              Text('${item.qty}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _ubahQty(item, 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                tooltip: 'Hapus item (kalau salah tap)',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _hapusItem(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(rupiah(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pelangganCtrl,
            decoration: const InputDecoration(labelText: 'Nama pelanggan (opsional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bayarCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah bayar', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kembalian'),
              Text(rupiah(_kembali), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loadingBayar ? null : _bayar,
              style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _loadingBayar
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Bayar', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
