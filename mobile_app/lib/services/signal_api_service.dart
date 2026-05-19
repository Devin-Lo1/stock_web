import '../models/signal_scan_result.dart';
import '../models/trade_signal.dart';
import 'api_client.dart';

class SignalApiService {
  const SignalApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<TradeSignal>> fetchSignalEvents({int limit = 50}) async {
    final decoded = await _apiClient.get(
      '/api/v1/signals/events',
      query: {'limit': limit.toString()},
    );
    return (decoded as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TradeSignal.fromSignalEvent)
        .toList();
  }

  Future<SignalScanResult> scanSignals({bool refresh = false}) async {
    final decoded = await _apiClient.post(
      '/api/v1/signals/scan',
      const {},
      query: {'refresh': refresh.toString()},
    );
    return SignalScanResult.fromJson(
      (decoded as Map<String, dynamic>?) ?? const {},
    );
  }
}
