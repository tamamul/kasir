import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/data_cache.dart';
import '../utils/format.dart';

class _CartItem {
  final int produkId;
  final String nama;
  final double harga;
  int qty;
  _CartItem({required this.produkId, required this.nama, required this.harga, this.qty = 1});
  double get subtotal => harga * qty;
}

/// Layar serbaguna: kalau [penjualanId] null berarti bikin transaksi
/// piutang baru (wajib pilih pelanggan). Kalau diisi, berarti menambah
/// item dan/atau bayar cicilan ke transaksi yang sudah ada — item dan
/// bayar sama-sama opsional, jadi 1 layar ini bisa dipakai buat 3 kasus
/// sekaligus (tambah orderan saja, bayar saja, atau dua-duanya).
class PiutangTransaksiScreen extends StatefulWidget {
  final dynamic penjualanId;
  const PiutangTransaksiScreen({super.key, this.penjualanId});

  @override
  State<PiutangTransaksiScreen> createState() => _PiutangTransaksiScreenState();
}

class _PiutangTransaksiScreenState extends State<PiutangTransaksiScreen> {
  final _searchCtrl = TextEditingController();
  final _bayarCtrl = TextEditingController();
  final List<_CartItem> _cart = [];
  Map<String, dynamic>? _pelangganTerpilih;
  Map<String, dynamic>? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isBaru => widget.penjualanId == null;

  @override
  void initState() {
    super.initState();
    _muatAwal();
  }

  Future<void> _muatAwal() async {
    if (!_isBaru) {
      final res = await ApiClient.call('getPiutangDetail', {'id': widget.penjualanId});
      if (res.isSuccess && mounted) {
        setState(() => _existing = res.data['penjualan']);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  double get _sisaSaatIni => _existing != null ? (double.tryParse(_existing!['sisa'].toString()) ?? 0) : 0;
  double get _tambahanTotal => _cart.fold(0, (sum, i) => sum + i.subtotal);
  double get _proyeksiSisa {
    final bayar = double.tryParse(_bayarCtrl.text) ?? 0;
    final sisa = _sisaSaatIni + _tambahanTotal - bayar;
    return sisa < 0 ? 0 : sisa;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _tambah(Map<String, dynamic> p) {
    final id = int.parse(p['id'].toString());
    final existing = _cart.where((i) => i.produkId == id);
    setState(() {
      if (existing.isNotEmpty) {
        existing.first.qty += 1;
      } else {
        _cart.add(_CartItem(produkId: id, nama: p['nama'].toString(), harga: double.parse(p['harga_jual'].toString())));
      }
    });
  }

  Future<void> _simpan() async {
    if (_isBaru && _pelangganTerpilih == null) {
      _snack('Pilih pelanggan dulu');
      return;
    }
    final bayar = double.tryParse(_bayarCtrl.text) ?? 0;
    if (_cart.isEmpty && bayar <= 0) {
      _snack('Isi item yang dibeli atau jumlah bayar (boleh salah satu)');
      return;
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{'bayar': bayar};
    if (_isBaru) {
      payload['pelanggan_id'] = _pelangganTerpilih!['id'];
    } else {
      payload['penjualan_id'] = widget.penjualanId;
    }
    if (_cart.isNotEmpty) {
      payload['items'] = _cart.map((i) => {'produk_id': i.produkId, 'qty': i.qty}).toList();
    }

    final res = await ApiClient.call('prosesTransaksiPiutang', payload);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!res.isSuccess) {
      _snack('Gagal: ${res.message}');
      return;
    }

    if (_cart.isNotEmpty) {
      final cache = context.read<DataCache>();
      for (final item in _cart) {
        cache.applyLocalStokChange(item.produkId, -item.qty);
      }
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(_isBaru ? 'Piutang Baru' : 'Tambah Orderan / Bayar')),
      body: Consumer<DataCache>(
        builder: (context, cache, _) {
          final hasil = cache.searchProduk(_searchCtrl.text);
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isBaru)
  DropdownButtonFormField<String>(
    value: _pelangganTerpilih?['id']?.toString(),
    decoration: const InputDecoration(
      labelText: 'Pelanggan',
      border: OutlineInputBorder(),
    ),
    items: cache.pelanggan
        .where((p) => p['aktif'] == 'Y')
        .map<DropdownMenuItem<String>>(
          (p) => DropdownMenuItem<String>(
            value: p['id'].toString(),
            child: Text(p['nama'].toString()),
          ),
        )
        .toList(),
    onChanged: (id) {
      if (id == null) {
        setState(() => _pelangganTerpilih = null);
        return;
      }

      final pelanggan = cache.pelanggan.firstWhere(
        (p) => p['id'].toString() == id,
      );

      setState(() => _pelangganTerpilih = pelanggan);
    },
  )
else if (_existing != null)
  Card(
    color: Colors.orange.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _existing!['pelanggan'].toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Sisa piutang saat ini: ${rupiah(_existing!['sisa'])}',
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    ),
  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tambah produk (opsional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search)),
                  onChanged: (_) => setState(() {}),
                ),
                if (hasil.isNotEmpty)
                  SizedBox(
                    height: 130,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: hasil.length,
                      itemBuilder: (_, i) {
                        final p = hasil[i] as Map<String, dynamic>;
                        return SizedBox(
                          width: 150,
                          child: Card(
                            margin: const EdgeInsets.only(top: 8, right: 6),
                            child: InkWell(
                              onTap: () => _tambah(p),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['nama'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const Spacer(),
                                    Text(rupiah(p['harga_jual']), style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(child: Text('Belum ada item baru ditambahkan', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _cart.length,
                          itemBuilder: (_, i) {
                            final item = _cart[i];
                            return ListTile(
                              dense: true,
                              title: Text(item.nama),
                              subtitle: Text('${rupiah(item.harga)} x${item.qty}'),
                              trailing: Text(rupiah(item.subtotal)),
                              onLongPress: () => setState(() => _cart.removeAt(i)),
                            );
                          },
                        ),
                ),
                const Divider(),
                TextField(
                  controller: _bayarCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bayar sekarang (boleh kosong)', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Proyeksi sisa piutang', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(rupiah(_proyeksiSisa), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _simpan,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
