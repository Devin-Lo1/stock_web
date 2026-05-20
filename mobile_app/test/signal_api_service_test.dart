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
      level: 'important',
      readStatus: 'unread',
      pushCandidate: true,
    );

    expect(signals, isEmpty);
    expect(requestedUri.path, '/api/v1/signals/events');
    expect(requestedUri.queryParameters['limit'], '100');
    expect(requestedUri.queryParameters['source_category'], 'strategy');
    expect(requestedUri.queryParameters['strategy_code'], 'ma_cross');
    expect(requestedUri.queryParameters['level'], 'important');
    expect(requestedUri.queryParameters['read_status'], 'unread');
    expect(requestedUri.queryParameters['push_candidate'], 'true');
  });
}
