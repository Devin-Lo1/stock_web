class TradeSignal {
  const TradeSignal({
    this.id = '',
    required this.type,
    required this.stock,
    required this.time,
    required this.level,
    this.signalType = '',
    this.tone = SignalTone.info,
    this.message = '',
    this.strategyName = '',
    this.conditionLabel = '',
    this.triggerValue,
    this.thresholdValue,
    this.pushCandidate = false,
    this.sourceCategory = '',
  });

  final String id;
  final String type;
  final String stock;
  final String time;
  final String level;
  final String signalType;
  final SignalTone tone;
  final String message;
  final String strategyName;
  final String conditionLabel;
  final double? triggerValue;
  final double? thresholdValue;
  final bool pushCandidate;
  final String sourceCategory;

  String get notificationKey => id.isNotEmpty ? id : '$type|$stock';

  SignalCategory get category {
    if (sourceCategory == 'strategy' || strategyName.isNotEmpty) {
      return SignalCategory.strategy;
    }
    if (sourceCategory == 'system' || type.contains('测试') || stock == 'TEST') {
      return SignalCategory.system;
    }
    return SignalCategory.risk;
  }

  factory TradeSignal.fromSignalEvent(Map<String, dynamic> json) {
    final payload = _readMap(json['payload']);
    final level = json['level'] as String? ?? 'info';
    final signalType = json['signal_type'] as String? ?? '';
    final code = json['code'] as String? ?? '';
    final stockName = payload['stock_name'] as String? ?? '';
    final triggeredAt = DateTime.tryParse(
      json['triggered_at'] as String? ?? '',
    );
    return TradeSignal(
      id: json['id'] as String? ?? '',
      type: json['title'] as String? ?? signalType,
      stock: stockName.isEmpty ? code : '$stockName $code',
      time: triggeredAt == null ? '--' : _dateText(triggeredAt),
      level: _levelText(level),
      signalType: signalType,
      tone: _toneFor(level, signalType),
      message: json['message'] as String? ?? '',
      strategyName: payload['strategy_name'] as String? ?? '',
      conditionLabel: payload['condition_label'] as String? ?? '',
      triggerValue: _readDouble(json['trigger_value']),
      thresholdValue: _readDouble(json['threshold_value']),
      pushCandidate: payload['push_candidate'] as bool? ?? false,
      sourceCategory: payload['source_category'] as String? ?? '',
    );
  }
}

enum SignalCategory { important, strategy, risk, system }

enum SignalTone { positive, negative, warning, info }

Map<String, Object?> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value.cast<String, Object?>();
  return const {};
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _dateText(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

String _levelText(String level) {
  return switch (level) {
    'important' => '高',
    'warning' => '中',
    'info' => '低',
    _ => level,
  };
}

SignalTone _toneFor(String level, String signalType) {
  if (signalType.endsWith('_buy')) return SignalTone.positive;
  if (signalType.endsWith('_sell')) return SignalTone.negative;
  return switch (level) {
    'important' => SignalTone.negative,
    'warning' => SignalTone.warning,
    _ => SignalTone.info,
  };
}
