import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_mobile/services/api_client.dart';
import 'package:stock_mobile/services/signal_api_service.dart';

void main() {
  test('fetchSignalEvents sends category filter query parameters', () async {
    late Uri requestedUri;
    final service = SignalApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response('[]', 200);
        }),
      ),
    );

    final signals = await service.fetchSignalEvents(
      limit: 100,
      sourceCategory: 'strategy',
      strategyCode: 'ma_cross',
      signalType: 'ma_cross_buy',
      level: 'important',
      readStatus: 'unread',
      pushCandidate: true,
    );

    expect(signals, isEmpty);
    expect(requestedUri.path, '/api/v1/signals/events');
    expect(requestedUri.queryParameters['limit'], '100');
    expect(requestedUri.queryParameters['source_category'], 'strategy');
    expect(requestedUri.queryParameters['strategy_code'], 'ma_cross');
    expect(requestedUri.queryParameters['signal_type'], 'ma_cross_buy');
    expect(requestedUri.queryParameters['level'], 'important');
    expect(requestedUri.queryParameters['read_status'], 'unread');
    expect(requestedUri.queryParameters['push_candidate'], 'true');
  });

  test('fetchSignalScanConfigs parses backend configs', () async {
    final service = SignalApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          return http.Response(
            '[{"id":"ma_cross_5_20","strategy_code":"ma_cross",'
            '"strategy_name":"MA Cross","parameters":{"short_window":5},'
            '"enabled":true,"push_candidate":false,"sort_order":40}]',
            200,
          );
        }),
      ),
    );

    final configs = await service.fetchSignalScanConfigs();

    expect(configs.single.id, 'ma_cross_5_20');
    expect(configs.single.strategyCode, 'ma_cross');
    expect(configs.single.pushCandidate, isFalse);
  });

  test('updateSignalScanConfig sends toggle payload', () async {
    late String method;
    late Uri requestedUri;
    late String body;
    final service = SignalApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          body = request.body;
          return http.Response(
            '{"id":"ma_cross_5_20","strategy_code":"ma_cross",'
            '"strategy_name":"MA Cross","parameters":{},'
            '"enabled":false,"push_candidate":true,"sort_order":40}',
            200,
          );
        }),
      ),
    );

    final config = await service.updateSignalScanConfig(
      'ma_cross_5_20',
      enabled: false,
    );

    expect(method, 'PUT');
    expect(requestedUri.path, '/api/v1/signals/configs/ma_cross_5_20');
    expect(body, contains('"enabled":false'));
    expect(config.enabled, isFalse);
  });

  test('ignoreSignalEvent calls backend ignore endpoint', () async {
    late String method;
    late Uri requestedUri;
    final service = SignalApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          return http.Response(
            '{"id":"event-1","code":"HK.00700","signal_type":"risk",'
            '"level":"warning","title":"Risk signal","message":"hidden",'
            '"read_status":"ignored","triggered_at":"2026-05-21T00:00:00Z"}',
            200,
          );
        }),
      ),
    );

    final signal = await service.ignoreSignalEvent('event-1');

    expect(method, 'PUT');
    expect(requestedUri.path, '/api/v1/signals/events/event-1/ignore');
    expect(signal.readStatus, 'ignored');
  });
}
