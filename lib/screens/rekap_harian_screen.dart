import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../utils/format.dart';

class RekapHarianScreen extends StatefulWidget {
  const RekapHarianScreen({super.key});

  @override
  State<RekapHarianScreen> createState() => _RekapHarianScreenState();
}

class _RekapHarianScreenState extends State<RekapHarianScreen> {
  DateTime _tanggal = DateTime.now();
  Map<String, dynamic>? _data;
  bool _loading = true;

  String get _tanggalStr =>
      '${_tanggal.year}-${_tanggal.month.toString().padLeft(2, '0')}-${_tanggal.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final res = await ApiClient.call('getRekapHarian', {'tanggal': _tanggalStr});
    if (!mounted) return;
    setState(() {
      _data = res.isSuccess ? res.data : null;
      _loading = false;
    });
    if (!res.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${res.message}')));
    }
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (hasil != null) {
      setState(() => _tanggal = hasil);
      _muat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(_tanggalStr),
                trailing: TextButton(onPressed: _pilihTanggal, child: const Text('Ganti tanggal')),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_data == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Data tidak tersedia')))
            else
              _buildIsi(_data!),
          ],
        ),
      ),
    );
  }

  Widget _buildIsi(Map<String, dynamic> d) {
    final perKasir = Map<String, dynamic>.from(d['per_kasir'] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _kartu('Total Uang Masuk', rupiah(d['total_uang_masuk']), Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _kartu('Jumlah Transaksi', '${d['jumlah_transaksi']}', Colors.blue)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _kartu('Penjualan Lunas', rupiah(d['total_penjualan_lunas']), Colors.teal)),
            const SizedBox(width: 12),
            Expanded(child: _kartu('Cicilan Diterima', rupiah(d['total_cicilan_diterima']), Colors.indigo)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _kartu('Piutang Baru', rupiah(d['total_piutang_baru']), Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _kartu('Total Pembelian', rupiah(d['total_pembelian']), Colors.orange)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Penjualan per Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (perKasir.isEmpty)
          const Text('Tidak ada transaksi', style: TextStyle(color: Colors.grey))
        else
          Card(
            child: Column(
              children: perKasir.entries
                  .map((e) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(e.key.isEmpty ? '(tanpa nama)' : e.key),
                        trailing: Text(rupiah(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 16),
        if ((d['jumlah_opname'] ?? 0) > 0)
          Card(
            color: Colors.amber.shade50,
            child: ListTile(
              leading: const Icon(Icons.tune, color: Colors.orange),
              title: Text('${d['jumlah_opname']} penyesuaian stok (opname) hari ini'),
            ),
          ),
      ],
    );
  }

  Widget _kartu(String label, String value, Color warna) {
    return Card(
      color: warna.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: warna)),
          ],
        ),
      ),
    );
  }
}
