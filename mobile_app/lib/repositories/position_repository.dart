import '../data/sample_positions.dart';
import '../models/position_snapshot.dart';
import '../models/position_trade.dart';
import '../models/quote_snapshot.dart';
import '../models/stock_position.dart';
import '../services/position_api_service.dart';
import '../services/position_storage_service.dart';
import '../services/quote_api_service.dart';

class PositionRepository {
  const PositionRepository({
    required PositionStorageService storageService,
    PositionApiService? apiService,
    QuoteApiService? quoteApiService,
  }) : _storageService = storageService,
       _apiService = apiService,
       _quoteApiService = quoteApiService;

  final PositionStorageService _storageService;
  final PositionApiService? _apiService;
  final QuoteApiService? _quoteApiService;

  Future<PositionLoadResult> loadPositions() async {
    if (_apiService != null) {
      try {
        final remotePositions = await _apiService.fetchPositions();
        if (remotePositions.isNotEmpty) {
          Object? refreshError;
          try {
            await _refreshQuotes(remotePositions);
          } catch (error) {
            refreshError = error;
          }
          final quotedPositions = await _attachQuotes(remotePositions);
          final snapshots = await _loadPositionSnapshots();
          final enrichedPositions = _attachSnapshots(
            quotedPositions,
            snapshots,
          );
          await _storageService.savePositions(enrichedPositions);
          return PositionLoadResult.remote(
            enrichedPositions,
            warning: refreshError,
          );
        }
      } catch (error) {
        // Keep the app usable while the mock backend is offline.
        final storedPositions = await _storageService.loadPositions();
        return PositionLoadResult.local(
          _stripBackendMetrics(storedPositions ?? List.of(samplePositions)),
          error: error,
        );
      }
    }

    final storedPositions = await _storageService.loadPositions();
    return PositionLoadResult.local(
      _stripBackendMetrics(storedPositions ?? List.of(samplePositions)),
    );
  }

  Future<void> savePositions(List<StockPosition> positions) {
    return _storageService.savePositions(positions);
  }

  Future<StockPosition> createPosition(
    StockPosition position,
    List<StockPosition> currentPositions,
  ) async {
    final apiService = _apiService;
    if (apiService == null) return position;

    final created = _mergeBackendPosition(
      await apiService.createPosition(position),
      position,
    );
    final quoted = await _attachQuotes([created]);
    final enriched = _attachSnapshots(
      quoted,
      await _loadPositionSnapshots(),
    ).first;
    await _storageService.savePositions([enriched, ...currentPositions]);
    return enriched;
  }

  Future<StockPosition> updatePosition(
    StockPosition original,
    StockPosition updated,
    List<StockPosition> currentPositions,
  ) async {
    final apiService = _apiService;
    final positionId = original.id;
    if (apiService == null || positionId == null) return updated;

    final remoteUpdated = _mergeBackendPosition(
      await apiService.updatePosition(positionId, updated),
      updated,
    );
    final quoted = await _attachQuotes([remoteUpdated]);
    final enriched = _attachSnapshots(
      quoted,
      await _loadPositionSnapshots(),
    ).first;
    await _storageService.savePositions(
      currentPositions
          .map((position) => position.id == positionId ? enriched : position)
          .toList(),
    );
    return enriched;
  }

  Future<void> deletePosition(
    StockPosition position,
    List<StockPosition> remainingPositions,
  ) async {
    final apiService = _apiService;
    final positionId = position.id;
    if (apiService != null && positionId != null) {
      await apiService.deletePosition(positionId);
    }
    await _storageService.savePositions(remainingPositions);
  }

  Future<List<StockPosition>> _attachQuotes(
    List<StockPosition> positions,
  ) async {
    if (_quoteApiService == null) return positions;

    final quotes = await _quoteApiService.fetchQuotes(
      positions.map((position) => position.code).toList(),
    );
    if (quotes.isEmpty) return positions;

    return positions.map((position) {
      final quote = quotes[position.code.toUpperCase()];
      if (quote == null) return position;
      return _positionWithQuote(position, quote);
    }).toList();
  }

  Future<void> _refreshQuotes(List<StockPosition> positions) async {
    if (_quoteApiService == null) return;
    await _quoteApiService.refreshQuotes(
      positions.map((position) => position.code).toList(),
    );
  }

  Future<List<PositionSnapshot>> _loadPositionSnapshots() async {
    final apiService = _apiService;
    if (apiService == null) return const [];
    try {
      return await apiService.capturePositionSnapshots();
    } catch (_) {
      try {
        return await apiService.fetchLatestPositionSnapshots();
      } catch (_) {
        return const [];
      }
    }
  }

