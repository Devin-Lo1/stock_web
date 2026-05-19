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
    this.sourceCategory = '',
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
      sourceCategory: payload['source_category'] as String? ?? '',
    );
  }
}

enum SignalCategory { important, strategy, risk, system }

extension SignalCategoryLabel on SignalCategory {
  String get title {
    return switch (this) {
      SignalCategory.important => '重要信号',
      SignalCategory.strategy => '量化策略',
      SignalCategory.risk => '风控提醒',
      SignalCategory.system => '系统通知',
    };
  }

  String get subtitle {
    return switch (this) {
      SignalCategory.important => '高优先级观察信号',
      SignalCategory.strategy => 'MA、RSI、MACD 等策略触发',
      SignalCategory.risk => '止盈、止损和当日异动',
      SignalCategory.system => '连接、推送和任务状态',
    };
  }

  IconData get icon {
    return switch (this) {
      SignalCategory.important => Icons.priority_high_rounded,
      SignalCategory.strategy => Icons.science_rounded,
      SignalCategory.risk => Icons.shield_rounded,
      SignalCategory.system => Icons.settings_suggest_rounded,
    };
  }

  Color get color {
    return switch (this) {
      SignalCategory.important => const Color(0xFFFF3B45),
      SignalCategory.strategy => const Color(0xFF38BDF8),
      SignalCategory.risk => const Color(0xFFE6B450),
      SignalCategory.system => const Color(0xFF8B9CB3),
    };
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
