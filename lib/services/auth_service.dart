import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  Map<String, dynamic>? user;
  String? token;
  bool ready = false;

  bool get isLoggedIn => token != null;
  String get role => user?['role']?.toString() ?? '';

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      user = jsonDecode(userJson);
    }
    ApiClient.token = token;
    ready = true;
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    final res = await ApiClient.call('login', {'username': username, 'password': password});
    if (!res.isSuccess) return res.message ?? 'Login gagal';

    token = res.data['token'];
    user = res.data['user'];
    ApiClient.token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token!);
    await prefs.setString('user', jsonEncode(user));

    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    if (token != null) {
      await ApiClient.call('logout', {'token': token});
    }
    token = null;
    user = null;
    ApiClient.token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }
}