  Future<List<PositionTrade>> loadPositionTrades(
    StockPosition position, {
    int limit = 50,
  }) async {
    final apiService = _apiService;
    final positionId = position.id;
    if (apiService == null || positionId == null) return const [];
    return apiService.fetchPositionTrades(positionId, limit: limit);
  }

  Future<List<PositionSnapshot>> loadPositionSnapshotHistory(
    StockPosition position, {
    int limit = 80,
  }) async {
    final apiService = _apiService;
    final positionId = position.id;
    if (apiService == null || positionId == null) return const [];
    return apiService.fetchPositionSnapshots(positionId, limit: limit);
  }

  Future<PositionTradeMutationResult> createPositionTrade(
    StockPosition position,
    PositionTradeDraft draft,
  ) async {
    final apiService = _apiService;
    final positionId = position.id;
    if (apiService == null || positionId == null) {
      return PositionTradeMutationResult(
        positions: const [],
        trade: null,
        updatedPosition: null,
      );
    }
    final trade = await apiService.createPositionTrade(positionId, draft);
    final refreshed = await loadPositions();
    return PositionTradeMutationResult(
      positions: refreshed.positions,
      trade: trade,
      updatedPosition: _findLatestPosition(refreshed.positions, position),
    );
  }

  Future<PositionTradeMutationResult> deletePositionTrade(
    StockPosition position,
    PositionTrade trade,
  ) async {
    final apiService = _apiService;
    final positionId = position.id;
    if (apiService == null || positionId == null) {
      return PositionTradeMutationResult(
        positions: const [],
        trade: null,
        updatedPosition: null,
      );
    }
    await apiService.deletePositionTrade(positionId, trade.id);
    final refreshed = await loadPositions();
    return PositionTradeMutationResult(
      positions: refreshed.positions,
      trade: trade,
      updatedPosition: _findLatestPosition(refreshed.positions, position),
    );
  }
}

class PositionLoadResult {
  const PositionLoadResult({
    required this.positions,
    required this.source,
    this.error,
  });

  factory PositionLoadResult.remote(
    List<StockPosition> positions, {
    Object? warning,
  }) {
    return PositionLoadResult(
      positions: positions,
      source: PositionLoadSource.remote,
      error: warning,
    );
  }

  factory PositionLoadResult.local(
    List<StockPosition> positions, {
    Object? error,
  }) {
    return PositionLoadResult(
      positions: positions,
      source: PositionLoadSource.local,
      error: error,
    );
  }

  final List<StockPosition> positions;
  final PositionLoadSource source;
  final Object? error;

  bool get isRemote => source == PositionLoadSource.remote;
}

enum PositionLoadSource { remote, local }

class PositionTradeMutationResult {
  const PositionTradeMutationResult({
    required this.positions,
    required this.trade,
    required this.updatedPosition,
  });

  final List<StockPosition> positions;
  final PositionTrade? trade;
  final StockPosition? updatedPosition;
}

StockPosition _positionWithQuote(StockPosition position, QuoteSnapshot quote) {
  return StockPosition(
    id: position.id,
    name: position.name,
    code: position.code,
    quantity: position.quantity,
    costPrice: position.costPrice,
    avgCostPrice: position.avgCostPrice,
    adjustedCostPrice: position.adjustedCostPrice,
    realizedProfit: position.realizedProfit,
    currentPrice: quote.currentPrice,
    previousClose: quote.previousClose,
    openPrice: quote.open,
    highPrice: quote.high,
    lowPrice: quote.low,
    volume: quote.volume,
    turnover: quote.turnover,
    turnoverRate: quote.turnoverRate,
    peRatio: quote.peRatio,
    lotSize: quote.lotSize,
    changeRate: quote.changeRate,
    signal: position.signal,
    snapshotMarketValue: position.snapshotMarketValue,
    snapshotDayProfit: position.snapshotDayProfit,
    snapshotDayProfitRate: position.snapshotDayProfitRate,
    snapshotHoldingProfit: position.snapshotHoldingProfit,
    snapshotHoldingProfitRate: position.snapshotHoldingProfitRate,
    snapshotTotalProfit: position.snapshotTotalProfit,
    snapshotTotalProfitRate: position.snapshotTotalProfitRate,
    snapshotPositionWeight: position.snapshotPositionWeight,
    snapshotTime: position.snapshotTime,
  );
}

