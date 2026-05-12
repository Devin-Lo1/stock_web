class Candle {
  const Candle({
    required this.code,
    required this.market,
    required this.period,
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.turnover,
  });

  final String code;
  final String market;
  final String period;
  final DateTime? time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double turnover;

  factory Candle.fromJson(Map<String, dynamic> json) {
    return Candle(
      code: json['code'] as String? ?? '',
      market: json['market'] as String? ?? '',
      period: json['period'] as String? ?? '',
      time: _readDateTime(json['time']),
      open: _readDouble(json['open']),
      high: _readDouble(json['high']),
      low: _readDouble(json['low']),
      close: _readDouble(json['close']),
      volume: _readDouble(json['volume']),
      turnover: _readDouble(json['turnover']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'market': market,
      'period': period,
      'time': time?.toIso8601String(),
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
      'turnover': turnover,
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
