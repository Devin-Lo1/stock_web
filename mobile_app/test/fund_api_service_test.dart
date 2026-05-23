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
    expect(summaries.single.marketValue, 1320);
  });

  test('createTrade posts action payload', () async {
    late String method;
    late Uri requestedUri;
    final service = FundApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          return http.Response('{}', 201);
        }),
      ),
    );

    await service.createTrade(
      'position-1',
      const FundTradeDraft(action: 'buy', shares: 100, nav: 1.2),
    );

    expect(method, 'POST');
    expect(requestedUri.path, '/api/v1/funds/positions/position-1/trades');
  });
}
