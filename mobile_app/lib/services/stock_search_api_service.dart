import '../models/stock_search_result.dart';
import 'api_client.dart';

class StockSearchApiService {
  const StockSearchApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StockSearchResult>> search(
    String query, {
    int limit = 20,
    bool includeDerivatives = false,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final decoded = await _apiClient.get(
      '/api/v1/stocks/search',
      query: {
        'q': normalizedQuery,
        'limit': limit.toString(),
        'include_derivatives': includeDerivatives.toString(),
      },
    );
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StockSearchResult.fromJson)
        .toList();
  }
}
