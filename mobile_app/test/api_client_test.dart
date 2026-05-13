import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_mobile/services/api_client.dart';

void main() {
  test('ApiClient parses structured backend errors', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode('''
{
  "detail": {
    "code": "FUTU_UNAVAILABLE",
    "message": "FutuOpenD 不可用或富途接口调用失败",
    "detail": {
      "reason": "connection failed"
    }
  }
}
'''),
          502,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.get('/api/v1/futu/health'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having((error) => error.code, 'code', 'FUTU_UNAVAILABLE')
            .having(
              (error) => error.message,
              'message',
              'FutuOpenD 不可用或富途接口调用失败',
            )
            .having(
              (error) => error.detail['reason'],
              'reason',
              'connection failed',
            ),
      ),
    );
  });

  test('ApiClient keeps legacy backend error text readable', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      httpClient: MockClient((request) async {
        return http.Response('{"detail":"Position not found"}', 404);
      }),
    );

    await expectLater(
      client.get('/api/v1/positions/missing'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.code, 'code', 'HTTP_404')
            .having((error) => error.message, 'message', 'Position not found'),
      ),
    );
  });
}
