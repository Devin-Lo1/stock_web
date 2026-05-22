import '../models/strategy_monitor.dart';
import '../services/strategy_monitor_api_service.dart';

class StrategyMonitorRepository {
  const StrategyMonitorRepository(this._apiService);

  final StrategyMonitorApiService _apiService;

  Future<List<StrategyMonitor>> loadMonitors({
    String? positionId,
    String? code,
    String? strategyCode,
    bool enabledOnly = false,
    int limit = 100,
  }) {
    return _apiService.fetchMonitors(
      positionId: positionId,
      code: code,
      strategyCode: strategyCode,
      enabledOnly: enabledOnly,
      limit: limit,
    );
  }

  Future<StrategyMonitor> createMonitor(StrategyMonitorCreateRequest request) {
    return _apiService.createMonitor(request);
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
  }) {
    return _apiService.updateMonitor(
      monitorId,
      positionId: positionId,
      market: market,
      code: code,
      name: name,
      strategyCode: strategyCode,
      strategyName: strategyName,
      parameters: parameters,
      period: period,
      enabled: enabled,
      pushCandidate: pushCandidate,
      scanIntervalMinutes: scanIntervalMinutes,
      cooldownMinutes: cooldownMinutes,
    );
  }

  Future<void> deleteMonitor(String monitorId) {
    return _apiService.deleteMonitor(monitorId);
  }

  Future<List<StrategyMonitorScanLog>> loadScanLogs({
    String? monitorId,
    String? code,
    String? status,
    int limit = 10,
  }) {
    return _apiService.fetchScanLogs(
      monitorId: monitorId,
      code: code,
      status: status,
      limit: limit,
    );
  }

  Future<void> deleteScanLog(String logId) {
    return _apiService.deleteScanLog(logId);
  }

  Future<StrategyMonitorSchedulerStatus> loadSchedulerStatus() {
    return _apiService.fetchSchedulerStatus();
  }

  Future<StrategyMonitorSchedulerStatus> startScheduler({
    int? pollIntervalSeconds,
    bool? refresh,
  }) {
    return _apiService.startScheduler(
      pollIntervalSeconds: pollIntervalSeconds,
      refresh: refresh,
    );
  }

  Future<StrategyMonitorSchedulerStatus> stopScheduler() {
    return _apiService.stopScheduler();
  }

  Future<StrategyMonitorSchedulerStatus> runSchedulerOnce({
    int? pollIntervalSeconds,
    bool? refresh,
    bool force = true,
  }) {
    return _apiService.runSchedulerOnce(
      pollIntervalSeconds: pollIntervalSeconds,
      refresh: refresh,
      force: force,
    );
  }
}
