import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/data_cache.dart';
import '../utils/format.dart';

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  List<dynamic> _produk = [];
  List<dynamic> _kategori = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final resProduk = await ApiClient.call('getProduk', {});
    final resKategori = await ApiClient.call('getKategori', {});
    if (!mounted) return;
    setState(() {
      _produk = resProduk.isSuccess ? resProduk.data : [];
      _kategori = resKategori.isSuccess ? resKategori.data : [];
      _loading = false;
    });
    // Sinkronkan juga cache lokal yang dipakai layar kasir, biar produk
    // yang baru ditambah/diubah langsung kelihatan di sana tanpa nunggu
    // siklus background sync berikutnya.
    if (mounted) context.read<DataCache>().sync();
  }

  void _bukaForm([Map<String, dynamic>? p]) {
    showDialog(
      context: context,
      builder: (_) => _FormProduk(produk: p, onSaved: _muat),
    );
  }

  Future<void> _hapus(dynamic id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nonaktifkan produk ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiClient.call('deleteProduk', {'id': id});
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
              child: _produk.isEmpty
                  ? ListView(children: const [
                      Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada produk'))),
                    ])
                  : ListView.builder(
                      itemCount: _produk.length,
                      itemBuilder: (_, i) {
                        final p = _produk[i] as Map<String, dynamic>;
                        final aktif = p['aktif'] == 'Y';
                        return ListTile(
                          title: Text(p['nama'].toString()),
                          subtitle: Text('${p['kategori']} • ${rupiah(p['harga_jual'])} • Stok: ${p['stok']}'),
                          leading: CircleAvatar(
                            backgroundColor: aktif ? Colors.green.shade100 : Colors.grey.shade300,
                            child: Icon(Icons.inventory_2, color: aktif ? Colors.green : Colors.grey),
                          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _bukaForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FormProduk extends StatefulWidget {
  final Map<String, dynamic>? produk;
  final VoidCallback onSaved;
  const _FormProduk({this.produk, required this.onSaved});

  @override
  State<_FormProduk> createState() => _FormProdukState();
}

class _FormProdukState extends State<_FormProduk> {
  late TextEditingController _barcode;
  late TextEditingController _nama;
  late TextEditingController _kategori;
  late TextEditingController _hargaBeli;
  late TextEditingController _hargaJual;
  late TextEditingController _stok;
  late TextEditingController _satuan;
  bool _aktif = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.produk;
    _barcode = TextEditingController(text: p?['barcode']?.toString() ?? '');
    _nama = TextEditingController(text: p?['nama']?.toString() ?? '');
    _kategori = TextEditingController(text: p?['kategori']?.toString() ?? '');
    _hargaBeli = TextEditingController(text: p?['harga_beli']?.toString() ?? '');
    _hargaJual = TextEditingController(text: p?['harga_jual']?.toString() ?? '');
    _stok = TextEditingController(text: p?['stok']?.toString() ?? '0');
    _satuan = TextEditingController(text: p?['satuan']?.toString() ?? 'Pcs');
    _aktif = p == null || p['aktif'] == 'Y';
  }

  Future<void> _simpan() async {
    if (_nama.text.trim().isEmpty || _hargaJual.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama dan harga jual wajib diisi')));
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'barcode': _barcode.text,
      'nama': _nama.text,
      'kategori': _kategori.text,
      'harga_beli': _hargaBeli.text,
      'harga_jual': _hargaJual.text,
      'stok': _stok.text,
      'satuan': _satuan.text,
      'aktif': _aktif ? 'Y' : 'N',
    };
    final id = widget.produk?['id'];
    if (id != null) payload['id'] = id;
    final res = await ApiClient.call(id != null ? 'updateProduk' : 'addProduk', payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${res.message}')));
      return;
    }
    Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.produk == null ? 'Produk Baru' : 'Edit Produk'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barcode')),
            TextField(controller: _nama, decoration: const InputDecoration(labelText: 'Nama')),
            TextField(controller: _kategori, decoration: const InputDecoration(labelText: 'Kategori')),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _hargaBeli,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga Beli'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _hargaJual,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga Jual'))),
            ]),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _stok,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stok'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _satuan, decoration: const InputDecoration(labelText: 'Satuan'))),
            ]),
            CheckboxListTile(
              value: _aktif,
              onChanged: (v) => setState(() => _aktif = v ?? true),
              title: const Text('Aktif'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: _saving ? null : _simpan,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
