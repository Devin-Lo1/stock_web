import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_mobile/models/fund_models.dart';
import 'package:stock_mobile/services/api_client.dart';
import 'package:stock_mobile/services/fund_api_service.dart';

void main() {
  test('searchFunds sends query and parses results', () async {
    late Uri requestedUri;
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            '[{"code":"000001","name":"Fund A","fund_type":"mixed",'
            '"company":"Company","manager":"Manager","source":"eastmoney"}]',
            200,
          );
        }),
      ),
    );

    final results = await service.searchFunds('000001');

    expect(requestedUri.path, '/api/v1/funds/search');
    expect(requestedUri.queryParameters['query'], '000001');
    expect(results.single.code, '000001');
    expect(results.single.company, 'Company');
  });

  test('fetchPositionSummaries parses latest nav and profit metrics', () async {
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          return http.Response(
            '[{"position":{"id":"fund-position-1","fund_code":"000001",'
            '"name":"Fund A","fund_type":"mixed","shares":1000,'
            '"avg_cost_nav":1.2,"invested_amount":1200,'
            '"realized_profit":0,"currency":"CNY"},'
            '"latest_nav":{"fund_code":"000001","nav_date":"2026-05-22",'
            '"unit_nav":1.3,"accumulated_nav":2.0,'
            '"daily_growth_rate":1.1},'
            '"valuation_mode":"estimated","display_nav":1.32,'
            '"display_change_rate":2.1,"display_time":"2026-05-22T15:00:00Z",'
            '"day_profit":20,"day_profit_rate":2.1,'
            '"grid_recommendation":{"position_id":"fund-position-1",'
            '"fund_code":"000001","name":"Fund A","action":"sell",'
            '"action_label":"Sell 1/4","reason":"up 5.00%",'
            '"baseline_nav":1.2,"current_nav":1.32,"change_rate":10,'
            '"threshold_percent":5,"recommended_amount":330,'
            '"recommended_shares":250,"valuation_mode":"estimated",'
            '"valuation_time":"2026-05-22T15:00:00Z"},'
            '"market_value":1320,"holding_profit":120,'
            '"holding_profit_rate":8.33,"total_profit":100,'
            '"total_profit_rate":8.33}]',
            200,
          );
        }),
      ),
    );

    final summaries = await service.fetchPositionSummaries();

    expect(summaries.single.position.fundCode, '000001');
    expect(summaries.single.latestNav?.unitNav, 1.3);
    expect(summaries.single.isEstimated, isTrue);
    expect(summaries.single.displayNav, 1.32);
    expect(summaries.single.dayProfit, 20);
    expect(summaries.single.gridRecommendation?.actionLabel, 'Sell 1/4');
    expect(summaries.single.marketValue, 1320);
  });

  test('createTrade posts action payload', () async {
    late String method;
    late Uri requestedUri;
    late Map<String, dynamic> requestBody;
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 201);
        }),
      ),
    );

    await service.createTrade(
      'position-1',
      FundTradeDraft(
        action: 'buy',
        shares: 100,
        nav: 1.2,
        tradeDate: DateTime(2026, 5, 22),
        note: 'sync',
      ),
    );

    expect(method, 'POST');
    expect(requestedUri.path, '/api/v1/funds/positions/position-1/trades');
    expect(requestBody['trade_date'], '2026-05-22');
    expect(requestBody['note'], 'sync');
  });

  test('createPosition posts sync date and note payload', () async {
    late Map<String, dynamic> requestBody;
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"id":"position-1","fund_code":"000001","name":"Fund A",'
            '"fund_type":"mixed","shares":100,"avg_cost_nav":1.2,'
            '"invested_amount":120,"realized_profit":0,"currency":"CNY"}',
            201,
          );
        }),
      ),
    );

    await service.createPosition(
      fund: const FundSearchResult(
        code: '000001',
        name: 'Fund A',
        fundType: 'mixed',
        company: '',
        manager: '',
        source: 'eastmoney',
      ),
      shares: 100,
      costNav: 1.2,
      fee: 0,
      tradeDate: DateTime(2026, 5, 22),
      note: 'opening sync',
    );

    expect(requestBody['trade_date'], '2026-05-22');
    expect(requestBody['note'], 'opening sync');
  });

  test('fetchTrades reads fund trade markers', () async {
    late Uri requestedUri;
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            '[{"id":"trade-1","fund_position_id":"position-1",'
            '"fund_code":"000001","name":"Fund A","action":"buy",'
            '"shares":100,"nav":1.2,"fee":0,'
            '"trade_date":"2026-05-22","note":"first"}]',
            200,
          );
        }),
      ),
    );

    final trades = await service.fetchTrades('position-1', limit: 50);

    expect(requestedUri.path, '/api/v1/funds/positions/position-1/trades');
    expect(requestedUri.queryParameters['limit'], '50');
    expect(trades.single.isBuy, isTrue);
    expect(trades.single.nav, 1.2);
  });

  test('fetchAlertSchedulerStatus parses multiple reminder times', () async {
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          return http.Response(
            '{"enabled":true,"running":true,"scanning":false,'
            '"poll_interval_seconds":60,'
            '"reminder_times":["14:20","14:30"],'
            '"due_window_minutes":10,'
            '"next_run_at":"2026-05-23T06:30:00Z",'
            '"last_scan_at":"2026-05-23T06:20:00Z",'
            '"last_scan_key":"2026-05-23:14:20",'
            '"last_error":"",'
            '"last_result":{"scanned_count":3,"created_count":1,'
            '"skipped_count":2}}',
            200,
          );
        }),
      ),
    );

    final status = await service.fetchAlertSchedulerStatus();

    expect(status.enabled, isTrue);
    expect(status.running, isTrue);
    expect(status.reminderTimes, ['14:20', '14:30']);
    expect(status.createdCount, 1);
    expect(status.lastScanAt, isNotNull);
  });

  test('updateAlertScheduler posts configured times', () async {
    late String method;
    late Uri requestedUri;
    late Map<String, dynamic> body;
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"enabled":true,"running":true,"scanning":false,'
            '"poll_interval_seconds":60,'
            '"reminder_times":["14:20","14:30"],'
            '"due_window_minutes":15,"next_run_at":null,'
            '"last_scan_at":null,"last_scan_key":"",'
            '"last_error":"","last_result":{}}',
            200,
          );
        }),
      ),
    );

    await service.updateAlertScheduler(
      const FundAlertSchedulerDraft(
        enabled: true,
        reminderTimes: ['14:20', '14:30'],
        dueWindowMinutes: 15,
      ),
    );

    expect(method, 'PUT');
    expect(requestedUri.path, '/api/v1/funds/alerts/scheduler/config');
    expect(body['enabled'], isTrue);
    expect(body['reminder_times'], ['14:20', '14:30']);
    expect(body['due_window_minutes'], 15);
  });

  test('runAlertScan posts manual scheduler scan', () async {
    late String method;
    late Uri requestedUri;
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          return http.Response(
            '{"enabled":true,"running":true,"scanning":false,'
            '"poll_interval_seconds":60,'
            '"reminder_times":["14:30"],'
            '"due_window_minutes":10,"next_run_at":null,'
            '"last_scan_at":"2026-05-23T06:30:00Z",'
            '"last_scan_key":"manual:test","last_error":"",'
            '"last_result":{"created_count":2}}',
            200,
          );
        }),
      ),
    );

    final status = await service.runAlertScan(refresh: false);

    expect(method, 'POST');
    expect(requestedUri.path, '/api/v1/funds/alerts/scheduler/run-once');
    expect(requestedUri.queryParameters['refresh'], 'false');
    expect(status.createdCount, 2);
  });
}
