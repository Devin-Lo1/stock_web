import '../models/signal_scan_result.dart';
import '../models/signal_scan_config.dart';
import '../models/trade_signal.dart';
import '../services/signal_api_service.dart';

class SignalRepository {
  const SignalRepository(this._apiService);

  final SignalApiService _apiService;

  Future<List<TradeSignal>> loadSignals({
    int limit = 50,
    String? code,
    String? signalType,
    String? readStatus,
    String? level,
    String? sourceCategory,
    String? strategyCode,
    bool? pushCandidate,
  }) {
    return _apiService.fetchSignalEvents(
      limit: limit,
      code: code,
      signalType: signalType,
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

  Future<TradeSignal> ignoreSignalEvent(String eventId) {
    return _apiService.ignoreSignalEvent(eventId);
  }

  Future<List<SignalScanConfig>> loadScanConfigs() {
    return _apiService.fetchSignalScanConfigs();
  }

  Future<SignalScanConfig> updateScanConfig(
    String configId, {
    bool? enabled,
    bool? pushCandidate,
  }) {
    return _apiService.updateSignalScanConfig(
      configId,
      enabled: enabled,
      pushCandidate: pushCandidate,
    );
  }
}
