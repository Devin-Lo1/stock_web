import '../models/candle.dart';
import '../models/capital_flow.dart';
import '../models/quote_snapshot.dart';
import 'api_client.dart';

class QuoteApiService {
  const QuoteApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, QuoteSnapshot>> fetchQuotes(List<String> codes) async {
    if (codes.isEmpty) return const {};

    final decoded = await _apiClient.get(
      '/api/v1/quotes',
      query: {'codes': codes.join(',')},
    );
    if (decoded is! List) return const {};

    return {
      for (final quote in decoded.whereType<Map<String, dynamic>>().map(
        QuoteSnapshot.fromJson,
      ))
        quote.code.toUpperCase(): quote,
    };
  }

  Future<Map<String, QuoteSnapshot>> refreshQuotes(List<String> codes) async {
    final decoded = await _apiClient.post(
      '/api/v1/quotes/refresh',
      const {},
      query: codes.isEmpty ? null : {'codes': codes.join(',')},
    );
    if (decoded is! List) return const {};

    return {
      for (final quote in decoded.whereType<Map<String, dynamic>>().map(
        QuoteSnapshot.fromJson,
      ))
        quote.code.toUpperCase(): quote,
    };
  }

  Future<List<Candle>> fetchCandles(
    String code, {
    String period = 'day',
    int limit = 120,
    bool includeMock = true,
  }) async {
    final decoded = await _apiClient.get(
      '/api/v1/klines/$code',
      query: {
        'period': period,
        'limit': limit.toString(),
        'include_mock': includeMock.toString(),
      },
    );
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Candle.fromJson)
        .toList();
  }

  Future<List<Candle>> refreshCandles(
    String code, {
    String period = 'day',
    int limit = 240,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = {
        'codes': code,
        'period': period,
        'max_count': limit.toString(),
        if (startDate != null) 'start': _dateText(startDate),
        if (endDate != null) 'end': _dateText(endDate),
      };
      final decoded = await _apiClient.post(
        '/api/v1/klines/refresh',
        const {},
        query: query,
      );
      if (decoded is List) {
        final candles = decoded
            .whereType<Map<String, dynamic>>()
            .map(Candle.fromJson)
            .toList();
        if (candles.isNotEmpty) return candles;
      }
    } catch (_) {
      final cached = await fetchCandles(
        code,
        period: period,
        limit: limit,
        includeMock: false,
      );
      if (cached.isNotEmpty) return cached;
    }

    return fetchCandles(code, period: period, limit: limit);
  }

  Future<CapitalFlowSnapshot> fetchCapitalFlow(String code) async {
    final decoded = await _apiClient.get('/api/v1/quotes/$code/capital-flow');
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid capital flow response');
    }
    return CapitalFlowSnapshot.fromJson(decoded);
  }
}

String _dateText(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
