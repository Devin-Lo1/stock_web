import '../models/position_snapshot.dart';
import '../models/stock_position.dart';
import 'api_client.dart';

class PositionApiService {
  const PositionApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StockPosition>> fetchPositions() async {
    final decoded = await _apiClient.get('/api/v1/positions');
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_positionFromBackendJson)
        .toList();
  }

  Future<StockPosition> createPosition(StockPosition position) async {
    final decoded = await _apiClient.post(
      '/api/v1/positions',
      _positionToBackendJson(position),
    );
    return _positionFromBackendJson(decoded as Map<String, dynamic>);
  }

  Future<StockPosition> updatePosition(
    String positionId,
    StockPosition position,
  ) async {
    final decoded = await _apiClient.put(
      '/api/v1/positions/$positionId',
      _positionToBackendJson(position),
    );
    return _positionFromBackendJson(decoded as Map<String, dynamic>);
  }

  Future<void> deletePosition(String positionId) {
    return _apiClient.delete('/api/v1/positions/$positionId');
  }

  Future<List<PositionSnapshot>> capturePositionSnapshots() async {
    final decoded = await _apiClient.post(
      '/api/v1/positions/snapshots/capture',
      const {},
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PositionSnapshot.fromJson)
        .toList();
  }

  Future<List<PositionSnapshot>> fetchLatestPositionSnapshots() async {
    final decoded = await _apiClient.get('/api/v1/positions/snapshots/latest');
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PositionSnapshot.fromJson)
        .toList();
  }
}

StockPosition _positionFromBackendJson(Map<String, dynamic> json) {
  return StockPosition(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    code: json['code'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
    avgCostPrice: (json['avg_cost_price'] as num?)?.toDouble() ?? 0,
    adjustedCostPrice: (json['adjusted_cost_price'] as num?)?.toDouble() ?? 0,
    realizedProfit: (json['realized_profit'] as num?)?.toDouble() ?? 0,
    currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0,
    previousClose: (json['previous_close'] as num?)?.toDouble() ?? 0,
    changeRate: (json['change_rate'] as num?)?.toDouble() ?? 0,
    signal: json['signal'] as String? ?? '等待确认',
  );
}

Map<String, dynamic> _positionToBackendJson(StockPosition position) {
  final upperCode = position.code.toUpperCase();
  final market = upperCode.contains('.') ? upperCode.split('.').first : 'HK';
  return {
    'market': market,
    'code': position.code,
    'name': position.name,
    'quantity': position.quantity,
    'cost_price': position.costPrice,
    'currency': switch (market) {
      'US' => 'USD',
      'SH' || 'SZ' => 'CNY',
      _ => 'HKD',
    },
  };
}
