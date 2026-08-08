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

    final jsonBody = jsonEncode(body);

    debugPrint('================================');
    debugPrint('API ACTION : $action');
    debugPrint('API URL    : $baseUrl');
    debugPrint('API BODY   : $jsonBody');
    debugPrint('================================');

    try {
      final response = await _postAppsScript(
        Uri.parse(baseUrl),
        jsonBody,
      );

      final raw = response.body.trim();

      debugPrint('API HTTP   : ${response.statusCode}');
      debugPrint('API TYPE   : ${response.headers['content-type']}');
      debugPrint('API BODY   : ${_limit(raw)}');

      if (raw.isEmpty) {
        return ApiResponse(
          status: 'error',
          message:
              'Server tidak memberikan response.\n'
              'HTTP: ${response.statusCode}',
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
    } on Exception catch (e) {
      debugPrint('API ERROR: $e');

      return ApiResponse(
        status: 'error',
        message: 'Gagal menghubungi server: $e',
      );
    }
  }

  static Future<http.Response> _postAppsScript(
    Uri url,
    String body,
  ) async {
    final client = http.Client();

    try {
      Uri currentUrl = url;

      for (int redirect = 0; redirect < 5; redirect++) {
        debugPrint('POST → $currentUrl');

        final request = http.Request(
          'POST',
          currentUrl,
        );

        request.headers['Content-Type'] =
            'application/json; charset=utf-8';

        request.headers['Accept'] =
            'application/json';

        request.body = body;

        request.followRedirects = false;

        final streamed = await client.send(request);

        debugPrint(
          'HTTP ${streamed.statusCode} ← $currentUrl',
        );

        if (streamed.statusCode >= 300 &&
            streamed.statusCode < 400) {
          final location = streamed.headers['location'];

          debugPrint('REDIRECT → $location');

          if (location == null || location.isEmpty) {
            return await http.Response.fromStream(streamed);
          }

          currentUrl = Uri.parse(location);

          continue;
        }

        return await http.Response.fromStream(streamed);
      }

      throw Exception(
        'Terlalu banyak redirect Apps Script.',
      );
    } finally {
      client.close();
    }
  }

  static String _limit(String text) {
    if (text.length <= 1000) {
      return text;
    }

    return '${text.substring(0, 1000)}...';
  }
}