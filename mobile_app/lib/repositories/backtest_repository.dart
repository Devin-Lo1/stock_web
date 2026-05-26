import '../models/backtest_models.dart';
import '../models/strategy_definition.dart';
import '../services/backtest_api_service.dart';

class BacktestRepository {
  const BacktestRepository(this._apiService);

  final BacktestApiService _apiService;

  Future<List<StrategyDefinition>> loadStrategies() {
    return _apiService.fetchStrategies();
  }

  Future<BacktestResult> runBacktest(BacktestRequest request) {
    return _apiService.runBacktest(request);
  }

  Future<BacktestBatchResult> runBacktestBatch(BacktestBatchRequest request) {
    return _apiService.runBacktestBatch(request);
  }

  Future<List<BacktestRun>> loadBacktestRuns({
    String? stockCode,
    String? strategyCode,
    String? status,
    int limit = 30,
  }) {
    return _apiService.fetchBacktestRuns(
      stockCode: stockCode,
      strategyCode: strategyCode,
      status: status,
      limit: limit,
    );
  }

  Future<BacktestResult> loadBacktestResult(String runId) {
    return _apiService.fetchBacktestResult(runId);
  }

  Future<void> deleteBacktestRun(String runId) {
    return _apiService.deleteBacktestRun(runId);
  }

  Future<void> deleteAllBacktestRuns() {
    return _apiService.deleteAllBacktestRuns();
  }

  Future<BacktestRun> renameBacktestRun(String runId, String name) {
    return _apiService.renameBacktestRun(runId, name);
  }
}
