import 'app_enums.dart';
import '../utils/formatters.dart';

class StockPosition {
  const StockPosition({
    this.id,
    required this.name,
    required this.code,
    required this.quantity,
    required this.costPrice,
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
    required this.changeRate,
    required this.signal,
  });

  final String? id;
  final String name;
  final String code;
  final double quantity;
  final double costPrice;
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
  final double changeRate;
  final String signal;

  factory StockPosition.fromJson(Map<String, dynamic> json) {
    return StockPosition(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
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
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0,
      signal: json['signal'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'code': code,
      'quantity': quantity,
      'costPrice': costPrice,
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
      'changeRate': changeRate,
      'signal': signal,
    };
  }

  MarketFilter get market {
    final upperCode = code.toUpperCase();
    if (upperCode.startsWith('US.')) return MarketFilter.us;
    return MarketFilter.hk;
  }

  double get costValue => quantity * costPrice;
  double get marketValue => quantity * currentPrice;
  double get profit => marketValue - costValue;
  double get dailyProfit => (currentPrice - previousClose) * quantity;
  double get dailyProfitRate => previousClose == 0
      ? 0
      : (currentPrice - previousClose) / previousClose * 100;
  double get profitRate => costValue == 0 ? 0 : profit / costValue * 100;
  bool get isUp => profit >= 0;
  String get price => formatHkd(currentPrice, showSign: false, decimals: 2);
  String get shortPrice =>
      '${currencySymbol(code)}${currentPrice.toStringAsFixed(2)}';
  String get change => formatPercent(changeRate);
  String get pnl => formatHkd(profit);
}
