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
    required this.alertEnabled,
    required this.alertThresholdPercent,
    required this.alertBuyAmount,
    required this.alertSellRatio,
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
  final bool alertEnabled;
  final double alertThresholdPercent;
  final double alertBuyAmount;
  final double alertSellRatio;

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
      alertEnabled: json['alert_enabled'] as bool? ?? true,
      alertThresholdPercent: _double(
        json['alert_threshold_percent'],
        fallback: 5,
      ),
      alertBuyAmount: _double(json['alert_buy_amount'], fallback: 5000),
      alertSellRatio: _double(json['alert_sell_ratio'], fallback: 0.25),
    );
  }
}

class FundAlertSettingsDraft {
  const FundAlertSettingsDraft({
    required this.alertEnabled,
    required this.thresholdPercent,
  });

  final bool alertEnabled;
  final double thresholdPercent;

  Map<String, dynamic> toJson() {
    return {
      'alert_enabled': alertEnabled,
      'alert_threshold_percent': thresholdPercent,
    };
  }
}

class FundAlertSchedulerStatus {
  const FundAlertSchedulerStatus({
    required this.enabled,
    required this.running,
    required this.scanning,
    required this.pollIntervalSeconds,
    required this.reminderTimes,
    required this.dueWindowMinutes,
    required this.nextRunAt,
    required this.lastScanAt,
    required this.lastScanKey,
    required this.lastError,
    required this.lastResult,
  });

  final bool enabled;
  final bool running;
  final bool scanning;
  final int pollIntervalSeconds;
  final List<String> reminderTimes;
  final int dueWindowMinutes;
  final DateTime? nextRunAt;
  final DateTime? lastScanAt;
  final String lastScanKey;
  final String lastError;
  final Map<String, Object?> lastResult;

  factory FundAlertSchedulerStatus.defaults() {
    return const FundAlertSchedulerStatus(
      enabled: false,
      running: false,
      scanning: false,
      pollIntervalSeconds: 60,
      reminderTimes: ['14:30'],
      dueWindowMinutes: 10,
      nextRunAt: null,
      lastScanAt: null,
      lastScanKey: '',
      lastError: '',
      lastResult: {},
    );
  }

  factory FundAlertSchedulerStatus.fromJson(Map<String, dynamic> json) {
    return FundAlertSchedulerStatus(
      enabled: json['enabled'] as bool? ?? false,
      running: json['running'] as bool? ?? false,
      scanning: json['scanning'] as bool? ?? false,
      pollIntervalSeconds: _int(json['poll_interval_seconds'], fallback: 60),
      reminderTimes: _stringList(json['reminder_times']),
      dueWindowMinutes: _int(json['due_window_minutes'], fallback: 10),
      nextRunAt: DateTime.tryParse(json['next_run_at'] as String? ?? ''),
      lastScanAt: DateTime.tryParse(json['last_scan_at'] as String? ?? ''),
      lastScanKey: json['last_scan_key'] as String? ?? '',
      lastError: json['last_error'] as String? ?? '',
      lastResult: _map(json['last_result']),
    );
  }

  int get createdCount => _int(lastResult['created_count']);
  int get scannedCount => _int(lastResult['scanned_count']);
  int get skippedCount => _int(lastResult['skipped_count']);
}

class FundAlertSchedulerDraft {
  const FundAlertSchedulerDraft({
    required this.enabled,
    required this.reminderTimes,
    required this.dueWindowMinutes,
  });

  final bool enabled;
  final List<String> reminderTimes;
  final int dueWindowMinutes;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'reminder_times': reminderTimes,
      'due_window_minutes': dueWindowMinutes,
    };
  }
}

class FundPositionSummary {
  const FundPositionSummary({
    required this.position,
    required this.latestNav,
    required this.gridRecommendation,
    required this.valuationMode,
    required this.displayNav,
    required this.displayChangeRate,
    required this.displayTime,
    required this.dayProfit,
    required this.dayProfitRate,
    required this.marketValue,
    required this.holdingProfit,
    required this.holdingProfitRate,
    required this.totalProfit,
    required this.totalProfitRate,
  });

  final FundPosition position;
  final FundNavPoint? latestNav;
  final FundGridRecommendation? gridRecommendation;
  final String valuationMode;
  final double displayNav;
  final double displayChangeRate;
  final DateTime? displayTime;
  final double dayProfit;
  final double dayProfitRate;
  final double marketValue;
  final double holdingProfit;
  final double holdingProfitRate;
  final double totalProfit;
  final double totalProfitRate;

  bool get isEstimated => valuationMode == 'estimated';

