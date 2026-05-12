class StockSearchResult {
  const StockSearchResult({
    required this.code,
    required this.name,
    required this.market,
    required this.stockType,
    required this.lotSize,
  });

  final String code;
  final String name;
  final String market;
  final String stockType;
  final double lotSize;

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      market: json['market'] as String? ?? '',
      stockType: json['stock_type'] as String? ?? '',
      lotSize: (json['lot_size'] as num?)?.toDouble() ?? 0,
    );
  }
}
