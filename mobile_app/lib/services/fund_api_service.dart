import '../models/fund_models.dart';
import 'api_client.dart';

class FundApiService {
  const FundApiService(this._client);

  final ApiClient _client;

  Future<List<FundSearchResult>> searchFunds(String query) async {
    final payload = await _client.get(
      '/api/v1/funds/search',
      query: {'query': query, 'limit': '20'},
    );
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(FundSearchResult.fromJson)
        .toList();
  }

  Future<List<FundPositionSummary>> fetchPositionSummaries({
    bool refresh = true,
  }) async {
    final payload = await _client.get(
      '/api/v1/funds/positions/summary',
      query: {'refresh': '$refresh'},
    );
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(FundPositionSummary.fromJson)
        .toList();
  }

  Future<FundAlertSchedulerStatus> fetchAlertSchedulerStatus() async {
    final payload = await _client.get('/api/v1/funds/alerts/scheduler/status');
    return FundAlertSchedulerStatus.fromJson(payload as Map<String, dynamic>);
  }

  Future<FundAlertSchedulerStatus> updateAlertScheduler(
    FundAlertSchedulerDraft draft,
  ) async {
    final payload = await _client.put(
      '/api/v1/funds/alerts/scheduler/config',
      draft.toJson(),
    );
    return FundAlertSchedulerStatus.fromJson(payload as Map<String, dynamic>);
  }

  Future<FundAlertSchedulerStatus> runAlertScan({bool refresh = true}) async {
    final payload = await _client.post(
      '/api/v1/funds/alerts/scheduler/run-once',
      const {},
      query: {'refresh': '$refresh'},
    );
    return FundAlertSchedulerStatus.fromJson(payload as Map<String, dynamic>);
  }

  Future<List<FundNavPoint>> fetchNavs(
    String fundCode, {
    int limit = 180,
    bool refresh = false,
  }) async {
    final payload = await _client.get(
      '/api/v1/funds/$fundCode/navs',
      query: {'limit': '$limit', 'refresh': '$refresh'},
    );
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(FundNavPoint.fromJson)
        .toList();
  }

  Future<List<FundBenchmarkPoint>> fetchHs300Benchmark({
    int limit = 370,
  }) async {
    final payload = await _client.get(
      '/api/v1/funds/benchmarks/hs300/navs',
      query: {'limit': '$limit'},
    );
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(FundBenchmarkPoint.fromJson)
        .toList();
  }

  Future<List<FundTrade>> fetchTrades(
    String positionId, {
    int limit = 100,
  }) async {
    final payload = await _client.get(
      '/api/v1/funds/positions/$positionId/trades',
      query: {'limit': '$limit'},
    );
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(FundTrade.fromJson)
        .toList();
  }

  Future<FundPosition> createPosition({
    required FundSearchResult fund,
    required double shares,
    required double costNav,
    double amount = 0,
    required double fee,
    bool autoNav = false,
    DateTime? tradeDate,
    DateTime? operationDate,
    bool operationAfterCutoff = false,
    String note = '',
  }) async {
    final payload = await _client.post('/api/v1/funds/positions', {
      'fund_code': fund.code,
      'name': fund.name,
      'fund_type': fund.fundType,
      'shares': shares,
      'cost_nav': costNav,
      'amount': amount,
      'fee': fee,
      'auto_nav': autoNav,
      if (tradeDate != null) 'trade_date': _dateString(tradeDate),
      if (operationDate != null) 'operation_date': _dateString(operationDate),
      'operation_after_cutoff': operationAfterCutoff,
      if (note.isNotEmpty) 'note': note,
    });
    return FundPosition.fromJson(payload as Map<String, dynamic>);
  }

  Future<void> deletePosition(String positionId) {
    return _client.delete('/api/v1/funds/positions/$positionId');
  }

  Future<FundPosition> updateAlertSettings(
    String positionId,
    FundAlertSettingsDraft draft,
  ) async {
    final payload = await _client.put(
      '/api/v1/funds/positions/$positionId',
      draft.toJson(),
    );
    return FundPosition.fromJson(payload as Map<String, dynamic>);
  }

  Future<void> createTrade(String positionId, FundTradeDraft draft) async {
    await _client.post(
      '/api/v1/funds/positions/$positionId/trades',
      draft.toJson(),
    );
  }
}

String _dateString(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
