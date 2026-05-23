class FundSearchResult {
  const FundSearchResult({
    required this.code,
    required this.name,
    required this.fundType,
    required this.company,
    required this.manager,
    required this.source,
  });

  final String code;
  final String name;
  final String fundType;
  final String company;
  final String manager;
  final String source;

  factory FundSearchResult.fromJson(Map<String, dynamic> json) {
    return FundSearchResult(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      fundType: json['fund_type'] as String? ?? '',
      company: json['company'] as String? ?? '',
      manager: json['manager'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}

class FundNavPoint {
  const FundNavPoint({
    required this.fundCode,
    required this.navDate,
    required this.unitNav,
    required this.accumulatedNav,
    required this.dailyGrowthRate,
  });

  final String fundCode;
  final DateTime navDate;
  final double unitNav;
  final double accumulatedNav;
  final double dailyGrowthRate;

  factory FundNavPoint.fromJson(Map<String, dynamic> json) {
    return FundNavPoint(
      fundCode: json['fund_code'] as String? ?? '',
      navDate:
          DateTime.tryParse(json['nav_date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      unitNav: _double(json['unit_nav']),
      accumulatedNav: _double(json['accumulated_nav']),
      dailyGrowthRate: _double(json['daily_growth_rate']),
    );
  }
}

class FundPosition {
  const FundPosition({
    required this.id,
    required this.fundCode,
    required this.name,
    required this.fundType,
    required this.shares,
    required this.avgCostNav,
    required this.investedAmount,
    required this.realizedProfit,
    required this.currency,
  });

  final String id;
  final String fundCode;
  final String name;
  final String fundType;
  final double shares;
  final double avgCostNav;
  final double investedAmount;
  final double realizedProfit;
  final String currency;

  factory FundPosition.fromJson(Map<String, dynamic> json) {
    return FundPosition(
      id: json['id'] as String? ?? '',
      fundCode: json['fund_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      fundType: json['fund_type'] as String? ?? '',
      shares: _double(json['shares']),
      avgCostNav: _double(json['avg_cost_nav']),
      investedAmount: _double(json['invested_amount']),
      realizedProfit: _double(json['realized_profit']),
      currency: json['currency'] as String? ?? 'CNY',
    );
  }
}

class FundPositionSummary {
  const FundPositionSummary({
    required this.position,
    required this.latestNav,
    required this.marketValue,
    required this.holdingProfit,
    required this.holdingProfitRate,
    required this.totalProfit,
    required this.totalProfitRate,
  });

  final FundPosition position;
  final FundNavPoint? latestNav;
  final double marketValue;
  final double holdingProfit;
  final double holdingProfitRate;
  final double totalProfit;
  final double totalProfitRate;

  factory FundPositionSummary.fromJson(Map<String, dynamic> json) {
    final latest = json['latest_nav'];
    return FundPositionSummary(
      position: FundPosition.fromJson(
        (json['position'] as Map<String, dynamic>?) ?? const {},
      ),
      latestNav: latest is Map<String, dynamic>
          ? FundNavPoint.fromJson(latest)
          : null,
      marketValue: _double(json['market_value']),
      holdingProfit: _double(json['holding_profit']),
      holdingProfitRate: _double(json['holding_profit_rate']),
      totalProfit: _double(json['total_profit']),
      totalProfitRate: _double(json['total_profit_rate']),
    );
  }
}

class FundTradeDraft {
  const FundTradeDraft({
    required this.action,
    required this.shares,
    required this.nav,
    this.fee = 0,
    this.note = '',
  });

  final String action;
  final double shares;
  final double nav;
  final double fee;
  final String note;

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'shares': shares,
      'nav': nav,
      'fee': fee,
      'note': note,
    };
  }
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
