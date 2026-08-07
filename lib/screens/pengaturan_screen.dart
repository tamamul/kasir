import 'package:flutter/material.dart';
import '../services/api_client.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  final _namaToko = TextEditingController();
  final _alamat = TextEditingController();
  final _telepon = TextEditingController();
  final _footer = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final res = await ApiClient.call('getPengaturan', {});
    if (!mounted) return;
    if (res.isSuccess) {
      final d = res.data;
      _namaToko.text = d['nama_toko']?.toString() ?? '';
      _alamat.text = d['alamat']?.toString() ?? '';
      _telepon.text = d['telepon']?.toString() ?? '';
      _footer.text = d['footer_struk']?.toString() ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _simpan() async {
    setState(() => _saving = true);
    final res = await ApiClient.call('updatePengaturan', {
      'nama_toko': _namaToko.text,
      'alamat': _alamat.text,
      'telepon': _telepon.text,
      'footer_struk': _footer.text,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(res.isSuccess ? 'Pengaturan disimpan' : 'Gagal: ${res.message}')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _namaToko, decoration: const InputDecoration(labelText: 'Nama Toko', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _alamat, decoration: const InputDecoration(labelText: 'Alamat', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _telepon, decoration: const InputDecoration(labelText: 'Telepon', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
              controller: _footer,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Footer Struk', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _simpan,
              child: _saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
