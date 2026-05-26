class QuoteSnapshot {
  const QuoteSnapshot({
    required this.code,
    required this.market,
    required this.currency,
    required this.currentPrice,
    required this.previousClose,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.turnover,
    this.turnoverRate = 0,
    this.peRatio = 0,
    this.lotSize = 0,
    required this.change,
    required this.changeRate,
    required this.quoteTime,
    this.extendedSession = '',
    this.extendedPrice = 0,
    this.extendedChange = 0,
    this.extendedChangeRate = 0,
    this.extendedVolume = 0,
    this.extendedTurnover = 0,
  });

  final String code;
  final String market;
  final String currency;
  final double currentPrice;
  final double previousClose;
  final double open;
  final double high;
  final double low;
  final double volume;
  final double turnover;
  final double turnoverRate;
  final double peRatio;
  final double lotSize;
  final double change;
  final double changeRate;
  final DateTime? quoteTime;
  final String extendedSession;
  final double extendedPrice;
  final double extendedChange;
  final double extendedChangeRate;
  final double extendedVolume;
  final double extendedTurnover;

  bool get hasExtendedSession =>
      extendedSession.isNotEmpty && extendedPrice > 0;

  factory QuoteSnapshot.fromJson(Map<String, dynamic> json) {
    return QuoteSnapshot(
      code: json['code'] as String? ?? '',
      market: json['market'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      currentPrice: _readDouble(json['currentPrice'] ?? json['current_price']),
      previousClose: _readDouble(
        json['previousClose'] ?? json['previous_close'],
      ),
      open: _readDouble(json['open']),
      high: _readDouble(json['high']),
      low: _readDouble(json['low']),
      volume: _readDouble(json['volume']),
      turnover: _readDouble(json['turnover']),
      turnoverRate: _readDouble(json['turnoverRate'] ?? json['turnover_rate']),
      peRatio: _readDouble(json['peRatio'] ?? json['pe_ratio']),
      lotSize: _readDouble(json['lotSize'] ?? json['lot_size']),
      change: _readDouble(json['change']),
      changeRate: _readDouble(json['changeRate'] ?? json['change_rate']),
      quoteTime: _readDateTime(json['quoteTime'] ?? json['quote_time']),
      extendedSession:
          json['extendedSession'] as String? ??
          json['extended_session'] as String? ??
          '',
      extendedPrice: _readDouble(
        json['extendedPrice'] ?? json['extended_price'],
      ),
      extendedChange: _readDouble(
        json['extendedChange'] ?? json['extended_change'],
      ),
      extendedChangeRate: _readDouble(
        json['extendedChangeRate'] ?? json['extended_change_rate'],
      ),
      extendedVolume: _readDouble(
        json['extendedVolume'] ?? json['extended_volume'],
      ),
      extendedTurnover: _readDouble(
        json['extendedTurnover'] ?? json['extended_turnover'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'market': market,
      'currency': currency,
      'currentPrice': currentPrice,
      'previousClose': previousClose,
      'open': open,
      'high': high,
      'low': low,
      'volume': volume,
      'turnover': turnover,
      'turnoverRate': turnoverRate,
      'peRatio': peRatio,
      'lotSize': lotSize,
      'change': change,
      'changeRate': changeRate,
      'quoteTime': quoteTime?.toIso8601String(),
      'extendedSession': extendedSession,
      'extendedPrice': extendedPrice,
      'extendedChange': extendedChange,
      'extendedChangeRate': extendedChangeRate,
      'extendedVolume': extendedVolume,
      'extendedTurnover': extendedTurnover,
    };
  }
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime? _readDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
