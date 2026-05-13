class StockSuggestion {
  const StockSuggestion({
    required this.code,
    required this.name,
    this.market = '',
    this.stockType = '',
    this.lotSize = 0,
  });

  final String code;
  final String name;
  final String market;
  final String stockType;
  final double lotSize;

  String get subtitle {
    final details = <String>[code];
    if (stockType.isNotEmpty) details.add(stockType);
    if (lotSize > 0) details.add('${lotSize.toStringAsFixed(0)}股/手');
    return details.join(' · ');
  }
}
