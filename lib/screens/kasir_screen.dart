```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/data_cache.dart';
import '../services/auth_service.dart';
import '../models/receipt_data.dart';
import '../utils/format.dart';
import 'barcode_scanner_screen.dart';
import 'struk_preview_screen.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _CartItem {
  final int produkId;
  final String nama;
  final double harga;
  int qty;

  _CartItem({
    required this.produkId,
    required this.nama,
    required this.harga,
    this.qty = 1,
  });

  double get subtotal => harga * qty;
}

class _KasirScreenState extends State<KasirScreen> {
  final _searchCtrl = TextEditingController();
  final _bayarCtrl = TextEditingController();
  final _pelangganCtrl = TextEditingController();

  final List<_CartItem> _cart = [];

  bool _loadingBayar = false;

  double get _total =>
      _cart.fold(0, (sum, i) => sum + i.subtotal);

  double get _kembali =>
      (double.tryParse(_bayarCtrl.text) ?? 0) - _total;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bayarCtrl.dispose();
    _pelangganCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // SCANNER
  // ============================================================

  Future<void> _bukaScanner() async {
    final hasil = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (hasil != null) {
      _scanBarcode(hasil);
    }
  }

  void _scanBarcode(String barcode) {
    if (barcode.trim().isEmpty) return;

    final cache = context.read<DataCache>();
    final produk = cache.produkByBarcode(barcode.trim());

    if (produk != null) {
      _tambahKeKeranjang(produk);
      _searchCtrl.clear();

      setState(() {});
    } else {
      _searchCtrl.text = barcode.trim();

      setState(() {});

      _snack(
        'Barcode "$barcode" tidak ditemukan persis — '
        'menampilkan hasil pencarian terdekat',
      );
    }
  }

  // ============================================================
  // KERANJANG
  // ============================================================

  void _tambahKeKeranjang(Map<String, dynamic> produk) {
    final id = int.parse(produk['id'].toString());

    final existing =
        _cart.where((i) => i.produkId == id);

    setState(() {
      if (existing.isNotEmpty) {
        existing.first.qty += 1;
      } else {
        _cart.add(
          _CartItem(
            produkId: id,
            nama: produk['nama'].toString(),
            harga: double.parse(
              produk['harga_jual'].toString(),
            ),
          ),
        );
      }
    });
  }

  void _ubahQty(_CartItem item, int delta) {
    setState(() {
      item.qty += delta;

      if (item.qty <= 0) {
        _cart.remove(item);
      }
    });
  }

  void _hapusItem(_CartItem item) {
    setState(() {
      _cart.remove(item);
    });
  }

  // ============================================================
  // PEMBAYARAN
  // ============================================================

  Future<void> _bayar() async {
    if (_cart.isEmpty) {
      _snack('Keranjang masih kosong');
      return;
    }

    final bayar =
        double.tryParse(_bayarCtrl.text) ?? 0;

    if (bayar < _total) {
      _snack(
        'Uang bayar kurang dari total belanja — '
        'kalau mau nyicil, pakai menu Piutang',
      );
      return;
    }

    setState(() {
      _loadingBayar = true;
    });

    final res = await ApiClient.call(
      'prosesPenjualan',
      {
        'pelanggan': _pelangganCtrl.text,
        'bayar': bayar,
        'items': _cart
            .map(
              (i) => {
                'produk_id': i.produkId,
                'qty': i.qty,
              },
            )
            .toList(),
      },
    );

    if (!mounted) return;

    setState(() {
      _loadingBayar = false;
    });

    if (!res.isSuccess) {
      _snack('Gagal: ${res.message}');
      return;
    }

    final cache = context.read<DataCache>();

    for (final item in _cart) {
      cache.applyLocalStokChange(
        item.produkId,
        -item.qty,
      );
    }

    _bukaStruk(res.data, cache);

    setState(() {
      _cart.clear();
      _bayarCtrl.clear();
      _pelangganCtrl.clear();
    });
  }

  // ============================================================
  // STRUK
  // ============================================================

  void _bukaStruk(
    Map<String, dynamic> data,
    DataCache cache,
  ) {
    final penjualan = data['penjualan'];

    final items = (data['items'] as List<dynamic>)
        .map(
          (i) => ReceiptItem.fromMap(i),
        )
        .toList();

    final pengaturan = cache.pengaturan;

    final kasir =
        context.read<AuthService>().user?['username']
                ?.toString() ??
            '';

    final receipt = ReceiptData(
      namaToko:
          (pengaturan['nama_toko'] ?? 'Toko')
              .toString(),
      alamatToko:
          (pengaturan['alamat'] ?? '').toString(),
      teleponToko:
          (pengaturan['telepon'] ?? '').toString(),
      footerStruk:
          (pengaturan['footer_struk'] ?? '')
              .toString(),
      noNota: penjualan['no_nota'].toString(),
      tanggal: penjualan['tanggal'].toString(),
      namaPelanggan:
          penjualan['pelanggan']?.toString(),
      kasir: kasir,
      items: items,
      total:
          num.tryParse(
                penjualan['total'].toString(),
              ) ??
              0,
      bayar:
          num.tryParse(
                penjualan['bayar'].toString(),
              ) ??
              0,
      kembali:
          num.tryParse(
                penjualan['kembali'].toString(),
              ) ??
              0,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StrukPreviewScreen(data: receipt),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ============================================================
  // RESPONSIVE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // HP kecil
        if (width < 380) {
          return _buildMobileLayout(
            context,
            compact: true,
          );
        }

        // HP normal
        if (width < 700) {
          return _buildMobileLayout(
            context,
            compact: false,
          );
        }

        // Tablet / desktop
        return _buildWideLayout(context);
      },
    );
  }

  // ============================================================
  // LAYOUT HP
  // ============================================================

  Widget _buildMobileLayout(
    BuildContext context, {
    required bool compact,
  }) {
    final height = MediaQuery.sizeOf(context).height;

    // Keranjang mendapat sekitar 42% layar.
    // Tetapi tetap dibatasi agar tidak terlalu besar.
    final cartHeight = (height * 0.42)
        .clamp(
          compact ? 250.0 : 280.0,
          compact ? 330.0 : 380.0,
        );

    return Column(
      children: [
        Expanded(
          child: _buildPencarian(
            compact: compact,
          ),
        ),

        const Divider(
          height: 1,
          thickness: 1,
        ),

        SizedBox(
          height: cartHeight,
          child: _buildKeranjang(
            compact: compact,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LAYOUT TABLET / DESKTOP
  // ============================================================

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildPencarian(
            compact: false,
          ),
        ),

        const VerticalDivider(
          width: 1,
          thickness: 1,
        ),

        Expanded(
          flex: 2,
          child: _buildKeranjang(
            compact: false,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PENCARIAN PRODUK
  // ============================================================

  Widget _buildPencarian({
    required bool compact,
  }) {
    return Consumer<DataCache>(
      builder: (context, cache, _) {
        final hasil =
            cache.searchProduk(_searchCtrl.text);

        final width =
            MediaQuery.sizeOf(context).width;

        final columns = width < 380
            ? 1
            : width < 700
                ? 2
                : width < 1000
                    ? 3
                    : 4;

        return Padding(
          padding: EdgeInsets.all(
            compact ? 8 : 10,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              // SEARCH BAR
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: compact ? 46 : 48,
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: TextStyle(
                          fontSize:
                              compact ? 13 : 14,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Cari nama, ID, atau barcode...',
                          hintStyle: TextStyle(
                            fontSize:
                                compact ? 12 : 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 21,
                          ),
                          border:
                              const OutlineInputBorder(),
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          suffixIcon:
                              cache.syncing
                                  ? const Padding(
                                      padding:
                                          EdgeInsets.all(
                                        12,
                                      ),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                        onSubmitted: _scanBarcode,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  SizedBox(
                    width: compact ? 46 : 48,
                    height: compact ? 46 : 48,
                    child: FilledButton(
                      onPressed: _bukaScanner,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: compact ? 8 : 10,
              ),

              Expanded(
                child: hasil.isEmpty
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(20),
                          child: Text(
                            cache.produk.isEmpty
                                ? 'Menunggu data produk tersinkron...'
                                : 'Cari, scan, atau ketik ID produk untuk mulai',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize:
                                  compact ? 12 : 13,
                            ),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding:
                            const EdgeInsets.only(
                          bottom: 6,
                        ),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,

                          // Tidak terlalu gepeng
                          childAspectRatio:
                              compact ? 1.8 : 2.0,
                        ),
                        itemCount: hasil.length,
                        itemBuilder: (_, i) {
                          final p =
                              hasil[i]
                                  as Map<String, dynamic>;

                          return Card(
                            margin: EdgeInsets.zero,
                            elevation: 1,
                            clipBehavior:
                                Clip.antiAlias,
                            child: InkWell(
                              onTap: () =>
                                  _tambahKeKeranjang(
                                p,
                              ),
                              child: Padding(
                                padding:
                                    EdgeInsets.symmetric(
                                  horizontal:
                                      compact ? 7 : 8,
                                  vertical:
                                      compact ? 5 : 6,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Text(
                                      p['nama']
                                          .toString(),
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize:
                                            compact
                                                ? 12
                                                : 13,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),

                                    const SizedBox(
                                      height: 2,
                                    ),

                                    Text(
                                      rupiah(
                                        p['harga_jual'],
                                      ),
                                      style: TextStyle(
                                        fontSize:
                                            compact
                                                ? 11
                                                : 12,
                                        color:
                                            Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),

                                    Text(
                                      'ID: ${p['id']} • Stok: ${p['stok']}',
                                      style: TextStyle(
                                        color:
                                            Colors.grey,
                                        fontSize:
                                            compact
                                                ? 9
                                                : 10,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // KERANJANG
  // ============================================================

  Widget _buildKeranjang({
    required bool compact,
  }) {
    return Container(
      color: Colors.grey.shade50,
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        compact ? 6 : 8,
        compact ? 8 : 10,
        compact ? 6 : 8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: compact ? 18 : 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Keranjang',
                style: TextStyle(
                  fontSize:
                      compact ? 15 : 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_cart.isNotEmpty)
                Text(
                  '${_cart.length} item',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize:
                        compact ? 10 : 11,
                  ),
                ),
            ],
          ),

          SizedBox(
            height: compact ? 4 : 6,
          ),

          // LIST ITEM
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada item',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _cart.length,
                    itemBuilder: (_, i) {
                      final item = _cart[i];

                      return Card(
                        margin:
                            const EdgeInsets.only(
                          bottom: 4,
                        ),
                        elevation: 0,
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(
                            horizontal:
                                compact ? 7 : 9,
                            vertical:
                                compact ? 3 : 4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      item.nama,
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize:
                                            compact
                                                ? 11
                                                : 12,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                    Text(
                                      '${rupiah(item.harga)} × ${item.qty} = ${rupiah(item.subtotal)}',
                                      style: TextStyle(
                                        color:
                                            Colors.grey,
                                        fontSize:
                                            compact
                                                ? 9
                                                : 10,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // MINUS
                              IconButton(
                                icon: const Icon(
                                  Icons
                                      .remove_circle_outline,
                                ),
                                iconSize:
                                    compact ? 18 : 20,
                                visualDensity:
                                    VisualDensity
                                        .compact,
                                padding: EdgeInsets.zero,
                                constraints:
                                    const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () =>
                                    _ubahQty(
                                  item,
                                  -1,
                                ),
                              ),

                              SizedBox(
                                width:
                                    compact ? 20 : 22,
                                child: Text(
                                  '${item.qty}',
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                    fontSize:
                                        compact
                                            ? 11
                                            : 12,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),

                              // PLUS
                              IconButton(
                                icon: const Icon(
                                  Icons
                                      .add_circle_outline,
                                ),
                                iconSize:
                                    compact ? 18 : 20,
                                visualDensity:
                                    VisualDensity
                                        .compact,
                                padding: EdgeInsets.zero,
                                constraints:
                                    const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () =>
                                    _ubahQty(
                                  item,
                                  1,
                                ),
                              ),

                              // HAPUS
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                iconSize:
                                    compact ? 17 : 19,
                                visualDensity:
                                    VisualDensity
                                        .compact,
                                padding: EdgeInsets.zero,
                                constraints:
                                    const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () =>
                                    _hapusItem(
                                  item,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 6),

          // TOTAL
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize:
                      compact ? 14 : 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              Flexible(
                child: Text(
                  rupiah(_total),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize:
                        compact ? 15 : 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          // PELANGGAN + BAYAR
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: compact ? 40 : 42,
                  child: TextField(
                    controller:
                        _pelangganCtrl,
                    style: TextStyle(
                      fontSize:
                          compact ? 11 : 12,
                    ),
                    decoration:
                        const InputDecoration(
                      labelText: 'Pelanggan',
                      border:
                          OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: SizedBox(
                  height: compact ? 40 : 42,
                  child: TextField(
                    controller: _bayarCtrl,
                    keyboardType:
                        TextInputType.number,
                    style: TextStyle(
                      fontSize:
                          compact ? 11 : 12,
                    ),
                    decoration:
                        const InputDecoration(
                      labelText: 'Bayar',
                      border:
                          OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                    ),
                    onChanged: (_) =>
                        setState(() {}),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          // KEMBALIAN + BAYAR
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Kembali:',
                      style: TextStyle(
                        fontSize:
                            compact ? 10 : 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        rupiah(_kembali),
                        style: TextStyle(
                          fontSize:
                              compact ? 11 : 12,
                          fontWeight:
                              FontWeight.bold,
                        ),
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: compact ? 40 : 42,
                child: FilledButton(
                  onPressed:
                      _loadingBayar
                          ? null
                          : _bayar,
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        Colors.green,
                    padding:
                        EdgeInsets.symmetric(
                      horizontal:
                          compact ? 18 : 24,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        8,
                      ),
                    ),
                  ),
                  child: _loadingBayar
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : Text(
                          'BAYAR',
                          style: TextStyle(
                            fontSize:
                                compact
                                    ? 12
                                    : 13,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```
