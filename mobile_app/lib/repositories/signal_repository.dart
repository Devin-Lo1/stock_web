import '../models/signal_scan_result.dart';
import '../models/trade_signal.dart';
import '../services/signal_api_service.dart';

class SignalRepository {
  const SignalRepository(this._apiService);

  final SignalApiService _apiService;

  Future<List<TradeSignal>> loadSignals({
    int limit = 50,
    String? code,
    String? readStatus,
    String? level,
    String? sourceCategory,
    String? strategyCode,
    bool? pushCandidate,
  }) {
    return _apiService.fetchSignalEvents(
      limit: limit,
      code: code,
      readStatus: readStatus,
      level: level,
      sourceCategory: sourceCategory,
      strategyCode: strategyCode,
      pushCandidate: pushCandidate,
    );
  }

  Future<SignalScanResult> scanSignals({bool refresh = false}) {
    return _apiService.scanSignals(refresh: refresh);
  }
}
