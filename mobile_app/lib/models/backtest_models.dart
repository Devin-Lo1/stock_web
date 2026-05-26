class BacktestRequest {
  const BacktestRequest({
    required this.strategyCode,
    required this.stockCode,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.initialCash,
    required this.feeRate,
    required this.slippageRate,
    required this.parameters,
  });

  final String strategyCode;
  final String stockCode;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final double initialCash;
  final double feeRate;
  final double slippageRate;
  final Map<String, Object?> parameters;

  Map<String, dynamic> toJson() {
    return {
      'strategy_code': strategyCode,
      'stock_code': stockCode,
      'period': period,
      'start_date': _dateText(startDate),
      'end_date': _dateText(endDate),
      'initial_cash': initialCash,
      'fee_rate': feeRate,
      'slippage_rate': slippageRate,
      'parameters': parameters,
    };
  }

  factory BacktestRequest.fromJson(Map<String, dynamic> json) {
    return BacktestRequest(
      strategyCode: json['strategy_code'] as String? ?? '',
      stockCode: json['stock_code'] as String? ?? '',
      period: json['period'] as String? ?? 'day',
      startDate: _readDate(json['start_date']) ?? DateTime(2000),
      endDate: _readDate(json['end_date']) ?? DateTime(2000),
      initialCash: _readDouble(json['initial_cash']),
      feeRate: _readDouble(json['fee_rate']),
      slippageRate: _readDouble(json['slippage_rate']),
      parameters: _readMap(json['parameters']),
    );
  }
}

class BacktestBatchRequest {
  const BacktestBatchRequest({
    required this.items,
    this.continueOnError = true,
  });

  final List<BacktestRequest> items;
  final bool continueOnError;

  Map<String, dynamic> toJson() {
    return {
      'items': [for (final item in items) item.toJson()],
      'continue_on_error': continueOnError,
    };
  }
}

class BacktestRun {
  const BacktestRun({
    required this.id,
    required this.name,
    required this.strategyCode,
    required this.stockCode,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.initialCash,
    required this.feeRate,
    required this.slippageRate,
    required this.parameters,
    required this.status,
    required this.summary,
  });

  final String id;
  final String name;
  final String strategyCode;
  final String stockCode;
  final String period;
  final DateTime? startDate;
  final DateTime? endDate;
  final double initialCash;
  final double feeRate;
  final double slippageRate;
  final Map<String, Object?> parameters;
  final String status;
  final Map<String, Object?> summary;

  factory BacktestRun.fromJson(Map<String, dynamic> json) {
    return BacktestRun(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      strategyCode: json['strategy_code'] as String? ?? '',
      stockCode: json['stock_code'] as String? ?? '',
      period: json['period'] as String? ?? '',
      startDate: _readDate(json['start_date']),
      endDate: _readDate(json['end_date']),
      initialCash: _readDouble(json['initial_cash']),
      feeRate: _readDouble(json['fee_rate']),
      slippageRate: _readDouble(json['slippage_rate']),
      parameters: _readMap(json['parameters']),
      status: json['status'] as String? ?? '',
      summary: _readMap(json['summary']),
    );
  }

  double summaryDouble(String key) => _readDouble(summary[key]);
}

class BacktestEquityPoint {
  const BacktestEquityPoint({
    required this.time,
    required this.equity,
    required this.cash,
    required this.positionQuantity,
    required this.marketValue,
    required this.drawdown,
  });

  final DateTime? time;
  final double equity;
  final double cash;
  final double positionQuantity;
  final double marketValue;
  final double drawdown;

  factory BacktestEquityPoint.fromJson(Map<String, dynamic> json) {
    return BacktestEquityPoint(
      time: _readDate(json['time']),
      equity: _readDouble(json['equity']),
      cash: _readDouble(json['cash']),
      positionQuantity: _readDouble(json['position_quantity']),
      marketValue: _readDouble(json['market_value']),
      drawdown: _readDouble(json['drawdown']),
    );
  }
}

class BacktestTrade {
  const BacktestTrade({
    required this.time,
    required this.side,
    required this.price,
    required this.quantity,
    required this.fee,
    required this.slippage,
    required this.cashAfter,
    required this.positionAfter,
  });

  final DateTime? time;
  final String side;
  final double price;
  final double quantity;
  final double fee;
  final double slippage;
  final double cashAfter;
  final double positionAfter;

  factory BacktestTrade.fromJson(Map<String, dynamic> json) {
    return BacktestTrade(
      time: _readDate(json['time']),
      side: json['side'] as String? ?? '',
      price: _readDouble(json['price']),
      quantity: _readDouble(json['quantity']),
      fee: _readDouble(json['fee']),
      slippage: _readDouble(json['slippage']),
      cashAfter: _readDouble(json['cash_after']),
      positionAfter: _readDouble(json['position_after']),
    );
  }
}

class BacktestResult {
  const BacktestResult({
    required this.run,
    required this.equityCurve,
    required this.trades,
  });

  final BacktestRun run;
  final List<BacktestEquityPoint> equityCurve;
  final List<BacktestTrade> trades;

  factory BacktestResult.fromJson(Map<String, dynamic> json) {
    return BacktestResult(
      run: BacktestRun.fromJson(json['run'] as Map<String, dynamic>? ?? {}),
      equityCurve: (json['equity_curve'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BacktestEquityPoint.fromJson)
          .toList(),
      trades: (json['trades'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BacktestTrade.fromJson)
          .toList(),
    );
  }
}

class BacktestBatchItemResult {
  const BacktestBatchItemResult({
    required this.index,
    required this.request,
    required this.run,
    required this.error,
  });

  final int index;
  final BacktestRequest? request;
  final BacktestRun? run;
  final String? error;

  bool get isCompleted => run?.status == 'completed';
  bool get isFailed => error != null || run?.status == 'failed';

  factory BacktestBatchItemResult.fromJson(Map<String, dynamic> json) {
    final requestJson = json['request'];
    final runJson = json['run'];
    return BacktestBatchItemResult(
      index: (json['index'] as num?)?.toInt() ?? 0,
      request: requestJson is Map<String, dynamic>
          ? BacktestRequest.fromJson(requestJson)
          : null,
      run: runJson is Map<String, dynamic>
          ? BacktestRun.fromJson(runJson)
          : null,
      error: json['error'] as String?,
    );
  }
}

class BacktestBatchResult {
  const BacktestBatchResult({
    required this.totalCount,
    required this.completedCount,
    required this.failedCount,
    required this.results,
  });

  final int totalCount;
  final int completedCount;
  final int failedCount;
  final List<BacktestBatchItemResult> results;

  factory BacktestBatchResult.fromJson(Map<String, dynamic> json) {
    return BacktestBatchResult(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      results: (json['results'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BacktestBatchItemResult.fromJson)
          .toList(),
    );
  }
}

String _dateText(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime? _readDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

Map<String, Object?> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value.cast<String, Object?>();
  return const {};
}
