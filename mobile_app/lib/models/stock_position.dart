import 'app_enums.dart';
import '../utils/formatters.dart';

class StockPosition {
  const StockPosition({
    this.id,
    required this.name,
    required this.code,
    required this.quantity,
    required this.costPrice,
    this.avgCostPrice = 0,
    this.adjustedCostPrice = 0,
    this.realizedProfit = 0,
    required this.currentPrice,
    required this.previousClose,
    this.openPrice = 0,
    this.highPrice = 0,
    this.lowPrice = 0,
    this.volume = 0,
    this.turnover = 0,
    this.turnoverRate = 0,
    this.peRatio = 0,
    this.lotSize = 0,
    this.extendedSession = '',
    this.extendedPrice = 0,
    this.extendedChange = 0,
    this.extendedChangeRate = 0,
    this.extendedVolume = 0,
    this.extendedTurnover = 0,
    required this.changeRate,
    required this.signal,
    this.snapshotMarketValue,
    this.snapshotDayProfit,
    this.snapshotDayProfitRate,
    this.snapshotHoldingProfit,
    this.snapshotHoldingProfitRate,
    this.snapshotTotalProfit,
    this.snapshotTotalProfitRate,
    this.snapshotPositionWeight,
    this.snapshotTime,
  });

  final String? id;
  final String name;
  final String code;
  final double quantity;
  final double costPrice;
  final double avgCostPrice;
  final double adjustedCostPrice;
  final double realizedProfit;
  final double currentPrice;
  final double previousClose;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final double volume;
  final double turnover;
  final double turnoverRate;
  final double peRatio;
  final double lotSize;
  final String extendedSession;
  final double extendedPrice;
  final double extendedChange;
  final double extendedChangeRate;
  final double extendedVolume;
  final double extendedTurnover;
  final double changeRate;
  final String signal;
  final double? snapshotMarketValue;
  final double? snapshotDayProfit;
  final double? snapshotDayProfitRate;
  final double? snapshotHoldingProfit;
  final double? snapshotHoldingProfitRate;
  final double? snapshotTotalProfit;
  final double? snapshotTotalProfitRate;
  final double? snapshotPositionWeight;
  final DateTime? snapshotTime;

