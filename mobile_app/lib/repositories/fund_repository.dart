import '../models/fund_models.dart';
import '../services/fund_api_service.dart';

class FundRepository {
  const FundRepository(this._apiService);

  final FundApiService _apiService;

  Future<List<FundSearchResult>> searchFunds(String query) {
    return _apiService.searchFunds(query);
  }

  Future<List<FundPositionSummary>> loadSummaries({bool refresh = true}) {
    return _apiService.fetchPositionSummaries(refresh: refresh);
  }

  Future<FundAlertSchedulerStatus> loadAlertSchedulerStatus() {
    return _apiService.fetchAlertSchedulerStatus();
  }

  Future<FundAlertSchedulerStatus> updateAlertScheduler(
    FundAlertSchedulerDraft draft,
  ) {
    return _apiService.updateAlertScheduler(draft);
  }

  Future<FundAlertSchedulerStatus> runAlertScan({bool refresh = true}) {
    return _apiService.runAlertScan(refresh: refresh);
  }

  Future<List<FundNavPoint>> loadNavs(
    String fundCode, {
    int limit = 180,
    bool refresh = false,
  }) {
    return _apiService.fetchNavs(fundCode, limit: limit, refresh: refresh);
  }

  Future<List<FundTrade>> loadTrades(String positionId, {int limit = 100}) {
    return _apiService.fetchTrades(positionId, limit: limit);
  }

  Future<FundPosition> createPosition({
    required FundSearchResult fund,
    required double shares,
    required double costNav,
    required double fee,
    DateTime? tradeDate,
    String note = '',
  }) {
    return _apiService.createPosition(
      fund: fund,
      shares: shares,
      costNav: costNav,
      fee: fee,
      tradeDate: tradeDate,
      note: note,
    );
  }

  Future<void> deletePosition(String positionId) {
    return _apiService.deletePosition(positionId);
  }

  Future<FundPosition> updateAlertSettings(
    String positionId,
    FundAlertSettingsDraft draft,
  ) {
    return _apiService.updateAlertSettings(positionId, draft);
  }

  Future<void> createTrade(String positionId, FundTradeDraft draft) {
    return _apiService.createTrade(positionId, draft);
  }
}
