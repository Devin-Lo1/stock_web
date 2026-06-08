import 'candle.dart';

class PersonalizedStrategySegment {
  const PersonalizedStrategySegment({
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.totalReturn,
    required this.maxDrawdown,
    required this.winRate,
    required this.roundTripCount,
  });

  final String label;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalReturn;
  final double maxDrawdown;
  final double winRate;
  final int roundTripCount;

  factory PersonalizedStrategySegment.fromJson(Map<String, dynamic> json) {
    return PersonalizedStrategySegment(
      label: json['label'] as String? ?? '',
      startDate: _readDate(json['start_date']),
      endDate: _readDate(json['end_date']),
      totalReturn: _readDouble(json['total_return']),
      maxDrawdown: _readDouble(json['max_drawdown']),
      winRate: _readDouble(json['win_rate']),
      roundTripCount: (json['round_trip_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PersonalizedStrategyTemplate {
  const PersonalizedStrategyTemplate({
    required this.code,
    required this.symbol,
    required this.name,
    required this.description,
    required this.benchmarkSymbol,
    required this.directionMode,
    required this.riskLevel,
    required this.positionRatio,
    required this.maxHoldDays,
    required this.parameters,
    required this.entryRules,
    required this.exitRules,
    required this.segments,
  });

  final String code;
  final String symbol;
  final String name;
  final String description;
  final String benchmarkSymbol;
  final String directionMode;
  final String riskLevel;
  final double positionRatio;
  final int? maxHoldDays;
  final Map<String, Object?> parameters;
  final List<String> entryRules;
  final List<String> exitRules;
  final List<PersonalizedStrategySegment> segments;

  String get riskText {
    return switch (riskLevel) {
      'steady' => '稳健',
      'aggressive' => '进攻',
      _ => '均衡',
    };
  }

  String get directionText {
    return directionMode == 'long_short' ? '多空' : '只做多';
  }

  factory PersonalizedStrategyTemplate.fromJson(Map<String, dynamic> json) {
    return PersonalizedStrategyTemplate(
      code: json['code'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      benchmarkSymbol: json['benchmark_symbol'] as String? ?? '',
      directionMode: json['direction_mode'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? '',
      positionRatio: _readDouble(json['position_ratio']),
      maxHoldDays: (json['max_hold_days'] as num?)?.toInt(),
      parameters: _readMap(json['parameters']),
      entryRules: _readStringList(json['entry_rules']),
      exitRules: _readStringList(json['exit_rules']),
      segments: (json['segments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PersonalizedStrategySegment.fromJson)
          .toList(),
    );
  }
}

class PersonalizedStrategyEvent {
  const PersonalizedStrategyEvent({
    required this.date,
    required this.action,
    required this.price,
    required this.reason,
  });

  final DateTime? date;
  final String action;
  final double? price;
  final String reason;

  factory PersonalizedStrategyEvent.fromMap(Map<Object?, Object?> json) {
    return PersonalizedStrategyEvent(
      date: _readDate(json['date']),
      action: json['action'] as String? ?? '',
      price: _readNullableDouble(json['price']),
      reason: json['reason'] as String? ?? '',
    );
  }
}

class PersonalizedStrategyDecision {
  const PersonalizedStrategyDecision({
    required this.kind,
    required this.title,
    required this.action,
    required this.actionLabel,
    required this.currentPosition,
    required this.latestDate,
    required this.latestPrice,
    required this.signalDate,
    required this.reason,
    required this.flatDecision,
    required this.longDecision,
    required this.shortDecision,
    required this.isRealtime,
    required this.isConfirmed,
    required this.detail,
  });

  final String kind;
  final String title;
  final String action;
  final String actionLabel;
  final String currentPosition;
  final DateTime? latestDate;
  final double? latestPrice;
  final DateTime? signalDate;
  final String reason;
  final String flatDecision;
  final String longDecision;
  final String shortDecision;
  final bool isRealtime;
  final bool isConfirmed;
  final Map<String, Object?> detail;

  PersonalizedStrategyEvent? get lastEvent {
    final value = detail['last_event'];
    if (value is Map) {
      return PersonalizedStrategyEvent.fromMap(value.cast<Object?, Object?>());
    }
    return null;
  }

  List<PersonalizedStrategyEvent> get replayEvents {
    final value = detail['events'];
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map)
          PersonalizedStrategyEvent.fromMap(item.cast<Object?, Object?>()),
    ];
  }

  List<Candle> get replayCandles {
    final value = detail['candles'];
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map)
          Candle.fromJson(
            Map<String, dynamic>.from(item.cast<Object?, Object?>()),
          ),
    ];
  }

  DateTime? get positionEntryDate {
    return _readDate(detail['position_entry_date']);
  }

  double? get positionEntryPrice {
    return _readNullableDouble(detail['position_entry_price']);
  }

  int get positionHoldDays {
    return _readInt(detail['position_hold_days']);
  }

  factory PersonalizedStrategyDecision.fromJson(Map<String, dynamic> json) {
    return PersonalizedStrategyDecision(
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actionLabel: json['action_label'] as String? ?? '',
      currentPosition: json['current_position'] as String? ?? 'flat',
      latestDate: _readDate(json['latest_date']),
      latestPrice: _readNullableDouble(json['latest_price']),
      signalDate: _readDate(json['signal_date']),
      reason: json['reason'] as String? ?? '',
      flatDecision: json['flat_decision'] as String? ?? '',
      longDecision: json['long_decision'] as String? ?? '',
      shortDecision: json['short_decision'] as String? ?? '',
      isRealtime: json['is_realtime'] as bool? ?? false,
      isConfirmed: json['is_confirmed'] as bool? ?? false,
      detail: _readMap(json['detail']),
    );
  }
}

class PersonalizedStrategyScanResult {
  const PersonalizedStrategyScanResult({
    required this.template,
    required this.status,
    required this.action,
    required this.actionLabel,
    required this.currentPosition,
    required this.latestDate,
    required this.latestClose,
    required this.signalDate,
    required this.reason,
    required this.refreshError,
    required this.todaySignal,
    required this.previousCloseSignal,
    required this.detail,
  });

  final PersonalizedStrategyTemplate template;
  final String status;
  final String action;
  final String actionLabel;
  final String currentPosition;
  final DateTime? latestDate;
  final double? latestClose;
  final DateTime? signalDate;
  final String reason;
  final String? refreshError;
  final PersonalizedStrategyDecision? todaySignal;
  final PersonalizedStrategyDecision? previousCloseSignal;
  final Map<String, Object?> detail;

  bool get isFailed => status == 'failed';

  factory PersonalizedStrategyScanResult.fromJson(Map<String, dynamic> json) {
    final templateJson = json['template'];
    return PersonalizedStrategyScanResult(
      template: templateJson is Map<String, dynamic>
          ? PersonalizedStrategyTemplate.fromJson(templateJson)
          : PersonalizedStrategyTemplate.fromJson(const {}),
      status: json['status'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actionLabel: json['action_label'] as String? ?? '',
      currentPosition: json['current_position'] as String? ?? 'flat',
      latestDate: _readDate(json['latest_date']),
      latestClose: _readNullableDouble(json['latest_close']),
      signalDate: _readDate(json['signal_date']),
      reason: json['reason'] as String? ?? '',
      refreshError: json['refresh_error'] as String?,
      todaySignal: _readDecision(json['today_signal']),
      previousCloseSignal: _readDecision(json['previous_close_signal']),
      detail: _readMap(json['detail']),
    );
  }
}

class PersonalizedStrategyRecommendation {
  const PersonalizedStrategyRecommendation({
    required this.symbol,
    required this.templateCode,
    required this.templateName,
    required this.riskLevel,
    required this.action,
    required this.actionLabel,
    required this.score,
    required this.latestDate,
    required this.latestPrice,
    required this.signalDate,
    required this.reason,
    required this.summary,
    required this.result,
  });

  final String symbol;
  final String templateCode;
  final String templateName;
  final String riskLevel;
  final String action;
  final String actionLabel;
  final double score;
  final DateTime? latestDate;
  final double? latestPrice;
  final DateTime? signalDate;
  final String reason;
  final String summary;
  final PersonalizedStrategyScanResult result;

  String get riskText {
    return switch (riskLevel) {
      'steady' => '稳健',
      'aggressive' => '进攻',
      _ => '均衡',
    };
  }

  factory PersonalizedStrategyRecommendation.fromJson(
    Map<String, dynamic> json,
  ) {
    final resultJson = json['result'];
    return PersonalizedStrategyRecommendation(
      symbol: json['symbol'] as String? ?? '',
      templateCode: json['template_code'] as String? ?? '',
      templateName: json['template_name'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actionLabel: json['action_label'] as String? ?? '',
      score: _readDouble(json['score']),
      latestDate: _readDate(json['latest_date']),
      latestPrice: _readNullableDouble(json['latest_price']),
      signalDate: _readDate(json['signal_date']),
      reason: json['reason'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      result: resultJson is Map<String, dynamic>
          ? PersonalizedStrategyScanResult.fromJson(resultJson)
          : PersonalizedStrategyScanResult.fromJson(const {}),
    );
  }
}

class PersonalizedStrategyBulkScanResult {
  const PersonalizedStrategyBulkScanResult({
    required this.results,
    required this.recommendations,
  });

  final List<PersonalizedStrategyScanResult> results;
  final List<PersonalizedStrategyRecommendation> recommendations;

  factory PersonalizedStrategyBulkScanResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return PersonalizedStrategyBulkScanResult(
      results: (json['results'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PersonalizedStrategyScanResult.fromJson)
          .toList(),
      recommendations: (json['recommendations'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PersonalizedStrategyRecommendation.fromJson)
          .toList(),
    );
  }
}

PersonalizedStrategyDecision? _readDecision(Object? value) {
  if (value is Map<String, dynamic>) {
    return PersonalizedStrategyDecision.fromJson(value);
  }
  return null;
}

DateTime? _readDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _readNullableDouble(Object? value) {
  if (value == null) return null;
  return _readDouble(value);
}

int _readInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, Object?> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value.cast<String, Object?>();
  return const {};
}

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}
