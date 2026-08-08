import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiResponse {
  final String status;
  final dynamic data;
  final String? message;

  ApiResponse({
    required this.status,
    this.data,
    this.message,
  });

  bool get isSuccess => status == 'success';

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status']?.toString() ?? 'error',
      data: json['data'],
      message: json['message']?.toString(),
    );
  }
}

class ApiClient {
  static String baseUrl = '';
  static String? token;

  static void init(String url) {
    baseUrl = url.trim();
  }

  static Future<ApiResponse> call(
    String action, [
    Map<String, dynamic> params = const {},
  ]) async {
    final body = Map<String, dynamic>.from(params);

    // Sama seperti PHP
    body['action'] = action;

    // Tambahkan token jika ada
    if (token != null &&
        token!.isNotEmpty &&
        !body.containsKey('token')) {
      body['token'] = token;
    }

    final jsonBody = jsonEncode(body);

    debugPrint('========== API REQUEST ==========');
    debugPrint('URL    : $baseUrl');
    debugPrint('ACTION : $action');
    debugPrint('BODY   : $jsonBody');

    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonBody,
          )
          .timeout(const Duration(seconds: 20));

      final raw = response.body.trim();

      debugPrint('========== API RESPONSE ==========');
      debugPrint('HTTP   : ${response.statusCode}');
      debugPrint('TYPE   : ${response.headers['content-type']}');
      debugPrint('BODY   : ${_limit(raw)}');

      if (raw.isEmpty) {
        return ApiResponse(
          status: 'error',
          message:
              'Server tidak memberikan response. '
              'HTTP ${response.statusCode}',
        );
      }

      dynamic decoded;

      try {
        decoded = jsonDecode(raw);
      } catch (e) {
        return ApiResponse(
          status: 'error',
          message:
              'Response server bukan JSON.\n\n'
              '${_limit(raw)}',
        );
      }

      if (decoded is! Map) {
        return ApiResponse(
          status: 'error',
          message: 'Format JSON server tidak valid.',
        );
      }

      return ApiResponse.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on http.ClientException catch (e) {
      debugPrint('API CLIENT ERROR: $e');

      return ApiResponse(
        status: 'error',
        message: 'Koneksi server gagal: $e',
      );
    } on FormatException catch (e) {
      debugPrint('API FORMAT ERROR: $e');

      return ApiResponse(
        status: 'error',
        message: 'Format response tidak valid: $e',
      );
    } catch (e) {
      debugPrint('API ERROR: $e');

      return ApiResponse(
        status: 'error',
        message: 'Gagal menghubungi server: $e',
      );
    }
  }

  static String _limit(String text) {
    if (text.length <= 1000) {
      return text;
    }

    return '${text.substring(0, 1000)}...';
  }
}