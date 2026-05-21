class StrategyMonitor {
  const StrategyMonitor({
    required this.id,
    required this.positionId,
    required this.market,
    required this.code,
    required this.name,
    required this.strategyCode,
    required this.strategyName,
    required this.parameters,
    required this.period,
    required this.scanIntervalMinutes,
    required this.cooldownMinutes,
    required this.enabled,
    required this.pushCandidate,
    required this.sourceBacktestRunId,
    required this.lastScannedAt,
    required this.lastTriggeredAt,
    required this.lastSignalEventId,
  });

  final String id;
  final String? positionId;
  final String market;
  final String code;
  final String name;
  final String strategyCode;
  final String strategyName;
  final Map<String, Object?> parameters;
  final String period;
  final int scanIntervalMinutes;
  final int cooldownMinutes;
  final bool enabled;
  final bool pushCandidate;
  final String? sourceBacktestRunId;
  final DateTime? lastScannedAt;
  final DateTime? lastTriggeredAt;
  final String? lastSignalEventId;

  factory StrategyMonitor.fromJson(Map<String, dynamic> json) {
    return StrategyMonitor(
      id: json['id'] as String? ?? '',
      positionId: _nullableString(json['position_id']),
      market: json['market'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      strategyCode: json['strategy_code'] as String? ?? '',
      strategyName: json['strategy_name'] as String? ?? '',
      parameters: _readMap(json['parameters']),
      period: json['period'] as String? ?? 'day',
      scanIntervalMinutes:
          (json['scan_interval_minutes'] as num?)?.toInt() ?? 15,
      cooldownMinutes: (json['cooldown_minutes'] as num?)?.toInt() ?? 120,
      enabled: json['enabled'] as bool? ?? true,
      pushCandidate: json['push_candidate'] as bool? ?? true,
      sourceBacktestRunId: _nullableString(json['source_backtest_run_id']),
      lastScannedAt: _readDateTime(json['last_scanned_at']),
      lastTriggeredAt: _readDateTime(json['last_triggered_at']),
      lastSignalEventId: _nullableString(json['last_signal_event_id']),
    );
  }

  String get parameterLabel {
    if (parameters.isEmpty) return 'default';
    return parameters.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
  }
}

class StrategyMonitorCreateRequest {
  const StrategyMonitorCreateRequest({
    required this.positionId,
    required this.market,
    required this.code,
    required this.name,
    required this.strategyCode,
    required this.strategyName,
    required this.parameters,
    required this.period,
    required this.scanIntervalMinutes,
    required this.cooldownMinutes,
    required this.enabled,
    required this.pushCandidate,
    this.sourceBacktestRunId,
  });

  final String? positionId;
  final String market;
  final String code;
  final String name;
  final String strategyCode;
  final String strategyName;
  final Map<String, Object?> parameters;
  final String period;
  final int scanIntervalMinutes;
  final int cooldownMinutes;
  final bool enabled;
  final bool pushCandidate;
  final String? sourceBacktestRunId;

  Map<String, dynamic> toJson() {
    return {
      if (positionId != null && positionId!.isNotEmpty)
        'position_id': positionId,
      'market': market,
      'code': code,
      'name': name,
      'strategy_code': strategyCode,
      'strategy_name': strategyName,
      'parameters': parameters,
      'period': period,
      'scan_interval_minutes': scanIntervalMinutes,
      'cooldown_minutes': cooldownMinutes,
      'enabled': enabled,
      'push_candidate': pushCandidate,
      if (sourceBacktestRunId != null && sourceBacktestRunId!.isNotEmpty)
        'source_backtest_run_id': sourceBacktestRunId,
    };
  }
}

class StrategyMonitorSchedulerStatus {
  const StrategyMonitorSchedulerStatus({
    required this.enabledByEnv,
    required this.running,
    required this.scanning,
    required this.pollIntervalSeconds,
    required this.refresh,
    required this.lastStartedAt,
    required this.lastStoppedAt,
    required this.lastRunAt,
    required this.lastError,
    required this.lastResult,
  });

  final bool enabledByEnv;
  final bool running;
  final bool scanning;
  final int pollIntervalSeconds;
  final bool refresh;
  final DateTime? lastStartedAt;
  final DateTime? lastStoppedAt;
  final DateTime? lastRunAt;
  final String? lastError;
  final Map<String, Object?> lastResult;

  factory StrategyMonitorSchedulerStatus.fromJson(Map<String, dynamic> json) {
    return StrategyMonitorSchedulerStatus(
      enabledByEnv: json['enabled_by_env'] as bool? ?? false,
      running: json['running'] as bool? ?? false,
      scanning: json['scanning'] as bool? ?? false,
      pollIntervalSeconds:
          (json['poll_interval_seconds'] as num?)?.toInt() ?? 60,
      refresh: json['refresh'] as bool? ?? false,
      lastStartedAt: _readDateTime(json['last_started_at']),
      lastStoppedAt: _readDateTime(json['last_stopped_at']),
      lastRunAt: _readDateTime(json['last_run_at']),
      lastError: _nullableString(json['last_error']),
      lastResult: _readMap(json['last_result']),
    );
  }
}

Map<String, Object?> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value.cast<String, Object?>();
  return const {};
}

DateTime? _readDateTime(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

String? _nullableString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
