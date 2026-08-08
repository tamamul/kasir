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

    body['action'] = action;

    if (token != null &&
        token!.isNotEmpty &&
        !body.containsKey('token')) {
      body['token'] = token;
    }

    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      final responseBody = response.body.trim();

      // Debug untuk melihat respons Apps Script
      debugPrint('========== API DEBUG ==========');
      debugPrint('URL       : $baseUrl');
      debugPrint('ACTION    : $action');
      debugPrint('HTTP      : ${response.statusCode}');
      debugPrint(
        'CONTENT   : ${response.headers['content-type']}',
      );
      debugPrint(
        'RESPONSE  : ${_potong(responseBody)}',
      );
      debugPrint('===============================');

      // HTTP error
      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return ApiResponse(
          status: 'error',
          message:
              'HTTP ${response.statusCode}: ${_potong(responseBody)}',
        );
      }

      // Respons kosong
      if (responseBody.isEmpty) {
        return ApiResponse(
          status: 'error',
          message: 'Server memberikan respons kosong.',
        );
      }

      // Server mengembalikan HTML
      if (_isHtml(responseBody)) {
        return ApiResponse(
          status: 'error',
          message:
              'Server mengembalikan HTML, bukan JSON.\n\n'
              '${_potong(responseBody)}',
        );
      }

      // Parse JSON
      dynamic decoded;

      try {
        decoded = jsonDecode(responseBody);
      } catch (e) {
        return ApiResponse(
          status: 'error',
          message:
              'Respons server bukan JSON.\n\n'
              '${_potong(responseBody)}',
        );
      }

      // JSON harus object
      if (decoded is! Map) {
        return ApiResponse(
          status: 'error',
          message:
              'Format JSON server tidak valid.',
        );
      }

      return ApiResponse.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on FormatException catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Format respons server tidak valid: $e',
      );
    } on http.ClientException catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Koneksi ke server gagal: $e',
      );
    } catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Gagal menghubungi server: $e',
      );
    }
  }

  static bool _isHtml(String body) {
    final lower = body.toLowerCase();

    return lower.startsWith('<!doctype html') ||
        lower.startsWith('<html') ||
        lower.startsWith('<head') ||
        lower.startsWith('<script') ||
        lower.contains('<html');
  }

  static String _potong(String text) {
    if (text.length <= 500) {
      return text;
    }

    return '${text.substring(0, 500)}...';
  }
}