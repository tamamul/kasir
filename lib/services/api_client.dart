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

    // Sama persis dengan PHP
    body['action'] = action;

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
      final response = await _request(jsonBody);

      final raw = response.body.trim();

      debugPrint('========== API RESPONSE ==========');
      debugPrint('HTTP : ${response.statusCode}');
      debugPrint(
        'TYPE : ${response.headers['content-type']}',
      );
      debugPrint('BODY : ${_limit(raw)}');

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
      } catch (_) {
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
      debugPrint('CLIENT ERROR: $e');

      return ApiResponse(
        status: 'error',
        message: 'Koneksi server gagal: $e',
      );
    } on FormatException catch (e) {
      debugPrint('FORMAT ERROR: $e');

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

  static Future<http.Response> _request(String body) async {
    final client = http.Client();

    try {
      // ==========================================================
      // REQUEST PERTAMA
      // POST -> script.google.com
      // ==========================================================

      var request = http.Request(
        'POST',
        Uri.parse(baseUrl),
      );

      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';

      request.body = body;

      // Kita tangani redirect sendiri.
      request.followRedirects = false;

      var streamed = await client.send(request);

      debugPrint(
        'INITIAL HTTP: ${streamed.statusCode}',
      );

      // ==========================================================
      // REDIRECT GOOGLE APPS SCRIPT
      // ==========================================================

      if (_isRedirect(streamed.statusCode)) {
        final location = streamed.headers['location'];

        debugPrint(
          'REDIRECT TO: $location',
        );

        if (location == null || location.isEmpty) {
          return await http.Response.fromStream(streamed);
        }

        // Buang stream response 302 sebelum request berikutnya.
        await streamed.stream.drain();

        Uri nextUrl = Uri.parse(location);

        // ========================================================
        // PENTING:
        //
        // Google Apps Script redirect HARUS dilanjutkan dengan GET.
        //
        // Jangan POST lagi.
        // ========================================================

        for (int i = 0; i < 5; i++) {
          debugPrint(
            'FOLLOW REDIRECT [$i]: $nextUrl',
          );

          final getRequest = http.Request(
            'GET',
            nextUrl,
          );

          getRequest.headers['Accept'] =
              'application/json';

          getRequest.followRedirects = false;

          streamed = await client.send(getRequest);

          debugPrint(
            'REDIRECT RESPONSE [$i]: '
            '${streamed.statusCode}',
          );

          // Sudah bukan redirect.
          if (!_isRedirect(streamed.statusCode)) {
            return await http.Response.fromStream(
              streamed,
            );
          }

          final nextLocation =
              streamed.headers['location'];

          if (nextLocation == null ||
              nextLocation.isEmpty) {
            return await http.Response.fromStream(
              streamed,
            );
          }

          await streamed.stream.drain();

          nextUrl = nextUrl.resolve(nextLocation);
        }

        throw Exception(
          'Terlalu banyak redirect Google Apps Script.',
        );
      }

      // Tidak redirect
      return await http.Response.fromStream(
        streamed,
      );
    } finally {
      client.close();
    }
  }

  static bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  static String _limit(String text) {
    if (text.length <= 1500) {
      return text;
    }

    return '${text.substring(0, 1500)}...';
  }
}