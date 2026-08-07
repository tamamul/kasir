import 'package:flutter/material.dart';
import '../services/api_client.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final res = await ApiClient.call('getUsers', {});
    if (!mounted) return;
    setState(() {
      _data = res.isSuccess ? res.data : [];
      _loading = false;
    });
  }

  void _bukaForm([Map<String, dynamic>? u]) {
    final username = TextEditingController(text: u?['username']?.toString() ?? '');
    final password = TextEditingController();
    String role = u?['role']?.toString() ?? 'kasir';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(u == null ? 'User Baru' : 'Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: u == null ? 'Password' : 'Password (kosongkan jika tidak ganti)'),
              ),
              DropdownButtonFormField<String>(
  value: role,
  decoration: const InputDecoration(labelText: 'Role'),
  items: const [
    DropdownMenuItem(
      value: 'kasir',
      child: Text('Kasir'),
    ),
    DropdownMenuItem(
      value: 'admin',
      child: Text('Admin'),
    ),
  ],
  onChanged: (v) {
    setLocal(() {
      role = v ?? 'kasir';
    });
  },
),
          ],
        ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (username.text.trim().isEmpty) return;
                if (u == null && password.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Password wajib diisi untuk user baru')));
                  return;
                }
                final payload = <String, dynamic>{'username': username.text, 'role': role};
                if (password.text.trim().isNotEmpty) payload['password'] = password.text;
                if (u != null) payload['id'] = u['id'];
                final res = await ApiClient.call(u != null ? 'updateUser' : 'addUser', payload);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!res.isSuccess && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${res.message}')));
                }
                _muat();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hapus(dynamic id) async {
    final res = await ApiClient.call('deleteUser', {'id': id});
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
                  final u = _data[i] as Map<String, dynamic>;
                  final aktif = u['aktif'] == 'Y';
                  return ListTile(
                    title: Text(u['username'].toString()),
                    subtitle: Text(u['role'].toString()),
                    leading: Icon(Icons.account_circle, color: aktif ? Colors.green : Colors.grey),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => v == 'edit' ? _bukaForm(u) : _hapus(u['id']),
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
