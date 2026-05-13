import '../data/sample_positions.dart';
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
          final enrichedPositions = await _attachQuotes(remotePositions);
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
          storedPositions ?? List.of(samplePositions),
          error: error,
        );
      }
    }

    final storedPositions = await _storageService.loadPositions();
    return PositionLoadResult.local(
      storedPositions ?? List.of(samplePositions),
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
    final enriched = (await _attachQuotes([created])).first;
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
    final enriched = (await _attachQuotes([remoteUpdated])).first;
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

StockPosition _positionWithQuote(StockPosition position, QuoteSnapshot quote) {
  return StockPosition(
    id: position.id,
    name: position.name,
    code: position.code,
    quantity: position.quantity,
    costPrice: position.costPrice,
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
