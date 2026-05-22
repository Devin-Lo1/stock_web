import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_mobile/services/api_client.dart';
import 'package:stock_mobile/services/notification_api_service.dart';

void main() {
  test('fetchPushRecords sends filters and parses backend records', () async {
    late Uri requestedUri;
    final service = NotificationApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            '[{"id":"record-1","signal_event_id":"event-1",'
            '"device_id":"device-1","provider":"huawei","status":"sent",'
            '"request_payload":{},"response_payload":{},'
            '"error_message":"","attempt_count":1,'
            '"sent_at":"2026-05-21T01:00:00Z",'
            '"created_at":"2026-05-21T01:00:00Z",'
            '"updated_at":"2026-05-21T01:00:00Z"}]',
            200,
          );
        }),
      ),
    );

    final records = await service.fetchPushRecords(
      signalEventId: 'event-1',
      deviceId: 'device-1',
      code: 'hk.02318',
      status: 'sent',
      limit: 20,
    );

    expect(requestedUri.path, '/api/v1/notifications/push-records');
    expect(requestedUri.queryParameters['signal_event_id'], 'event-1');
    expect(requestedUri.queryParameters['device_id'], 'device-1');
    expect(requestedUri.queryParameters['code'], 'HK.02318');
    expect(requestedUri.queryParameters['status'], 'sent');
    expect(requestedUri.queryParameters['limit'], '20');
    expect(records.single.id, 'record-1');
    expect(records.single.signalEventId, 'event-1');
    expect(records.single.provider, 'huawei');
    expect(records.single.status, 'sent');
    expect(records.single.attemptCount, 1);
    expect(records.single.sentAt, isNotNull);
  });

  test('retryPushRecord posts retry endpoint and parses record', () async {
    late http.Request requestedRequest;
    final service = NotificationApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedRequest = request;
          return http.Response(
            '{"id":"record-2","signal_event_id":"event-1",'
            '"device_id":"device-1","provider":"fcm","status":"sent",'
            '"request_payload":{},"response_payload":{},'
            '"error_message":"","attempt_count":1,'
            '"sent_at":"2026-05-21T01:02:00Z",'
            '"created_at":"2026-05-21T01:02:00Z",'
            '"updated_at":"2026-05-21T01:02:00Z"}',
            200,
          );
        }),
      ),
    );

    final record = await service.retryPushRecord('record-1');

    expect(requestedRequest.method, 'POST');
    expect(
      requestedRequest.url.path,
      '/api/v1/notifications/push-records/record-1/retry',
    );
    expect(record.id, 'record-2');
    expect(record.status, 'sent');
  });

  test('deletePushRecord calls delete endpoint', () async {
    late http.Request requestedRequest;
    final service = NotificationApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedRequest = request;
          return http.Response('', 204);
        }),
      ),
    );

    await service.deletePushRecord('record-1');

    expect(requestedRequest.method, 'DELETE');
    expect(
      requestedRequest.url.path,
      '/api/v1/notifications/push-records/record-1',
    );
  });
}
