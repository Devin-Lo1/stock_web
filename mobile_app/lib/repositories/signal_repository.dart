import '../models/signal_scan_result.dart';
import '../models/trade_signal.dart';
import '../services/signal_api_service.dart';

class SignalRepository {
  const SignalRepository(this._apiService);

  final SignalApiService _apiService;

  Future<List<TradeSignal>> loadSignals({int limit = 50}) {
    return _apiService.fetchSignalEvents(limit: limit);
  }

  Future<SignalScanResult> scanSignals({bool refresh = false}) {
    return _apiService.scanSignals(refresh: refresh);
  }
}
