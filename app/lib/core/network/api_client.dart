import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<dynamic> get(String path) => _send(() => _client.get(_uri(path)));

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) => _send(
        () => _client.post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body ?? const <String, dynamic>{}),
        ),
      );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _send(Future<http.Response> Function() run) async {
    final res = await run();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }
}