  factory FundPositionSummary.fromJson(Map<String, dynamic> json) {
    final latest = json['latest_nav'];
    final recommendation = json['grid_recommendation'];
    return FundPositionSummary(
      position: FundPosition.fromJson(
        (json['position'] as Map<String, dynamic>?) ?? const {},
      ),
      latestNav: latest is Map<String, dynamic>
          ? FundNavPoint.fromJson(latest)
          : null,
      gridRecommendation: recommendation is Map<String, dynamic>
          ? FundGridRecommendation.fromJson(recommendation)
          : null,
      valuationMode: json['valuation_mode'] as String? ?? 'none',
      displayNav: _double(json['display_nav']),
      displayChangeRate: _double(json['display_change_rate']),
      displayTime: DateTime.tryParse(json['display_time'] as String? ?? ''),
      dayProfit: _double(json['day_profit']),
      dayProfitRate: _double(json['day_profit_rate']),
      marketValue: _double(json['market_value']),
      holdingProfit: _double(json['holding_profit']),
      holdingProfitRate: _double(json['holding_profit_rate']),
      totalProfit: _double(json['total_profit']),
      totalProfitRate: _double(json['total_profit_rate']),
    );
  }
}

class FundGridRecommendation {
  const FundGridRecommendation({
    required this.positionId,
    required this.fundCode,
    required this.name,
    required this.action,
    required this.actionLabel,
    required this.reason,
    required this.baselineNav,
    required this.currentNav,
    required this.changeRate,
    required this.thresholdPercent,
    required this.recommendedAmount,
    required this.recommendedShares,
    required this.valuationMode,
    required this.valuationTime,
  });

  final String positionId;
  final String fundCode;
  final String name;
  final String action;
  final String actionLabel;
  final String reason;
  final double baselineNav;
  final double currentNav;
  final double changeRate;
  final double thresholdPercent;
  final double recommendedAmount;
  final double recommendedShares;
  final String valuationMode;
  final DateTime? valuationTime;

  bool get isBuy => action == 'buy';

  factory FundGridRecommendation.fromJson(Map<String, dynamic> json) {
    return FundGridRecommendation(
      positionId: json['position_id'] as String? ?? '',
      fundCode: json['fund_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actionLabel: json['action_label'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      baselineNav: _double(json['baseline_nav']),
      currentNav: _double(json['current_nav']),
      changeRate: _double(json['change_rate']),
      thresholdPercent: _double(json['threshold_percent']),
      recommendedAmount: _double(json['recommended_amount']),
      recommendedShares: _double(json['recommended_shares']),
      valuationMode: json['valuation_mode'] as String? ?? 'none',
      valuationTime: DateTime.tryParse(json['valuation_time'] as String? ?? ''),
    );
  }
}

class FundTradeDraft {
  const FundTradeDraft({
    required this.action,
    required this.shares,
    required this.nav,
    this.amount = 0,
    this.fee = 0,
    this.autoNav = false,
    this.tradeDate,
    this.operationDate,
    this.operationAfterCutoff = false,
    this.note = '',
  });

  final String action;
  final double shares;
  final double nav;
  final double amount;
  final double fee;
  final bool autoNav;
  final DateTime? tradeDate;
  final DateTime? operationDate;
  final bool operationAfterCutoff;
  final String note;

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'shares': shares,
      'nav': nav,
      'amount': amount,
      'fee': fee,
      'auto_nav': autoNav,
      if (tradeDate != null) 'trade_date': _dateString(tradeDate!),
      if (operationDate != null) 'operation_date': _dateString(operationDate!),
      'operation_after_cutoff': operationAfterCutoff,
      'note': note,
    };
  }
}

String _dateString(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

class FundTrade {
  const FundTrade({
    required this.id,
    required this.positionId,
    required this.fundCode,
    required this.name,
    required this.action,
    required this.shares,
    required this.nav,
    required this.fee,
    required this.tradeDate,
    required this.operationDate,
    required this.operationAfterCutoff,
    required this.note,
  });

  final String id;
  final String positionId;
  final String fundCode;
  final String name;
  final String action;
  final double shares;
  final double nav;
  final double fee;
  final DateTime tradeDate;
  final DateTime? operationDate;
  final bool operationAfterCutoff;
  final String note;

  bool get isBuy => action == 'buy';

  factory FundTrade.fromJson(Map<String, dynamic> json) {
    return FundTrade(
      id: json['id'] as String? ?? '',
      positionId: json['fund_position_id'] as String? ?? '',
      fundCode: json['fund_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      action: json['action'] as String? ?? '',
      shares: _double(json['shares']),
      nav: _double(json['nav']),
      fee: _double(json['fee']),
      tradeDate:
          DateTime.tryParse(json['trade_date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      operationDate: DateTime.tryParse(json['operation_date'] as String? ?? ''),
      operationAfterCutoff: json['operation_after_cutoff'] as bool? ?? false,
      note: json['note'] as String? ?? '',
    );
  }
}

double _double(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const ['14:30'];
  final times = value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
  return times.isEmpty ? const ['14:30'] : times;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, dynamic>) return value.cast<String, Object?>();
  if (value is Map<String, Object?>) return value;
  return const {};
}
