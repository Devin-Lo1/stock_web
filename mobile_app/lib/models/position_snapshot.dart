class PositionSnapshot {
  const PositionSnapshot({
    required this.id,
    required this.positionId,
    required this.market,
    required this.code,
    required this.name,
    required this.currency,
    required this.quantity,
    required this.avgCostPrice,
    required this.adjustedCostPrice,
    required this.realizedProfit,
    required this.currentPrice,
    required this.previousClose,
    required this.marketValue,
    required this.dayProfit,
    required this.dayProfitRate,
    required this.holdingProfit,
    required this.holdingProfitRate,
    required this.totalProfit,
    required this.totalProfitRate,
    required this.positionWeight,
    required this.snapshotTime,
  });

  final String id;
  final String positionId;
  final String market;
  final String code;
  final String name;
  final String currency;
  final double quantity;
  final double avgCostPrice;
  final double adjustedCostPrice;
  final double realizedProfit;
  final double currentPrice;
  final double previousClose;
  final double marketValue;
  final double dayProfit;
  final double dayProfitRate;
  final double holdingProfit;
  final double holdingProfitRate;
  final double totalProfit;
  final double totalProfitRate;
  final double positionWeight;
  final DateTime? snapshotTime;

  factory PositionSnapshot.fromJson(Map<String, dynamic> json) {
    return PositionSnapshot(
      id: json['id'] as String? ?? '',
      positionId: json['position_id'] as String? ?? '',
      market: json['market'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      quantity: _readDouble(json['quantity']),
      avgCostPrice: _readDouble(json['avg_cost_price']),
      adjustedCostPrice: _readDouble(json['adjusted_cost_price']),
      realizedProfit: _readDouble(json['realized_profit']),
      currentPrice: _readDouble(json['current_price']),
      previousClose: _readDouble(json['previous_close']),
      marketValue: _readDouble(json['market_value']),
      dayProfit: _readDouble(json['day_profit']),
      dayProfitRate: _readDouble(json['day_profit_rate']),
      holdingProfit: _readDouble(json['holding_profit']),
      holdingProfitRate: _readDouble(json['holding_profit_rate']),
      totalProfit: _readDouble(json['total_profit']),
      totalProfitRate: _readDouble(json['total_profit_rate']),
      positionWeight: _readDouble(json['position_weight']),
      snapshotTime: _readDateTime(json['snapshot_time']),
    );
  }
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime? _readDateTime(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
