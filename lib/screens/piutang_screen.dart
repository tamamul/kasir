import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../utils/format.dart';
import 'piutang_transaksi_screen.dart';
import 'piutang_detail_screen.dart';

class PiutangScreen extends StatefulWidget {
  const PiutangScreen({super.key});

  @override
  State<PiutangScreen> createState() => _PiutangScreenState();
}

class _PiutangScreenState extends State<PiutangScreen> {
  List<dynamic> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final res = await ApiClient.call('getPiutangList', {});
    if (!mounted) return;
    setState(() {
      _data = res.isSuccess ? res.data : [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPiutang = _data.fold<double>(0, (sum, p) => sum + (double.tryParse(p['sisa'].toString()) ?? 0));

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total piutang belum lunas', style: TextStyle(color: Colors.grey)),
                Text(rupiah(totalPiutang), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _muat,
                    child: _data.isEmpty
                        ? ListView(children: const [
                            Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Tidak ada piutang terbuka'))),
                          ])
                        : ListView.builder(
                            itemCount: _data.length,
                            itemBuilder: (_, i) {
                              final p = _data[i] as Map<String, dynamic>;
                              return ListTile(
                                title: Text(p['pelanggan'].toString()),
                                subtitle: Text('${p['no_nota']} • Total ${rupiah(p['total'])}'),
                                trailing: Text(rupiah(p['sisa']), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => PiutangDetailScreen(id: p['id'])),
                                  );
                                  _muat();
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PiutangTransaksiScreen()));
          _muat();
        },
        icon: const Icon(Icons.add),
        label: const Text('Piutang Baru'),
      ),
    );
  }
}
