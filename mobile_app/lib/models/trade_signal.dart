import 'package:flutter/material.dart';

class TradeSignal {
  const TradeSignal({
    this.id = '',
    required this.type,
    required this.stock,
    required this.time,
    required this.level,
    required this.color,
    this.message = '',
    this.strategyName = '',
    this.conditionLabel = '',
    this.triggerValue,
    this.thresholdValue,
    this.pushCandidate = false,
  });

  final String id;
  final String type;
  final String stock;
  final String time;
  final String level;
  final Color color;
  final String message;
  final String strategyName;
  final String conditionLabel;
  final double? triggerValue;
  final double? thresholdValue;
  final bool pushCandidate;

  String get notificationKey => id.isNotEmpty ? id : '$type|$stock';

  factory TradeSignal.fromSignalEvent(Map<String, dynamic> json) {
    final payload = _readMap(json['payload']);
    final level = json['level'] as String? ?? 'info';
    final code = json['code'] as String? ?? '';
    final stockName = payload['stock_name'] as String? ?? '';
    final triggeredAt = DateTime.tryParse(
      json['triggered_at'] as String? ?? '',
    );
    return TradeSignal(
      id: json['id'] as String? ?? '',
      type: json['title'] as String? ?? json['signal_type'] as String? ?? '',
      stock: stockName.isEmpty ? code : '$stockName $code',
      time: triggeredAt == null ? '--' : _dateText(triggeredAt),
      level: _levelText(level),
      color: _levelColor(level, json['signal_type'] as String? ?? ''),
      message: json['message'] as String? ?? '',
      strategyName: payload['strategy_name'] as String? ?? '',
      conditionLabel: payload['condition_label'] as String? ?? '',
      triggerValue: _readDouble(json['trigger_value']),
      thresholdValue: _readDouble(json['threshold_value']),
      pushCandidate: payload['push_candidate'] as bool? ?? false,
    );
  }
}

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

Color _levelColor(String level, String signalType) {
  if (signalType.endsWith('_buy')) return const Color(0xFF12B886);
  if (signalType.endsWith('_sell')) return const Color(0xFFFF3B45);
  return switch (level) {
    'important' => const Color(0xFFFF3B45),
    'warning' => const Color(0xFFE6B450),
    _ => const Color(0xFF38BDF8),
  };
}