  factory StockPosition.fromJson(Map<String, dynamic> json) {
    return StockPosition(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      avgCostPrice: (json['avgCostPrice'] as num?)?.toDouble() ?? 0,
      adjustedCostPrice: (json['adjustedCostPrice'] as num?)?.toDouble() ?? 0,
      realizedProfit: (json['realizedProfit'] as num?)?.toDouble() ?? 0,
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0,
      previousClose: (json['previousClose'] as num?)?.toDouble() ?? 0,
      openPrice: (json['openPrice'] as num?)?.toDouble() ?? 0,
      highPrice: (json['highPrice'] as num?)?.toDouble() ?? 0,
      lowPrice: (json['lowPrice'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      turnover: (json['turnover'] as num?)?.toDouble() ?? 0,
      turnoverRate: (json['turnoverRate'] as num?)?.toDouble() ?? 0,
      peRatio: (json['peRatio'] as num?)?.toDouble() ?? 0,
      lotSize: (json['lotSize'] as num?)?.toDouble() ?? 0,
      extendedSession: json['extendedSession'] as String? ?? '',
      extendedPrice: (json['extendedPrice'] as num?)?.toDouble() ?? 0,
      extendedChange: (json['extendedChange'] as num?)?.toDouble() ?? 0,
      extendedChangeRate: (json['extendedChangeRate'] as num?)?.toDouble() ?? 0,
      extendedVolume: (json['extendedVolume'] as num?)?.toDouble() ?? 0,
      extendedTurnover: (json['extendedTurnover'] as num?)?.toDouble() ?? 0,
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0,
      signal: json['signal'] as String? ?? '',
      snapshotMarketValue: (json['snapshotMarketValue'] as num?)?.toDouble(),
      snapshotDayProfit: (json['snapshotDayProfit'] as num?)?.toDouble(),
      snapshotDayProfitRate: (json['snapshotDayProfitRate'] as num?)
          ?.toDouble(),
      snapshotHoldingProfit: (json['snapshotHoldingProfit'] as num?)
          ?.toDouble(),
      snapshotHoldingProfitRate: (json['snapshotHoldingProfitRate'] as num?)
          ?.toDouble(),
      snapshotTotalProfit: (json['snapshotTotalProfit'] as num?)?.toDouble(),
      snapshotTotalProfitRate: (json['snapshotTotalProfitRate'] as num?)
          ?.toDouble(),
      snapshotPositionWeight: (json['snapshotPositionWeight'] as num?)
          ?.toDouble(),
      snapshotTime: DateTime.tryParse(json['snapshotTime'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'code': code,
      'quantity': quantity,
      'costPrice': costPrice,
      'avgCostPrice': avgCostPrice,
      'adjustedCostPrice': adjustedCostPrice,
      'realizedProfit': realizedProfit,
      'currentPrice': currentPrice,
      'previousClose': previousClose,
      'openPrice': openPrice,
      'highPrice': highPrice,
      'lowPrice': lowPrice,
      'volume': volume,
      'turnover': turnover,
      'turnoverRate': turnoverRate,
      'peRatio': peRatio,
      'lotSize': lotSize,
      'extendedSession': extendedSession,
      'extendedPrice': extendedPrice,
      'extendedChange': extendedChange,
      'extendedChangeRate': extendedChangeRate,
      'extendedVolume': extendedVolume,
      'extendedTurnover': extendedTurnover,
      'changeRate': changeRate,
      'signal': signal,
      if (snapshotMarketValue != null)
        'snapshotMarketValue': snapshotMarketValue,
      if (snapshotDayProfit != null) 'snapshotDayProfit': snapshotDayProfit,
      if (snapshotDayProfitRate != null)
        'snapshotDayProfitRate': snapshotDayProfitRate,
      if (snapshotHoldingProfit != null)
        'snapshotHoldingProfit': snapshotHoldingProfit,
      if (snapshotHoldingProfitRate != null)
        'snapshotHoldingProfitRate': snapshotHoldingProfitRate,
      if (snapshotTotalProfit != null)
        'snapshotTotalProfit': snapshotTotalProfit,
      if (snapshotTotalProfitRate != null)
        'snapshotTotalProfitRate': snapshotTotalProfitRate,
      if (snapshotPositionWeight != null)
        'snapshotPositionWeight': snapshotPositionWeight,
      if (snapshotTime != null) 'snapshotTime': snapshotTime!.toIso8601String(),
    };
  }

  MarketFilter get market {
    final upperCode = code.toUpperCase();
    if (upperCode.startsWith('US.')) return MarketFilter.us;
    return MarketFilter.hk;
  }

  double get effectiveAdjustedCostPrice =>
      adjustedCostPrice == 0 ? costPrice : adjustedCostPrice;
  bool get hasBackendMetrics =>
      snapshotMarketValue != null &&
      snapshotDayProfit != null &&
      snapshotDayProfitRate != null &&
      snapshotHoldingProfit != null &&
      snapshotHoldingProfitRate != null &&
      snapshotPositionWeight != null;
  double? get backendMarketValue => snapshotMarketValue;
  double? get backendDayProfit => snapshotDayProfit;
  double? get backendDayProfitRate => snapshotDayProfitRate;
  double? get backendHoldingProfit => snapshotHoldingProfit;
  double? get backendHoldingProfitRate => snapshotHoldingProfitRate;
  double? get backendPositionWeight => snapshotPositionWeight;
  double get costValue => quantity * effectiveAdjustedCostPrice;
  double get marketValue => snapshotMarketValue ?? quantity * currentPrice;
  double get profit => snapshotHoldingProfit ?? marketValue - costValue;
  double get dailyProfit =>
      snapshotDayProfit ?? (currentPrice - previousClose) * quantity;
  double get dailyProfitRate =>
      snapshotDayProfitRate ??
      (previousClose == 0
          ? 0
          : (currentPrice - previousClose) / previousClose * 100);
  double get profitRate =>
      snapshotHoldingProfitRate ??
      (costValue == 0 ? 0 : profit / costValue * 100);
  double get totalProfit => snapshotTotalProfit ?? realizedProfit + profit;
  double get totalProfitRate => snapshotTotalProfitRate ?? profitRate;
  double get positionWeight => snapshotPositionWeight ?? 0;
  bool get hasExtendedSession =>
      market == MarketFilter.us &&
      extendedSession.isNotEmpty &&
      extendedPrice > 0;
  bool get isUp => profit >= 0;
  String get price => formatHkd(currentPrice, showSign: false, decimals: 2);
  String get shortPrice =>
      '${currencySymbol(code)}${currentPrice.toStringAsFixed(2)}';
  String get change => formatPercent(changeRate);
  String get pnl => formatHkd(profit);
}
