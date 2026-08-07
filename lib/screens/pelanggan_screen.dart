import 'package:flutter/material.dart';
import '../services/api_client.dart';

class PelangganScreen extends StatefulWidget {
  const PelangganScreen({super.key});

  @override
  State<PelangganScreen> createState() => _PelangganScreenState();
}

class _PelangganScreenState extends State<PelangganScreen> {
  List<dynamic> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final res = await ApiClient.call('getPelanggan', {});
    if (!mounted) return;
    setState(() {
      _data = res.isSuccess ? res.data : [];
      _loading = false;
    });
  }

  void _bukaForm([Map<String, dynamic>? p]) {
    final nama = TextEditingController(text: p?['nama']?.toString() ?? '');
    final hp = TextEditingController(text: p?['hp']?.toString() ?? '');
    final alamat = TextEditingController(text: p?['alamat']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p == null ? 'Pelanggan Baru' : 'Edit Pelanggan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama')),
            TextField(controller: hp, decoration: const InputDecoration(labelText: 'No. HP')),
            TextField(controller: alamat, decoration: const InputDecoration(labelText: 'Alamat')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (nama.text.trim().isEmpty) return;
              final payload = <String, dynamic>{'nama': nama.text, 'hp': hp.text, 'alamat': alamat.text};
              if (p != null) payload['id'] = p['id'];
              final res = await ApiClient.call(p != null ? 'updatePelanggan' : 'addPelanggan', payload);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (!res.isSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${res.message}')));
              }
              _muat();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _hapus(dynamic id) async {
    final res = await ApiClient.call('deletePelanggan', {'id': id});
    if (!res.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${res.message}')));
    }
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView.builder(
                itemCount: _data.length,
                itemBuilder: (_, i) {
                  final p = _data[i] as Map<String, dynamic>;
                  final aktif = p['aktif'] == 'Y';
                  return ListTile(
                    title: Text(p['nama'].toString()),
                    subtitle: Text('${p['hp']} • ${p['alamat']}'),
                    leading: Icon(Icons.person, color: aktif ? Colors.green : Colors.grey),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => v == 'edit' ? _bukaForm(p) : _hapus(p['id']),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'hapus', child: Text('Nonaktifkan')),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(onPressed: () => _bukaForm(), child: const Icon(Icons.add)),
    );
  }
}
