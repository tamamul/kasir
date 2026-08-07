import 'package:flutter/material.dart';
import '../services/api_client.dart';

class KategoriScreen extends StatefulWidget {
  const KategoriScreen({super.key});

  @override
  State<KategoriScreen> createState() => _KategoriScreenState();
}

class _KategoriScreenState extends State<KategoriScreen> {
  List<dynamic> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final res = await ApiClient.call('getKategori', {});
    if (!mounted) return;
    setState(() {
      _data = res.isSuccess ? res.data : [];
      _loading = false;
    });
  }

  void _bukaForm([Map<String, dynamic>? k]) {
    final ctrl = TextEditingController(text: k?['nama']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(k == null ? 'Kategori Baru' : 'Edit Kategori'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nama')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final payload = <String, dynamic>{'nama': ctrl.text};
              if (k != null) payload['id'] = k['id'];
              final res = await ApiClient.call(k != null ? 'updateKategori' : 'addKategori', payload);
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
    final res = await ApiClient.call('deleteKategori', {'id': id});
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
                  final k = _data[i] as Map<String, dynamic>;
                  return ListTile(
                    title: Text(k['nama'].toString()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _bukaForm(k)),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () => _hapus(k['id'])),
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