List<StockPosition> _stripBackendMetrics(List<StockPosition> positions) {
  return positions.map(_positionWithoutBackendMetrics).toList();
}

StockPosition _positionWithoutBackendMetrics(StockPosition position) {
  return StockPosition(
    id: position.id,
    name: position.name,
    code: position.code,
    quantity: position.quantity,
    costPrice: position.costPrice,
    avgCostPrice: position.avgCostPrice,
    adjustedCostPrice: position.adjustedCostPrice,
    realizedProfit: position.realizedProfit,
    currentPrice: position.currentPrice,
    previousClose: position.previousClose,
    openPrice: position.openPrice,
    highPrice: position.highPrice,
    lowPrice: position.lowPrice,
    volume: position.volume,
    turnover: position.turnover,
    turnoverRate: position.turnoverRate,
    peRatio: position.peRatio,
    lotSize: position.lotSize,
    changeRate: position.changeRate,
    signal: position.signal,
  );
}

StockPosition _mergeBackendPosition(
  StockPosition backendPosition,
  StockPosition localPosition,
) {
  return StockPosition(
    id: backendPosition.id,
    name: backendPosition.name,
    code: backendPosition.code,
    quantity: backendPosition.quantity,
    costPrice: backendPosition.costPrice,
    avgCostPrice: backendPosition.avgCostPrice,
    adjustedCostPrice: backendPosition.adjustedCostPrice,
    realizedProfit: backendPosition.realizedProfit,
    currentPrice: localPosition.currentPrice,
    previousClose: localPosition.previousClose,
    openPrice: localPosition.openPrice,
    highPrice: localPosition.highPrice,
    lowPrice: localPosition.lowPrice,
    volume: localPosition.volume,
    turnover: localPosition.turnover,
    turnoverRate: localPosition.turnoverRate,
    peRatio: localPosition.peRatio,
    lotSize: localPosition.lotSize,
    changeRate: localPosition.changeRate,
    signal: localPosition.signal,
  );
}

List<StockPosition> _attachSnapshots(
  List<StockPosition> positions,
  List<PositionSnapshot> snapshots,
) {
  if (snapshots.isEmpty) return positions;
  final byPositionId = <String, PositionSnapshot>{};
  final byCode = <String, PositionSnapshot>{};
  for (final snapshot in snapshots) {
    byPositionId[snapshot.positionId] = snapshot;
    byCode[snapshot.code.toUpperCase()] = snapshot;
  }
  return positions.map((position) {
    final snapshot = position.id == null ? null : byPositionId[position.id!];
    return _positionWithSnapshot(
      position,
      snapshot ?? byCode[position.code.toUpperCase()],
    );
  }).toList();
}

StockPosition _positionWithSnapshot(
  StockPosition position,
  PositionSnapshot? snapshot,
) {
  if (snapshot == null) return position;
  return StockPosition(
    id: position.id,
    name: position.name,
    code: position.code,
    quantity: snapshot.quantity,
    costPrice: snapshot.adjustedCostPrice,
    avgCostPrice: snapshot.avgCostPrice,
    adjustedCostPrice: snapshot.adjustedCostPrice,
    realizedProfit: snapshot.realizedProfit,
    currentPrice: snapshot.currentPrice,
    previousClose: snapshot.previousClose,
    openPrice: position.openPrice,
    highPrice: position.highPrice,
    lowPrice: position.lowPrice,
    volume: position.volume,
    turnover: position.turnover,
    turnoverRate: position.turnoverRate,
    peRatio: position.peRatio,
    lotSize: position.lotSize,
    changeRate: position.changeRate,
    signal: position.signal,
    snapshotMarketValue: snapshot.marketValue,
    snapshotDayProfit: snapshot.dayProfit,
    snapshotDayProfitRate: snapshot.dayProfitRate,
    snapshotHoldingProfit: snapshot.holdingProfit,
    snapshotHoldingProfitRate: snapshot.holdingProfitRate,
    snapshotTotalProfit: snapshot.totalProfit,
    snapshotTotalProfitRate: snapshot.totalProfitRate,
    snapshotPositionWeight: snapshot.positionWeight,
    snapshotTime: snapshot.snapshotTime,
  );
}

StockPosition? _findLatestPosition(
  List<StockPosition> positions,
  StockPosition current,
) {
  for (final position in positions) {
    if (current.id != null && position.id == current.id) return position;
  }
  for (final position in positions) {
    if (position.code.toUpperCase() == current.code.toUpperCase()) {
      return position;
    }
  }
  return null;
}
