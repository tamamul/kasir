import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../utils/format.dart';
import 'piutang_transaksi_screen.dart';

class PiutangDetailScreen extends StatefulWidget {
  final dynamic id;
  const PiutangDetailScreen({super.key, required this.id});

  @override
  State<PiutangDetailScreen> createState() => _PiutangDetailScreenState();
}

class _PiutangDetailScreenState extends State<PiutangDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final res = await ApiClient.call('getPiutangDetail', {'id': widget.id});
    if (!mounted) return;
    setState(() {
      _data = res.isSuccess ? res.data : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_data?['penjualan']?['no_nota']?.toString() ?? 'Detail Piutang')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : _buildBody(),
      floatingActionButton: (_data != null && _data!['penjualan']['status'] != 'LUNAS')
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PiutangTransaksiScreen(penjualanId: widget.id)),
                );
                _muat();
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah / Bayar'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final penjualan = _data!['penjualan'];
    final items = _data!['items'] as List<dynamic>;
    final riwayat = _data!['riwayat_bayar'] as List<dynamic>;
    final lunas = penjualan['status'] == 'LUNAS';

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: lunas ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(penjualan['pelanggan'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(penjualan['tanggal'].toString(), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  _baris('Total', penjualan['total']),
                  _baris('Sudah dibayar', penjualan['bayar']),
                  _baris('Sisa', penjualan['sisa'], warna: lunas ? null : Colors.red),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(lunas ? 'LUNAS' : 'BELUM LUNAS', style: const TextStyle(color: Colors.white)),
                    backgroundColor: lunas ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Barang', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final i in items)
            ListTile(
              dense: true,
              title: Text(i['nama_produk'].toString()),
              subtitle: Text('${i['qty']} x ${rupiah(i['harga'])}'),
              trailing: Text(rupiah(i['subtotal'])),
            ),
          const SizedBox(height: 16),
          const Text('Riwayat Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
          if (riwayat.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Belum ada pembayaran', style: TextStyle(color: Colors.grey)),
            )
          else
            for (final r in riwayat)
              ListTile(
                dense: true,
                leading: const Icon(Icons.payments_outlined),
                title: Text(rupiah(r['jumlah'])),
                subtitle: Text('${r['tanggal']} • ${r['kasir']}'),
              ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _baris(String label, dynamic value, {Color? warna}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(rupiah(value), style: TextStyle(fontWeight: FontWeight.bold, color: warna)),
        ],
      ),
    );
  }
}
