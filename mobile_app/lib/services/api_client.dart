import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final http.Client _httpClient;
  final String baseUrl;

  Future<Object?> get(String path, {Map<String, String>? query}) async {
    final response = await _httpClient.get(_uri(path, query));
    return _decode(response);
  }

  Future<Object?> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? query,
  }) async {
    final response = await _httpClient.post(
      _uri(path, query),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Object?> put(String path, Map<String, dynamic> body) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await _httpClient.delete(_uri(path));
    _decode(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$normalizedBaseUrl$normalizedPath',
    ).replace(queryParameters: query);
  }

  Object? _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.body.isEmpty ? response.reasonPhrase : response.body,
      );
    }

    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String? message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
