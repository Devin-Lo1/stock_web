import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _requestTimeout = Duration(seconds: 12);

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final http.Client _httpClient;
  final String baseUrl;

  Future<Object?> get(String path, {Map<String, String>? query}) async {
    return _send(() => _httpClient.get(_uri(path, query)));
  }

  Future<Object?> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? query,
  }) async {
    return _send(
      () => _httpClient.post(
        _uri(path, query),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
  }

  Future<Object?> put(String path, Map<String, dynamic> body) async {
    return _send(
      () => _httpClient.put(
        _uri(path),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
  }

  Future<void> delete(String path) async {
    await _send(() => _httpClient.delete(_uri(path)));
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

  Future<Object?> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_requestTimeout);
      return _decode(response);
    } on TimeoutException catch (error) {
      throw ApiException(
        statusCode: 0,
        code: 'NETWORK_TIMEOUT',
        message: '请求后端超时',
        detail: {'reason': error.message ?? 'timeout'},
      );
    } on SocketException catch (error) {
      throw ApiException(
        statusCode: 0,
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接后端',
        detail: {'reason': error.message},
      );
    }
  }

  Object? _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _decodeError(response);
    }

    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  ApiException _decodeError(http.Response response) {
    if (response.body.isEmpty) {
      return ApiException(
        statusCode: response.statusCode,
        code: 'HTTP_${response.statusCode}',
        message: response.reasonPhrase ?? '请求失败',
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final envelope = decoded is Map<String, dynamic>
          ? decoded['detail']
          : null;
      if (envelope is Map<String, dynamic>) {
        return ApiException(
          statusCode: response.statusCode,
          code: _readString(envelope['code']) ?? 'HTTP_${response.statusCode}',
          message:
              _readString(envelope['message']) ??
              response.reasonPhrase ??
              '请求失败',
          detail: _readMap(envelope['detail']),
        );
      }
      return ApiException(
        statusCode: response.statusCode,
        code: 'HTTP_${response.statusCode}',
        message: decoded is Map<String, dynamic>
            ? _readString(decoded['detail']) ?? decoded.toString()
            : decoded.toString(),
      );
    } on FormatException {
      return ApiException(
        statusCode: response.statusCode,
        code: 'HTTP_${response.statusCode}',
        message: response.body,
      );
    }
  }

  static String? _readString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static Map<String, Object?> _readMap(Object? value) {
    if (value is Map<String, dynamic>) return value.cast<String, Object?>();
    return const {};
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.detail = const {},
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, Object?> detail;

  bool get isNetworkError =>
      code == 'NETWORK_TIMEOUT' || code == 'NETWORK_UNAVAILABLE';

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
