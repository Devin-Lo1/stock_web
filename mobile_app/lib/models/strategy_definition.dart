class StrategyDefinition {
  const StrategyDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.defaultParameters,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final Map<String, Object?> defaultParameters;

  factory StrategyDefinition.fromJson(Map<String, dynamic> json) {
    return StrategyDefinition(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      defaultParameters: _readMap(json['default_parameters']),
    );
  }

  double defaultDouble(String key, double fallback) {
    final value = defaultParameters[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  String get displayName =>
      strategyDisplayNameForCode(code, fallbackName: name);
}

Map<String, Object?> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value.cast<String, Object?>();
  return const {};
}

const _strategyEnglishNames = {
  'ma_cross': 'MA Cross',
  'rsi_reversal': 'RSI Reversal',
  'macd_trend': 'MACD Trend',
  'price_break_ma': 'Price Break MA',
  'volume_breakout': 'Volume Breakout',
  'ma_breakdown_stop': 'MA Breakdown Stop',
  'atr_trailing_stop': 'ATR Trailing Stop',
  'rsi_oversold_rebound': 'RSI Oversold Rebound',
  'trend_score': 'Trend Score',
  'composite_factor': 'Composite Factor',
};

const _strategyChineseNames = {
  'ma_cross': '均线交叉',
  'rsi_reversal': 'RSI 反转',
  'macd_trend': 'MACD 趋势',
  'price_break_ma': '价格跌破/站回均线',
  'volume_breakout': '放量突破',
  'ma_breakdown_stop': '均线止损',
  'atr_trailing_stop': 'ATR 移动止损',
  'rsi_oversold_rebound': 'RSI 超卖反弹',
  'trend_score': '趋势评分',
  'composite_factor': '组合因子',
};

String strategyDisplayNameForCode(String code, {String? fallbackName}) {
  final name = fallbackName?.trim();
  final baseName = name == null || name.isEmpty
      ? _strategyEnglishNames[code] ?? code
      : name;
  final chineseName = _strategyChineseNames[code];
  if (chineseName == null || baseName.contains(chineseName)) {
    return baseName;
  }
  return '$baseName（$chineseName）';
}
