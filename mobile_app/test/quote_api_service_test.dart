import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_mobile/services/api_client.dart';
import 'package:stock_mobile/services/quote_api_service.dart';

void main() {
  test(
    'refreshCandles requests backend refresh before cached fallback',
    () async {
      final requestedUris = <Uri>[];
      final service = QuoteApiService(
        ApiClient(
          baseUrl: 'http://test.local',
          httpClient: MockClient((request) async {
            requestedUris.add(request.url);

            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/klines/refresh');
            return http.Response('''
[
  {
    "code": "HK.02628",
    "market": "HK",
    "period": "week",
    "time": "2026-05-11T00:00:00Z",
    "open": 31.06,
    "high": 31.84,
    "low": 29.48,
    "close": 29.60,
    "volume": 100248669,
    "turnover": 3111460025
  }
]
''', 200);
          }),
        ),
      );

      final candles = await service.refreshCandles(
        'HK.02628',
        period: 'week',
        limit: 5,
      );

      expect(candles, hasLength(1));
      expect(candles.single.close, 29.60);
      expect(requestedUris, hasLength(1));
      expect(requestedUris.single.path, '/api/v1/klines/refresh');
    },
  );

  test('refreshCandles falls back to real cache before mock data', () async {
    final requestedUris = <Uri>[];
    final service = QuoteApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);

          if (request.method == 'POST') {
            return http.Response('service unavailable', 503);
          }

          expect(request.method, 'GET');
          expect(request.url.queryParameters['include_mock'], 'false');
          return http.Response('''
[
  {
    "code": "HK.02628",
    "market": "HK",
    "period": "week",
    "time": "2026-05-11T00:00:00Z",
    "open": 31.06,
    "high": 31.84,
    "low": 29.48,
    "close": 29.60,
    "volume": 100248669,
    "turnover": 3111460025
  }
]
''', 200);
        }),
      ),
    );

    final candles = await service.refreshCandles(
      'HK.02628',
      period: 'week',
      limit: 240,
    );

    expect(candles, hasLength(1));
    expect(candles.single.period, 'week');
    expect(requestedUris, hasLength(2));
    expect(requestedUris.first.path, '/api/v1/klines/refresh');
    expect(requestedUris.last.queryParameters['include_mock'], 'false');
  });
}
