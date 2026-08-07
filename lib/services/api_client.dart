import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse {
  final String status;
  final dynamic data;
  final String? message;

  ApiResponse({required this.status, this.data, this.message});

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
    baseUrl = url;
  }

  static Future<ApiResponse> call(String action, [Map<String, dynamic> params = const {}]) async {
    final body = Map<String, dynamic>.from(params);
    body['action'] = action;
    if (token != null && !body.containsKey('token')) {
      body['token'] = token;
    }

    try {
      final response = await _postFollowingRedirect(Uri.parse(baseUrl), jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(response.body);
      return ApiResponse.fromJson(decoded);
    } catch (e) {
      return ApiResponse(status: 'error', message: 'Gagal menghubungi server: $e');
    }
  }

  // Apps Script kadang membalas 302 (redirect ke googleusercontent.com) untuk
  // POST. http.Client bawaan akan mengubah method jadi GET saat mengikuti
  // redirect otomatis (sesuai spesifikasi HTTP untuk 301/302), yang bikin
  // body JSON kita hilang. Di sini redirect-nya ditangani manual supaya
  // method POST + body tetap terkirim ke URL barunya.
  static Future<http.Response> _postFollowingRedirect(Uri url, String body) async {
    final client = http.Client();
    try {
      var request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = body
        ..followRedirects = false;

      var streamed = await client.send(request);

      if (streamed.statusCode == 301 || streamed.statusCode == 302 || streamed.statusCode == 303) {
        final location = streamed.headers['location'];
        if (location != null) {
          final redirectRequest = http.Request('POST', Uri.parse(location))
            ..headers['Content-Type'] = 'application/json'
            ..body = body;
          streamed = await client.send(redirectRequest);
        }
      }

      return await http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }
}
