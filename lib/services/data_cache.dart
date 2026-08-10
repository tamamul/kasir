import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Cache lokal buat produk/kategori/pelanggan. Dimuat instan dari disk
/// begitu app dibuka (tanpa nunggu network), lalu sinkron ke server di
/// background secara berkala. Layar kasir cari produk dari cache ini
/// (instan, tidak nunggu network tiap ketik), bukan manggil API tiap kali.
class DataCache extends ChangeNotifier {
  List<dynamic> produk = [];
  List<dynamic> kategori = [];
  List<dynamic> pelanggan = [];
  DateTime? lastSync;
  bool syncing = false;
  Timer? _timer;

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString('cache_produk');
    final k = prefs.getString('cache_kategori');
    final c = prefs.getString('cache_pelanggan');
    if (p != null) produk = jsonDecode(p);
    if (k != null) kategori = jsonDecode(k);
    if (c != null) pelanggan = jsonDecode(c);
    notifyListeners();

    // Langsung sinkron di background begitu app dibuka, tapi UI sudah
    // bisa dipakai duluan pakai data cache di atas. Sengaja tidak di-await.
    // ignore: unawaited_futures
    sync();
  }

  Future<void> sync() async {
    if (syncing) return;
    syncing = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiClient.call('getProduk', {}),
        ApiClient.call('getKategori', {}),
        ApiClient.call('getPelanggan', {}),
      ]);

      final prefs = await SharedPreferences.getInstance();
      if (results[0].isSuccess) {
        produk = results[0].data;
        await prefs.setString('cache_produk', jsonEncode(produk));
      }
      if (results[1].isSuccess) {
        kategori = results[1].data;
        await prefs.setString('cache_kategori', jsonEncode(kategori));
      }
      if (results[2].isSuccess) {
        pelanggan = results[2].data;
        await prefs.setString('cache_pelanggan', jsonEncode(pelanggan));
      }
      lastSync = DateTime.now();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void startBackgroundSync({Duration interval = const Duration(minutes: 2)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => sync());
  }

  void stopBackgroundSync() {
    _timer?.cancel();
  }

  List<dynamic> searchProduk(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return [];
    return produk.where((p) {
      final nama = (p['nama'] ?? '').toString().toLowerCase();
      final aktif = (p['aktif'] ?? 'Y').toString() == 'Y';
      return aktif && nama.contains(query);
    }).toList();
  }

  Map<String, dynamic>? produkByBarcode(String barcode) {
    for (final p in produk) {
      if ((p['barcode'] ?? '').toString() == barcode) return Map<String, dynamic>.from(p);
    }
    return null;
  }

  /// Update stok di cache lokal SEGERA setelah transaksi sukses, supaya UI
  /// langsung mencerminkan stok terbaru tanpa nunggu siklus sync berikutnya.
  /// Nilai ini otomatis dikoreksi ulang begitu sync() jalan lagi.
  void applyLocalStokChange(dynamic produkId, int delta) {
    final idx = produk.indexWhere((p) => p['id'].toString() == produkId.toString());
    if (idx != -1) {
      final current = int.tryParse(produk[idx]['stok'].toString()) ?? 0;
      produk[idx] = Map<String, dynamic>.from(produk[idx])..['stok'] = current + delta;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
