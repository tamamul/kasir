import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/data_cache.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

void main() {
  ApiClient.init(AppConfig.appsScriptUrl);
  runApp(const KasirApp());
}

class KasirApp extends StatelessWidget {
  const KasirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..loadFromStorage()),
        ChangeNotifierProvider(create: (_) => DataCache()),
      ],
      child: MaterialApp(
        title: 'Kasir MARSA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2E7D32),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _cacheStarted = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cache = context.read<DataCache>();
    if (auth.isLoggedIn && !_cacheStarted) {
      _cacheStarted = true;
      cache.loadFromDisk();
      cache.startBackgroundSync();
    } else if (!auth.isLoggedIn && _cacheStarted) {
      _cacheStarted = false;
      cache.stopBackgroundSync();
    }

    return auth.isLoggedIn ? const HomeShell() : const LoginScreen();
  }
}
