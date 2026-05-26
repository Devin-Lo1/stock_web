import '../models/backtest_models.dart';
import '../models/strategy_definition.dart';
import 'api_client.dart';

class BacktestApiService {
  const BacktestApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StrategyDefinition>> fetchStrategies() async {
    final decoded = await _apiClient.get('/api/v1/strategies');
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StrategyDefinition.fromJson)
        .toList();
  }

  Future<BacktestResult> runBacktest(BacktestRequest request) async {
    final decoded = await _apiClient.post(
      '/api/v1/backtests',
      request.toJson(),
    );
    if (decoded is Map<String, dynamic>) {
      return BacktestResult.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_BACKTEST_RESPONSE',
      message: '回测结果格式不正确',
    );
  }

  Future<BacktestBatchResult> runBacktestBatch(
    BacktestBatchRequest request,
  ) async {
    final decoded = await _apiClient.post(
      '/api/v1/backtests/batch',
      request.toJson(),
    );
    if (decoded is Map<String, dynamic>) {
      return BacktestBatchResult.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_BACKTEST_BATCH_RESPONSE',
      message: '批量回测结果格式不正确',
    );
  }

  Future<List<BacktestRun>> fetchBacktestRuns({
    String? stockCode,
    String? strategyCode,
    String? status,
    int limit = 30,
  }) async {
    final decoded = await _apiClient.get(
      '/api/v1/backtests',
      query: {
        if (stockCode != null && stockCode.trim().isNotEmpty)
          'stock_code': stockCode.trim().toUpperCase(),
        if (strategyCode != null && strategyCode.trim().isNotEmpty)
          'strategy_code': strategyCode.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'limit': '$limit',
      },
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(BacktestRun.fromJson)
        .toList();
  }

  Future<BacktestResult> fetchBacktestResult(String runId) async {
    final decoded = await _apiClient.get('/api/v1/backtests/$runId');
    if (decoded is Map<String, dynamic>) {
      return BacktestResult.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_BACKTEST_RESPONSE',
      message: '回测结果格式不正确',
    );
  }

  Future<void> deleteBacktestRun(String runId) {
    return _apiClient.delete('/api/v1/backtests/$runId');
  }

  Future<void> deleteAllBacktestRuns() {
    return _apiClient.delete('/api/v1/backtests');
  }

  Future<BacktestRun> renameBacktestRun(String runId, String name) async {
    final decoded = await _apiClient.put('/api/v1/backtests/$runId/name', {
      'name': name,
    });
    if (decoded is Map<String, dynamic>) {
      return BacktestRun.fromJson(decoded);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'INVALID_BACKTEST_RESPONSE',
      message: '回测结果格式不正确',
    );
  }
}
