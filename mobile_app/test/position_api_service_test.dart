import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
}
