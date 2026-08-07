import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../utils/format.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  List<dynamic> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final res = await ApiClient.call('getPenjualan', {});
    if (!mounted) return;
    setState(() {
      _data = res.isSuccess ? res.data : [];
      _loading = false;
    });
  }

  Future<void> _lihatDetail(dynamic id) async {
    final res = await ApiClient.call('getPenjualanDetail', {'id': id});
    if (!mounted) return;
    if (!res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${res.message}')));
      return;
    }
    final penjualan = res.data['penjualan'];
    final items = res.data['items'] as List<dynamic>;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(penjualan['no_nota'].toString()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${penjualan['tanggal']} • Kasir: ${penjualan['kasir']}', style: const TextStyle(color: Colors.grey)),
              const Divider(),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${i['nama_produk']} x${i['qty']}')),
                      Text(rupiah(i['subtotal'])),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(rupiah(penjualan['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              child: _data.isEmpty
                  ? ListView(children: const [
                      Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada transaksi'))),
                    ])
                  : ListView.builder(
                      itemCount: _data.length,
                      itemBuilder: (_, i) {
                        final p = _data[i] as Map<String, dynamic>;
                        return ListTile(
                          title: Text(p['no_nota'].toString()),
                          subtitle: Text('${p['tanggal']} • ${p['pelanggan'] ?? '-'}'),
                          trailing: Text(rupiah(p['total'])),
                          onTap: () => _lihatDetail(p['id']),
                        );
                      },
                    ),
            ),
    );
  }
}
