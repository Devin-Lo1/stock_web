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
}
