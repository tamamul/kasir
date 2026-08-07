import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../utils/format.dart';

class PembelianScreen extends StatefulWidget {
  const PembelianScreen({super.key});

  @override
  State<PembelianScreen> createState() => _PembelianScreenState();
}

class _BeliItem {
  final int produkId;
  final String nama;
  int qty;
  double harga;
  _BeliItem({required this.produkId, required this.nama, this.qty = 1, required this.harga});
}

class _PembelianScreenState extends State<PembelianScreen> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _hasil = [];
  final List<_BeliItem> _cart = [];
  bool _saving = false;

  Future<void> _cari(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _hasil = []);
      return;
    }
    final res = await ApiClient.call('getProduk', {'q': q});
    if (!mounted) return;
    setState(() => _hasil = res.isSuccess ? res.data : []);
  }

  void _tambah(Map<String, dynamic> p) {
    final id = int.parse(p['id'].toString());
    final existing = _cart.where((i) => i.produkId == id);
    setState(() {
      if (existing.isNotEmpty) {
        existing.first.qty += 1;
      } else {
        _cart.add(_BeliItem(
          produkId: id,
          nama: p['nama'].toString(),
          harga: double.tryParse(p['harga_beli'].toString()) ?? 0,
        ));
      }
    });
  }

  Future<void> _simpan() async {
    if (_cart.isEmpty) return;
    setState(() => _saving = true);
    final res = await ApiClient.call('prosesPembelian', {
      'items': _cart.map((i) => {'produk_id': i.produkId, 'qty': i.qty, 'harga': i.harga}).toList(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${res.message}')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok berhasil ditambahkan')));
    setState(() => _cart.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                  labelText: 'Cari produk', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search)),
              onChanged: _cari,
            ),
          ),
          if (_hasil.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _hasil.length,
                itemBuilder: (_, i) {
                  final p = _hasil[i] as Map<String, dynamic>;
                  return SizedBox(
                    width: 160,
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: InkWell(
                        onTap: () => _tambah(p),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['nama'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const Spacer(),
                              Text('Stok: ${p['stok']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const Divider(),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Belum ada produk dipilih', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (_, i) {
                      final item = _cart[i];
                      return ListTile(
                        title: Text(item.nama),
                        subtitle: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: TextFormField(
                                initialValue: item.qty.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Qty'),
                                onChanged: (v) => setState(() => item.qty = int.tryParse(v) ?? item.qty),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                initialValue: item.harga.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Harga'),
                                onChanged: (v) => setState(() => item.harga = double.tryParse(v) ?? item.harga),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _cart.removeAt(i)),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _simpan,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Stok Masuk'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
