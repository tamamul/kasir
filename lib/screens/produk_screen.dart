import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/data_cache.dart';
import '../utils/format.dart';

enum _Urutan { namaAZ, stokTerendah, stokTertinggi, terbaru }

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  final _searchCtrl = TextEditingController();
  String? _filterKategori; // null = semua kategori
  String _filterStatus = 'Y'; // 'Y' aktif, 'N' nonaktif, 'ALL' semua
  _Urutan _urutan = _Urutan.namaAZ;

  List<dynamic> _terapkanFilter(List<dynamic> produk) {
    var hasil = produk.where((p) {
      if (_filterStatus != 'ALL' && (p['aktif'] ?? 'Y').toString() != _filterStatus) return false;
      if (_filterKategori != null && (p['kategori'] ?? '').toString() != _filterKategori) return false;
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final nama = (p['nama'] ?? '').toString().toLowerCase();
      final id = (p['id'] ?? '').toString();
      final barcode = (p['barcode'] ?? '').toString().toLowerCase();
      return nama.contains(q) || id == q || barcode.contains(q);
    }).toList();

    switch (_urutan) {
      case _Urutan.namaAZ:
        hasil.sort((a, b) => (a['nama'] ?? '').toString().compareTo((b['nama'] ?? '').toString()));
        break;
      case _Urutan.stokTerendah:
        hasil.sort((a, b) => (int.tryParse(a['stok'].toString()) ?? 0).compareTo(int.tryParse(b['stok'].toString()) ?? 0));
        break;
      case _Urutan.stokTertinggi:
        hasil.sort((a, b) => (int.tryParse(b['stok'].toString()) ?? 0).compareTo(int.tryParse(a['stok'].toString()) ?? 0));
        break;
      case _Urutan.terbaru:
        hasil.sort((a, b) => (int.tryParse(b['id'].toString()) ?? 0).compareTo(int.tryParse(a['id'].toString()) ?? 0));
        break;
    }
    return hasil;
  }

  void _bukaForm(DataCache cache, [Map<String, dynamic>? p]) {
    showDialog(
      context: context,
      builder: (_) => _FormProduk(produk: p, onSaved: () => cache.sync()),
    );
  }

  Future<void> _hapus(DataCache cache, dynamic id) async {
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
    cache.sync();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataCache>(
      builder: (context, cache, _) {
        final hasil = _terapkanFilter(cache.produk);
        final daftarKategori = cache.kategori.map((k) => k['nama'].toString()).toSet().toList()..sort();

        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari nama, ID, atau barcode...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: cache.syncing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chipFilterStatus('Aktif', 'Y'),
                      const SizedBox(width: 6),
                      _chipFilterStatus('Nonaktif', 'N'),
                      const SizedBox(width: 6),
                      _chipFilterStatus('Semua', 'ALL'),
                      const SizedBox(width: 12),
                      DropdownButton<String?>(
                        value: _filterKategori,
                        hint: const Text('Semua kategori'),
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Semua kategori')),
                          ...daftarKategori.map((k) => DropdownMenuItem<String?>(value: k, child: Text(k))),
                        ],
                        onChanged: (v) => setState(() => _filterKategori = v),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<_Urutan>(
                        value: _urutan,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: _Urutan.namaAZ, child: Text('Nama A-Z')),
                          DropdownMenuItem(value: _Urutan.stokTerendah, child: Text('Stok terendah')),
                          DropdownMenuItem(value: _Urutan.stokTertinggi, child: Text('Stok tertinggi')),
                          DropdownMenuItem(value: _Urutan.terbaru, child: Text('Baru ditambah')),
                        ],
                        onChanged: (v) => setState(() => _urutan = v ?? _Urutan.namaAZ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${hasil.length} produk', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: cache.produk.isEmpty && cache.syncing
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => cache.sync(),
                        child: hasil.isEmpty
                            ? ListView(children: const [
                                Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Tidak ada produk yang cocok'))),
                              ])
                            : ListView.builder(
                                itemCount: hasil.length,
                                itemBuilder: (_, i) {
                                  final p = hasil[i] as Map<String, dynamic>;
                                  final aktif = p['aktif'] == 'Y';
                                  final stok = int.tryParse(p['stok'].toString()) ?? 0;
                                  return ListTile(
                                    title: Text(p['nama'].toString()),
                                    subtitle: Text('${p['kategori']} • ${rupiah(p['harga_jual'])} • ID: ${p['id']}'),
                                    leading: CircleAvatar(
                                      backgroundColor: !aktif
                                          ? Colors.grey.shade300
                                          : stok <= 0
                                              ? Colors.red.shade100
                                              : Colors.green.shade100,
                                      child: Icon(Icons.inventory_2,
                                          color: !aktif ? Colors.grey : (stok <= 0 ? Colors.red : Colors.green)),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Stok: $stok', style: TextStyle(color: stok <= 0 ? Colors.red : null)),
                                        PopupMenuButton<String>(
                                          onSelected: (v) => v == 'edit' ? _bukaForm(cache, p) : _hapus(cache, p['id']),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                                            PopupMenuItem(value: 'hapus', child: Text('Nonaktifkan')),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _bukaForm(cache),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _chipFilterStatus(String label, String value) {
    final selected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filterStatus = value),
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
