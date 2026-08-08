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

    // Sama seperti versi PHP
    body['action'] = action;

    // Token
    if (token != null &&
        token!.isNotEmpty &&
        !body.containsKey('token')) {
      body['token'] = token;
    }

    final jsonBody = jsonEncode(body);

    debugPrint('================================');
    debugPrint('API REQUEST');
    debugPrint('URL    : $baseUrl');
    debugPrint('ACTION : $action');
    debugPrint('BODY   : $jsonBody');
    debugPrint('================================');

    try {
      final response = await _postWithRedirect(
        Uri.parse(baseUrl),
        jsonBody,
      );

      final raw = response.body.trim();

      debugPrint('================================');
      debugPrint('API RESPONSE');
      debugPrint('HTTP : ${response.statusCode}');
      debugPrint(
        'TYPE : ${response.headers['content-type']}',
      );
      debugPrint('BODY : ${_limit(raw)}');
      debugPrint('================================');

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
    } on FormatException catch (e) {
      debugPrint('FORMAT ERROR: $e');

      return ApiResponse(
        status: 'error',
        message: 'Format response tidak valid: $e',
      );
    } on http.ClientException catch (e) {
      debugPrint('CLIENT ERROR: $e');

      return ApiResponse(
        status: 'error',
        message: 'Koneksi server gagal: $e',
      );
    } catch (e) {
      debugPrint('API ERROR: $e');

      return ApiResponse(
        status: 'error',
        message: 'Gagal menghubungi server: $e',
      );
    }
  }

  /// POST ke Google Apps Script.
  ///
  /// Apps Script sering mengembalikan:
  ///
  ///   302 -> script.googleusercontent.com
  ///
  /// Redirect tersebut harus kita ikuti sendiri supaya
  /// POST + JSON body tidak berubah menjadi GET.
  static Future<http.Response> _postWithRedirect(
    Uri url,
    String body,
  ) async {
    final client = http.Client();

    try {
      Uri currentUrl = url;

      const maxRedirects = 8;

      for (int i = 0; i <= maxRedirects; i++) {
        debugPrint('REDIRECT REQUEST [$i]');
        debugPrint(currentUrl.toString());

        final request = http.Request(
          'POST',
          currentUrl,
        );

        request.headers['Content-Type'] = 'application/json';
        request.headers['Accept'] = 'application/json';

        request.body = body;

        // PENTING:
        // Jangan biarkan package http mengubah POST
        // menjadi GET ketika menerima 301/302/303.
        request.followRedirects = false;

        final streamed = await client.send(request);

        final status = streamed.statusCode;

        debugPrint('REDIRECT STATUS [$i] : $status');

        // Bukan redirect → selesai
        if (status != 301 &&
            status != 302 &&
            status != 303 &&
            status != 307 &&
            status != 308) {
          return await http.Response.fromStream(streamed);
        }

        final location = streamed.headers['location'];

        if (location == null || location.isEmpty) {
          return await http.Response.fromStream(streamed);
        }

        // Tutup response sebelum request berikutnya
        await streamed.stream.drain();

        // Bisa berupa URL absolut atau relatif
        currentUrl = currentUrl.resolve(location);

        debugPrint(
          'REDIRECT LOCATION [$i] : $currentUrl',
        );
      }

      throw Exception(
        'Terlalu banyak redirect dari Google Apps Script.',
      );
    } finally {
      client.close();
    }
  }

  static String _limit(String text) {
    if (text.length <= 1500) {
      return text;
    }

    return '${text.substring(0, 1500)}...';
  }
}