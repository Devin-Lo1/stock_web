import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_mobile/models/strategy_monitor.dart';
import 'package:stock_mobile/services/api_client.dart';
import 'package:stock_mobile/services/strategy_monitor_api_service.dart';

void main() {
  test('fetchMonitors sends monitor filters and parses response', () async {
    late Uri requestedUri;
    final service = StrategyMonitorApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            '[{"id":"monitor-1","position_id":"position-1","market":"HK",'
            '"code":"HK.00700","name":"Tencent","strategy_code":"ma_cross",'
            '"strategy_name":"MA Cross","parameters":{"short_window":5},'
            '"period":"day","scan_interval_minutes":15,'
            '"cooldown_minutes":120,"enabled":true,'
            '"push_candidate":false,"source_backtest_run_id":null,'
            '"last_scanned_at":"2026-05-21T01:00:00Z",'
            '"last_triggered_at":null,"last_signal_event_id":null}]',
            200,
          );
        }),
      ),
    );

    final monitors = await service.fetchMonitors(
      code: 'hk.00700',
      strategyCode: 'ma_cross',
      enabledOnly: true,
      limit: 20,
    );

    expect(requestedUri.path, '/api/v1/strategies/monitors');
    expect(requestedUri.queryParameters['code'], 'HK.00700');
    expect(requestedUri.queryParameters['strategy_code'], 'ma_cross');
    expect(requestedUri.queryParameters['enabled_only'], 'true');
    expect(requestedUri.queryParameters['limit'], '20');
    expect(monitors.single.id, 'monitor-1');
    expect(monitors.single.parameters['short_window'], 5);
    expect(monitors.single.pushCandidate, isFalse);
  });

  test('createMonitor posts backend monitor payload', () async {
    late String method;
    late Uri requestedUri;
    late Map<String, dynamic> body;
    final service = StrategyMonitorApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"id":"monitor-1","position_id":"position-1","market":"HK",'
            '"code":"HK.00700","name":"Tencent","strategy_code":"ma_cross",'
            '"strategy_name":"MA Cross","parameters":{"short_window":5,'
            '"long_window":20},"period":"day","scan_interval_minutes":15,'
            '"cooldown_minutes":120,"enabled":true,"push_candidate":true,'
            '"source_backtest_run_id":null,"last_scanned_at":null,'
            '"last_triggered_at":null,"last_signal_event_id":null}',
            201,
          );
        }),
      ),
    );

    final monitor = await service.createMonitor(
      const StrategyMonitorCreateRequest(
        positionId: 'position-1',
        market: 'HK',
        code: 'HK.00700',
        name: 'Tencent',
        strategyCode: 'ma_cross',
        strategyName: 'MA Cross',
        parameters: {'short_window': 5, 'long_window': 20},
        period: 'day',
        scanIntervalMinutes: 15,
        cooldownMinutes: 120,
        enabled: true,
        pushCandidate: true,
      ),
    );

    expect(method, 'POST');
    expect(requestedUri.path, '/api/v1/strategies/monitors');
    expect(body['position_id'], 'position-1');
    expect(body['scan_interval_minutes'], 15);
    expect(body['push_candidate'], isTrue);
    expect(monitor.id, 'monitor-1');
  });

  test('updateMonitor sends toggle payload', () async {
    late String method;
    late Uri requestedUri;
    late Map<String, dynamic> body;
    final service = StrategyMonitorApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"id":"monitor-1","position_id":null,"market":"US",'
            '"code":"US.MU","name":"Micron","strategy_code":"price_break_ma",'
            '"strategy_name":"Price Break MA","parameters":{"ma_window":20},'
            '"period":"60m","scan_interval_minutes":30,'
            '"cooldown_minutes":90,"enabled":false,'
            '"push_candidate":true,"source_backtest_run_id":null,'
            '"last_scanned_at":null,"last_triggered_at":null,'
            '"last_signal_event_id":null}',
            200,
          );
        }),
      ),
    );

    final monitor = await service.updateMonitor(
      'monitor-1',
      enabled: false,
      scanIntervalMinutes: 30,
    );

    expect(method, 'PUT');
    expect(requestedUri.path, '/api/v1/strategies/monitors/monitor-1');
    expect(body, {'enabled': false, 'scan_interval_minutes': 30});
    expect(monitor.enabled, isFalse);
    expect(monitor.scanIntervalMinutes, 30);
  });

  test('fetchSchedulerStatus parses backend scheduler state', () async {
    final service = StrategyMonitorApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          return http.Response(
            '{"enabled_by_env":false,"running":true,"scanning":false,'
            '"poll_interval_seconds":60,"refresh":true,'
            '"last_started_at":"2026-05-21T01:00:00Z",'
            '"last_stopped_at":null,"last_run_at":"2026-05-21T01:05:00Z",'
            '"last_error":null,"last_result":{"scanned_count":3,'
            '"created_count":1,"skipped_count":2,"error_count":0}}',
            200,
          );
        }),
      ),
    );

    final status = await service.fetchSchedulerStatus();

    expect(status.running, isTrue);
    expect(status.refresh, isTrue);
    expect(status.pollIntervalSeconds, 60);
    expect(status.lastResult['created_count'], 1);
  });

  test('fetchScanLogs sends filters and parses response', () async {
    late Uri requestedUri;
    final service = StrategyMonitorApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response.bytes(
            utf8.encode(
              '[{"id":"log-1","monitor_id":"monitor-1","code":"HK.00700",'
              '"strategy_code":"ma_cross","stage":"evaluate",'
              '"status":"not_triggered","message":"未触发信号。",'
              '"detail":{"latest_close":320.5},'
              '"scanned_at":"2026-05-22T01:00:00Z",'
              '"created_at":"2026-05-22T01:00:01Z"}]',
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    final logs = await service.fetchScanLogs(
      monitorId: 'monitor-1',
      code: 'hk.00700',
      status: 'not_triggered',
      limit: 10,
    );

    expect(requestedUri.path, '/api/v1/strategies/monitors/scan-logs');
    expect(requestedUri.queryParameters['monitor_id'], 'monitor-1');
    expect(requestedUri.queryParameters['code'], 'HK.00700');
    expect(requestedUri.queryParameters['status'], 'not_triggered');
    expect(requestedUri.queryParameters['limit'], '10');
    expect(logs.single.id, 'log-1');
    expect(logs.single.detail['latest_close'], 320.5);
  });

  test('deleteScanLog deletes backend scan log endpoint', () async {
    late String method;
    late Uri requestedUri;
    final service = StrategyMonitorApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          return http.Response('', 204);
        }),
      ),
    );

    await service.deleteScanLog('log-1');

    expect(method, 'DELETE');
    expect(requestedUri.path, '/api/v1/strategies/monitors/scan-logs/log-1');
  });

  test('startScheduler sends interval and refresh payload', () async {
    late String method;
    late Uri requestedUri;
    late Map<String, dynamic> body;
    final service = StrategyMonitorApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"enabled_by_env":false,"running":true,"scanning":false,'
            '"poll_interval_seconds":30,"refresh":false,'
            '"last_started_at":null,"last_stopped_at":null,'
            '"last_run_at":null,"last_error":null,"last_result":{}}',
            200,
          );
        }),
      ),
    );

    final status = await service.startScheduler(
      pollIntervalSeconds: 30,
      refresh: false,
    );

    expect(method, 'POST');
    expect(requestedUri.path, '/api/v1/strategies/monitors/scheduler/start');
    expect(body, {'poll_interval_seconds': 30, 'refresh': false});
    expect(status.running, isTrue);
  });

  test('stopScheduler posts to backend scheduler stop endpoint', () async {
    late String method;
    late Uri requestedUri;
    final service = StrategyMonitorApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          return http.Response(
            '{"enabled_by_env":false,"running":false,"scanning":false,'
            '"poll_interval_seconds":60,"refresh":false,'
            '"last_started_at":null,"last_stopped_at":null,'
            '"last_run_at":null,"last_error":null,"last_result":{}}',
            200,
          );
        }),
      ),
    );

    final status = await service.stopScheduler();

    expect(method, 'POST');
    expect(requestedUri.path, '/api/v1/strategies/monitors/scheduler/stop');
    expect(status.running, isFalse);
  });
}
