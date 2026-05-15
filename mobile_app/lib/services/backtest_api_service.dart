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
}
