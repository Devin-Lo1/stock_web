import '../data/stock_suggestion_catalog.dart';
import '../models/stock_suggestion.dart';

const _marketPrefixTokens = {'HK.', 'US.', 'SH.', 'SZ.', 'CN.'};

List<StockSuggestion> searchStockSuggestions(String query) {
  final normalizedQuery = query.trim().toUpperCase();
  if (normalizedQuery.isEmpty) return const [];
  final tokens = normalizedQuery
      .split(RegExp(r'\s+'))
      .where(
        (token) => token.isNotEmpty && !_marketPrefixTokens.contains(token),
      )
      .toList();
  if (tokens.isEmpty) return const [];
  final seenCodes = <String>{};
  final matches = <StockSuggestion>[];

  for (final suggestion in stockSuggestionCatalog) {
    final code = suggestion.code.toUpperCase();
    final name = suggestion.name.toUpperCase();
    final codeDigits = code.replaceAll(RegExp(r'[^0-9]'), '');
    final isMatch = tokens.any((token) {
      final digitToken = token.replaceAll(RegExp(r'[^0-9]'), '');
      return code.contains(token) ||
          name.contains(token) ||
          (digitToken.isNotEmpty && codeDigits.contains(digitToken));
    });
    if (!isMatch || !seenCodes.add(code)) continue;
    matches.add(suggestion);
    if (matches.length >= 6) break;
  }

  return matches;
}

String normalizedStockSearchQuery(String query) {
  return query
      .trim()
      .split(RegExp(r'\s+'))
      .where(
        (token) => token.isNotEmpty && !_marketPrefixTokens.contains(token),
      )
      .join(' ');
}

bool shouldIncludeStockDerivatives(String query) {
  final normalizedQuery = query.trim().toUpperCase();
  final digitQuery = normalizedQuery.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitQuery.length >= 5) return true;
  if (normalizedQuery.startsWith('HK.') && digitQuery.length >= 4) {
    return true;
  }
  return normalizedQuery.contains('购') ||
      normalizedQuery.contains('沽') ||
      normalizedQuery.contains('牛') ||
      normalizedQuery.contains('熊') ||
      normalizedQuery.contains('轮') ||
      normalizedQuery.contains('WARRANT') ||
      normalizedQuery.contains('CBBC');
}

bool sameStockSuggestions(
  List<StockSuggestion> current,
  List<StockSuggestion> next,
) {
  if (current.length != next.length) return false;
  for (var index = 0; index < current.length; index++) {
    if (current[index].code != next[index].code) return false;
  }
  return true;
}
