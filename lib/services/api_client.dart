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

    // Sama seperti PHP:
    // $params['action'] = $action;
    body['action'] = action;

    // Sama seperti PHP:
    // if (!isset($params['token']) && !empty($_SESSION['token']))
    if (token != null &&
        token!.isNotEmpty &&
        !body.containsKey('token')) {
      body['token'] = token;
    }

    final jsonBody = jsonEncode(body);

    debugPrint('================ API REQUEST ================');
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
          .timeout(
            const Duration(seconds: 20),
          );

      debugPrint('================ API RESPONSE ===============');
      debugPrint('HTTP   : ${response.statusCode}');
      debugPrint(
        'TYPE   : ${response.headers['content-type']}',
      );
      debugPrint(
        'BODY   : ${_limit(response.body)}',
      );

      final raw = response.body.trim();

      if (raw.isEmpty) {
        return ApiResponse(
          status: 'error',
          message: 'Server tidak memberikan response.',
        );
      }

      // Jangan langsung jsonDecode.
      // Cek dulu apakah server mengembalikan HTML.
      if (_looksLikeHtml(raw)) {
        return ApiResponse(
          status: 'error',
          message:
              'Apps Script mengembalikan HTML, bukan JSON.\n'
              '${_limit(raw)}',
        );
      }

      dynamic decoded;

      try {
        decoded = jsonDecode(raw);
      } catch (e) {
        return ApiResponse(
          status: 'error',
          message:
              'Response server bukan JSON.\n'
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
    } on FormatException catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Format response tidak valid: $e',
      );
    } on http.ClientException catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Koneksi server gagal: $e',
      );
    } catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Gagal menghubungi server: $e',
      );
    }
  }

  static bool _looksLikeHtml(String body) {
    final text = body.toLowerCase().trim();

    return text.startsWith('<!doctype html') ||
        text.startsWith('<html') ||
        text.startsWith('<head') ||
        text.startsWith('<script') ||
        text.contains('<html');
  }

  static String _limit(String text) {
    if (text.length <= 1000) {
      return text;
    }

    return '${text.substring(0, 1000)}...';
  }
}