import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_mobile/models/app_enums.dart';
import 'package:stock_mobile/models/position_trade.dart';
import 'package:stock_mobile/models/stock_position.dart';
import 'package:stock_mobile/services/api_client.dart';
import 'package:stock_mobile/services/position_api_service.dart';

void main() {
  test('fetchPositions parses backend cost fields', () async {
    final service = PositionApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          return http.Response(
            '[{"id":"position-1","market":"HK","code":"HK.00700",'
            '"name":"Tencent","quantity":100,"cost_price":8,'
            '"avg_cost_price":10,"adjusted_cost_price":8,'
            '"realized_profit":200,"currency":"HKD"}]',
            200,
          );
        }),
      ),
    );

    final positions = await service.fetchPositions();

    expect(positions.single.avgCostPrice, 10);
    expect(positions.single.adjustedCostPrice, 8);
    expect(positions.single.realizedProfit, 200);
  });

  test('createPosition posts A-share market with CNY currency', () async {
    late String body;
    final service = PositionApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          body = request.body;
          return http.Response(
            '{"id":"position-cn","market":"SH","code":"SH.600519",'
            '"name":"Moutai","quantity":100,"cost_price":1500,'
            '"currency":"CNY"}',
            201,
          );
        }),
      ),
    );

    final position = await service.createPosition(
      const StockPosition(
        name: 'Moutai',
        code: 'SH.600519',
        quantity: 100,
        costPrice: 1500,
        currentPrice: 1500,
        previousClose: 1500,
        changeRate: 0,
        signal: 'ok',
      ),
    );

    expect(body, contains('"market":"SH"'));
    expect(body, contains('"currency":"CNY"'));
    expect(position.market, MarketFilter.cn);
  });

  test('capturePositionSnapshots parses backend calculated metrics', () async {
    late String method;
    late Uri requestedUri;
    final service = PositionApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          return http.Response(
            '[{"id":"snapshot-1","position_id":"position-1","market":"HK",'
            '"code":"HK.00700","name":"Tencent","currency":"HKD",'
            '"quantity":100,"avg_cost_price":10,"adjusted_cost_price":8,'
            '"realized_profit":200,"current_price":12,'
            '"previous_close":11,"market_value":1200,'
            '"day_profit":100,"day_profit_rate":9.09,'
            '"holding_profit":400,"holding_profit_rate":50,'
            '"total_profit":600,"total_profit_rate":60,'
            '"position_weight":25,'
            '"snapshot_time":"2026-05-21T01:00:00Z"}]',
            200,
          );
        }),
      ),
    );

    final snapshots = await service.capturePositionSnapshots();

    expect(method, 'POST');
    expect(requestedUri.path, '/api/v1/positions/snapshots/capture');
    expect(snapshots.single.marketValue, 1200);
    expect(snapshots.single.dayProfit, 100);
    expect(snapshots.single.holdingProfit, 400);
    expect(snapshots.single.positionWeight, 25);
  });

  test('fetchPositionTrades reads per-position trade history', () async {
    late Uri requestedUri;
    final service = PositionApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            '[{"id":"trade-1","position_id":"position-1","market":"HK",'
            '"code":"HK.00700","name":"Tencent","currency":"HKD",'
            '"action":"reduce","quantity":20,"price":12,"fee":1,'
            '"trade_time":"2026-05-21T01:00:00Z","note":"trim"}]',
            200,
          );
        }),
      ),
    );

    final trades = await service.fetchPositionTrades('position-1', limit: 30);

    expect(requestedUri.path, '/api/v1/positions/position-1/trades');
    expect(requestedUri.queryParameters['limit'], '30');
    expect(trades.single.action, 'reduce');
    expect(trades.single.actionLabel, '减仓');
    expect(trades.single.fee, 1);
  });

  test('createPositionTrade posts trade draft payload', () async {
    late String method;
    late Uri requestedUri;
    late String body;
    final service = PositionApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          body = request.body;
          return http.Response(
            '{"id":"trade-2","position_id":"position-1","market":"HK",'
            '"code":"HK.00700","name":"Tencent","currency":"HKD",'
            '"action":"add","quantity":10,"price":11,"fee":2,'
            '"trade_time":"2026-05-21T01:00:00Z","note":"add"}',
            201,
          );
        }),
      ),
    );

    final trade = await service.createPositionTrade(
      'position-1',
      const PositionTradeDraft(
        action: 'add',
        quantity: 10,
        price: 11,
        fee: 2,
        note: 'add',
      ),
    );

    expect(method, 'POST');
    expect(requestedUri.path, '/api/v1/positions/position-1/trades');
    expect(body, contains('"action":"add"'));
    expect(body, contains('"quantity":10'));
    expect(trade.actionLabel, '加仓');
  });

  test('createPositionTrade omits fee when draft uses automatic fee', () async {
    late String body;
    final service = PositionApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          body = request.body;
          return http.Response(
            '{"id":"trade-2","position_id":"position-1","market":"US",'
            '"code":"US.MU","name":"Micron","currency":"USD",'
            '"action":"reduce","quantity":2,"price":120,"fee":18,'
            '"trade_time":"2026-05-21T01:00:00Z","note":""}',
            201,
          );
        }),
      ),
    );

    final trade = await service.createPositionTrade(
      'position-1',
      const PositionTradeDraft(action: 'reduce', quantity: 2, price: 120),
    );

    expect(body, isNot(contains('"fee"')));
    expect(trade.fee, 18);
  });

  test('deletePositionTrade calls backend delete endpoint', () async {
    late String method;
    late Uri requestedUri;
    final service = PositionApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          method = request.method;
          requestedUri = request.url;
          return http.Response('', 204);
        }),
      ),
    );

    await service.deletePositionTrade('position-1', 'trade-1');

    expect(method, 'DELETE');
    expect(requestedUri.path, '/api/v1/positions/position-1/trades/trade-1');
  });

  test('fetchPositionSnapshots reads one position curve data', () async {
    late Uri requestedUri;
    final service = PositionApiService(
      ApiClient(
        baseUrl: 'http://test.local',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            '[{"id":"snapshot-1","position_id":"position-1","market":"HK",'
            '"code":"HK.00700","name":"Tencent","currency":"HKD",'
            '"quantity":100,"avg_cost_price":10,"adjusted_cost_price":8,'
            '"realized_profit":200,"current_price":12,'
            '"previous_close":11,"market_value":1200,'
            '"day_profit":100,"day_profit_rate":9.09,'
            '"holding_profit":400,"holding_profit_rate":50,'
            '"total_profit":600,"total_profit_rate":60,'
            '"position_weight":25,'
            '"snapshot_time":"2026-05-21T01:00:00Z"}]',
            200,
          );
        }),
      ),
    );

    final snapshots = await service.fetchPositionSnapshots(
      'position-1',
      limit: 20,
    );

    expect(requestedUri.path, '/api/v1/positions/position-1/snapshots');
    expect(requestedUri.queryParameters['limit'], '20');
    expect(snapshots.single.totalProfit, 600);
  });
}
