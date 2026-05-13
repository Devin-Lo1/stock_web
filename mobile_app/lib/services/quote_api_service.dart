import '../models/candle.dart';
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
  }) async {
    final decoded = await _apiClient.get(
      '/api/v1/klines/$code',
      query: {'period': period, 'limit': limit.toString()},
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
  }) async {
    final cached = await fetchCandles(code, period: period, limit: limit);
    if (cached.isNotEmpty) return cached;

    final decoded = await _apiClient.post(
      '/api/v1/klines/refresh',
      const {},
      query: {'codes': code, 'period': period, 'max_count': limit.toString()},
    );
    if (decoded is! List) {
      return fetchCandles(code, period: period, limit: limit);
    }

    final candles = decoded
        .whereType<Map<String, dynamic>>()
        .map(Candle.fromJson)
        .toList();
    if (candles.isNotEmpty) return candles;
    return fetchCandles(code, period: period, limit: limit);
  }
}
