import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'kasir_screen.dart';
import 'produk_screen.dart';
import 'kategori_screen.dart';
import 'pelanggan_screen.dart';
import 'pembelian_screen.dart';
import 'piutang_screen.dart';
import 'laporan_screen.dart';
import 'rekap_harian_screen.dart';
import 'users_screen.dart';
import 'pengaturan_screen.dart';

class _MenuItem {
  final String label;
  final IconData icon;
  final Widget screen;
  const _MenuItem(this.label, this.icon, this.screen);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    _MenuItem('Kasir', Icons.point_of_sale, KasirScreen()),
    _MenuItem('Produk', Icons.inventory_2, ProdukScreen()),
    _MenuItem('Kategori', Icons.category, KategoriScreen()),
    _MenuItem('Pelanggan', Icons.people, PelangganScreen()),
    _MenuItem('Piutang', Icons.request_quote, PiutangScreen()),
    _MenuItem('Laporan', Icons.receipt_long, LaporanScreen()),
  ];

  static const _adminItems = [
    _MenuItem('Stok Masuk', Icons.move_to_inbox, PembelianScreen()),
    _MenuItem('Rekap Harian', Icons.summarize, RekapHarianScreen()),
    _MenuItem('Users', Icons.admin_panel_settings, UsersScreen()),
    _MenuItem('Pengaturan', Icons.settings, PengaturanScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isAdmin = auth.role == 'admin';
    final menu = isAdmin ? [..._items, ..._adminItems] : _items;
    final activeIndex = _index < menu.length ? _index : 0;

    return Scaffold(
      appBar: AppBar(title: Text(menu[activeIndex].label)),
      drawer: Drawer(
  child: ListView(
    padding: EdgeInsets.zero,
    children: [
      DrawerHeader(
        decoration: const BoxDecoration(
          color: Color(0xFF1565C0), // warna header
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(
              Icons.storefront,
              color: Colors.white,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              auth.user?['username']?.toString() ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              auth.role,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),

      for (var i = 0; i < menu.length; i++)
        ListTile(
          leading: Icon(
            menu[i].icon,
            color: i == activeIndex
                ? const Color(0xFF1565C0)
                : Colors.grey.shade700,
          ),
          title: Text(
            menu[i].label,
            style: TextStyle(
              color: i == activeIndex
                  ? const Color(0xFF1565C0)
                  : Colors.black87,
              fontWeight: i == activeIndex
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          selected: i == activeIndex,
          selectedTileColor: const Color(0xFFE3F2FD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 3,
          ),
          onTap: () {
            setState(() => _index = i);
            Navigator.pop(context);
          },
        ),

      const Divider(),

      ListTile(
        leading: const Icon(
          Icons.logout,
          color: Colors.red,
        ),
        title: const Text(
          'Keluar',
          style: TextStyle(
            color: Colors.red,
          ),
        ),
        onTap: () => auth.logout(),
      ),
    ],
  ),
),
      body: IndexedStack(
        index: activeIndex,
        children: [for (final m in menu) m.screen],
      ),
    );
  }
}
