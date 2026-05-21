import '../models/signal_scan_result.dart';
import '../models/signal_scan_config.dart';
import '../models/trade_signal.dart';
import 'api_client.dart';

class SignalApiService {
  const SignalApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<TradeSignal>> fetchSignalEvents({
    int limit = 50,
    String? code,
    String? signalType,
    String? readStatus,
    String? level,
    String? sourceCategory,
    String? strategyCode,
    bool? pushCandidate,
  }) async {
    final decoded = await _apiClient.get(
      '/api/v1/signals/events',
      query: {
        'limit': limit.toString(),
        if (code != null && code.isNotEmpty) 'code': code,
        if (signalType != null && signalType.isNotEmpty)
          'signal_type': signalType,
        if (readStatus != null && readStatus.isNotEmpty)
          'read_status': readStatus,
        if (level != null && level.isNotEmpty) 'level': level,
        if (sourceCategory != null && sourceCategory.isNotEmpty)
          'source_category': sourceCategory,
        if (strategyCode != null && strategyCode.isNotEmpty)
          'strategy_code': strategyCode,
        if (pushCandidate != null) 'push_candidate': pushCandidate.toString(),
      },
    );
    return (decoded as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TradeSignal.fromSignalEvent)
        .toList();
  }

  Future<List<SignalScanConfig>> fetchSignalScanConfigs() async {
    final decoded = await _apiClient.get('/api/v1/signals/configs');
    return (decoded as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SignalScanConfig.fromJson)
        .toList();
  }

  Future<SignalScanConfig> updateSignalScanConfig(
    String configId, {
    bool? enabled,
    bool? pushCandidate,
  }) async {
    final body = <String, dynamic>{};
    if (enabled != null) body['enabled'] = enabled;
    if (pushCandidate != null) body['push_candidate'] = pushCandidate;
    final decoded = await _apiClient.put(
      '/api/v1/signals/configs/$configId',
      body,
    );
    return SignalScanConfig.fromJson(
      (decoded as Map<String, dynamic>?) ?? const {},
    );
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
