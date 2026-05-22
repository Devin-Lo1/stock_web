import '../models/strategy_monitor.dart';
import 'api_client.dart';

class StrategyMonitorApiService {
  const StrategyMonitorApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StrategyMonitor>> fetchMonitors({
    String? positionId,
    String? code,
    String? strategyCode,
    bool enabledOnly = false,
    int limit = 100,
  }) async {
    final decoded = await _apiClient.get(
      '/api/v1/strategies/monitors',
      query: {
        'limit': '$limit',
        if (positionId != null && positionId.trim().isNotEmpty)
          'position_id': positionId.trim(),
        if (code != null && code.trim().isNotEmpty)
          'code': code.trim().toUpperCase(),
        if (strategyCode != null && strategyCode.trim().isNotEmpty)
          'strategy_code': strategyCode.trim(),
        if (enabledOnly) 'enabled_only': 'true',
      },
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StrategyMonitor.fromJson)
        .toList();
  }

  Future<StrategyMonitor> createMonitor(
    StrategyMonitorCreateRequest request,
  ) async {
    final decoded = await _apiClient.post(
      '/api/v1/strategies/monitors',
      request.toJson(),
    );
    if (decoded is Map<String, dynamic>) {
      return StrategyMonitor.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_STRATEGY_MONITOR_RESPONSE',
      message: '策略监控结果格式不正确',
    );
  }

  Future<StrategyMonitor> updateMonitor(
    String monitorId, {
    String? positionId,
    String? market,
    String? code,
    String? name,
    String? strategyCode,
    String? strategyName,
    Map<String, Object?>? parameters,
    String? period,
    bool? enabled,
    bool? pushCandidate,
    int? scanIntervalMinutes,
    int? cooldownMinutes,
  }) async {
    final body = <String, dynamic>{};
    if (positionId != null && positionId.trim().isNotEmpty) {
      body['position_id'] = positionId.trim();
    }
    if (market != null) body['market'] = market;
    if (code != null) body['code'] = code;
    if (name != null) body['name'] = name;
    if (strategyCode != null) body['strategy_code'] = strategyCode;
    if (strategyName != null) body['strategy_name'] = strategyName;
    if (parameters != null) body['parameters'] = parameters;
    if (period != null) body['period'] = period;
    if (enabled != null) body['enabled'] = enabled;
    if (pushCandidate != null) body['push_candidate'] = pushCandidate;
    if (scanIntervalMinutes != null) {
      body['scan_interval_minutes'] = scanIntervalMinutes;
    }
    if (cooldownMinutes != null) body['cooldown_minutes'] = cooldownMinutes;
    final decoded = await _apiClient.put(
      '/api/v1/strategies/monitors/$monitorId',
      body,
    );
    if (decoded is Map<String, dynamic>) {
      return StrategyMonitor.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_STRATEGY_MONITOR_RESPONSE',
      message: '策略监控结果格式不正确',
    );
  }

  Future<void> deleteMonitor(String monitorId) {
    return _apiClient.delete('/api/v1/strategies/monitors/$monitorId');
  }

  Future<List<StrategyMonitorScanLog>> fetchScanLogs({
    String? monitorId,
    String? code,
    String? status,
    int limit = 10,
  }) async {
    final decoded = await _apiClient.get(
      '/api/v1/strategies/monitors/scan-logs',
      query: {
        'limit': '$limit',
        if (monitorId != null && monitorId.trim().isNotEmpty)
          'monitor_id': monitorId.trim(),
        if (code != null && code.trim().isNotEmpty)
          'code': code.trim().toUpperCase(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StrategyMonitorScanLog.fromJson)
        .toList();
  }

  Future<void> deleteScanLog(String logId) {
    return _apiClient.delete('/api/v1/strategies/monitors/scan-logs/$logId');
  }

  Future<StrategyMonitorSchedulerStatus> fetchSchedulerStatus() async {
    final decoded = await _apiClient.get(
      '/api/v1/strategies/monitors/scheduler/status',
    );
    if (decoded is Map<String, dynamic>) {
      return StrategyMonitorSchedulerStatus.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_STRATEGY_SCHEDULER_RESPONSE',
      message: '策略监控调度状态格式不正确',
    );
  }

  Future<StrategyMonitorSchedulerStatus> startScheduler({
    int? pollIntervalSeconds,
    bool? refresh,
  }) async {
    final body = <String, dynamic>{};
    if (pollIntervalSeconds != null) {
      body['poll_interval_seconds'] = pollIntervalSeconds;
    }
    if (refresh != null) body['refresh'] = refresh;
    final decoded = await _apiClient.post(
      '/api/v1/strategies/monitors/scheduler/start',
      body,
    );
    if (decoded is Map<String, dynamic>) {
      return StrategyMonitorSchedulerStatus.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_STRATEGY_SCHEDULER_RESPONSE',
      message: '策略监控调度状态格式不正确',
    );
  }

  Future<StrategyMonitorSchedulerStatus> stopScheduler() async {
    final decoded = await _apiClient.post(
      '/api/v1/strategies/monitors/scheduler/stop',
      const {},
    );
    if (decoded is Map<String, dynamic>) {
      return StrategyMonitorSchedulerStatus.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_STRATEGY_SCHEDULER_RESPONSE',
      message: '策略监控调度状态格式不正确',
    );
  }

  Future<StrategyMonitorSchedulerStatus> runSchedulerOnce({
    int? pollIntervalSeconds,
    bool? refresh,
    bool force = true,
  }) async {
    final body = <String, dynamic>{};
    if (pollIntervalSeconds != null) {
      body['poll_interval_seconds'] = pollIntervalSeconds;
    }
    if (refresh != null) body['refresh'] = refresh;
    final decoded = await _apiClient.post(
      '/api/v1/strategies/monitors/scheduler/run-once',
      body,
      query: {'force': '$force'},
    );
    if (decoded is Map<String, dynamic>) {
      return StrategyMonitorSchedulerStatus.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_STRATEGY_SCHEDULER_RESPONSE',
      message: '策略监控调度状态格式不正确',
    );
  }
}
