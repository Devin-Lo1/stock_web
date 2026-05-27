import 'candle.dart';

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

class VolumeProfileBacktestRequest {
  const VolumeProfileBacktestRequest({
    required this.stockCode,
    required this.startDate,
    required this.endDate,
    required this.deviationThreshold,
    required this.bucketCount,
    this.valueAreaRatio = 0.68,
    this.stopLossMultiple = 1.0,
  });

  final String stockCode;
  final DateTime startDate;
  final DateTime endDate;
  final double deviationThreshold;
  final int bucketCount;
  final double valueAreaRatio;
  final double stopLossMultiple;

  Map<String, dynamic> toJson() {
    return {
      'stock_code': stockCode,
      'start_date': _dateText(startDate),
      'end_date': _dateText(endDate),
      'deviation_threshold': deviationThreshold,
      'bucket_count': bucketCount,
      'value_area_ratio': valueAreaRatio,
      'stop_loss_multiple': stopLossMultiple,
    };
  }
}

class VolumeProfileBucket {
  const VolumeProfileBucket({
    required this.priceLow,
    required this.priceHigh,
    required this.priceMid,
    required this.volume,
    required this.volumeRatio,
  });

  final double priceLow;
  final double priceHigh;
  final double priceMid;
  final double volume;
  final double volumeRatio;

  factory VolumeProfileBucket.fromJson(Map<String, dynamic> json) {
    return VolumeProfileBucket(
      priceLow: _readDouble(json['price_low']),
      priceHigh: _readDouble(json['price_high']),
      priceMid: _readDouble(json['price_mid']),
      volume: _readDouble(json['volume']),
      volumeRatio: _readDouble(json['volume_ratio']),
    );
  }
}

class VolumeProfileDayProfile {
  const VolumeProfileDayProfile({
    required this.date,
    required this.poc,
    required this.vah,
    required this.val,
    required this.totalVolume,
    required this.bucketCount,
    required this.valueAreaRatio,
    required this.buckets,
  });

  final DateTime? date;
  final double poc;
  final double vah;
  final double val;
  final double totalVolume;
  final int bucketCount;
  final double valueAreaRatio;
  final List<VolumeProfileBucket> buckets;

  factory VolumeProfileDayProfile.fromJson(Map<String, dynamic> json) {
    return VolumeProfileDayProfile(
      date: _readDate(json['date']),
      poc: _readDouble(json['poc']),
      vah: _readDouble(json['vah']),
      val: _readDouble(json['val']),
      totalVolume: _readDouble(json['total_volume']),
      bucketCount: (json['bucket_count'] as num?)?.toInt() ?? 0,
      valueAreaRatio: _readDouble(json['value_area_ratio']),
      buckets: (json['buckets'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VolumeProfileBucket.fromJson)
          .toList(),
    );
  }
}

class VolumeProfileSignal {
  const VolumeProfileSignal({
    required this.date,
    required this.profileDate,
    required this.direction,
    required this.openPrice,
    required this.targetPrice,
    required this.stopPrice,
    required this.deviation,
    required this.outcome,
    required this.outcomeTime,
    required this.outcomePrice,
    required this.poc,
    required this.vah,
    required this.val,
  });

  final DateTime? date;
  final DateTime? profileDate;
  final String? direction;
  final double? openPrice;
  final double? targetPrice;
  final double? stopPrice;
  final double? deviation;
  final String outcome;
  final DateTime? outcomeTime;
  final double? outcomePrice;
  final double? poc;
  final double? vah;
  final double? val;

  bool get isTriggered => direction != null && outcome != 'skipped';
  bool get isSuccess => outcome == 'success';
  bool get isFailure => outcome == 'failed';

  factory VolumeProfileSignal.fromJson(Map<String, dynamic> json) {
    return VolumeProfileSignal(
      date: _readDate(json['date']),
      profileDate: _readDate(json['profile_date']),
      direction: json['direction'] as String?,
      openPrice: _readNullableDouble(json['open_price']),
      targetPrice: _readNullableDouble(json['target_price']),
      stopPrice: _readNullableDouble(json['stop_price']),
      deviation: _readNullableDouble(json['deviation']),
      outcome: json['outcome'] as String? ?? '',
      outcomeTime: _readDate(json['outcome_time']),
      outcomePrice: _readNullableDouble(json['outcome_price']),
      poc: _readNullableDouble(json['poc']),
      vah: _readNullableDouble(json['vah']),
      val: _readNullableDouble(json['val']),
    );
  }
}

class VolumeProfileBacktestResult {
  const VolumeProfileBacktestResult({
    required this.request,
    required this.summary,
    required this.signals,
    required this.chartProfile,
    required this.chartSignal,
    required this.chartCandles,
  });

  final VolumeProfileBacktestRequest? request;
  final Map<String, Object?> summary;
  final List<VolumeProfileSignal> signals;
  final VolumeProfileDayProfile? chartProfile;
  final VolumeProfileSignal? chartSignal;
  final List<Candle> chartCandles;

  double summaryDouble(String key) => _readDouble(summary[key]);
  int summaryInt(String key) => _readDouble(summary[key]).round();

  factory VolumeProfileBacktestResult.fromJson(Map<String, dynamic> json) {
    final requestJson = json['request'];
    final profileJson = json['chart_profile'];
    final signalJson = json['chart_signal'];
    return VolumeProfileBacktestResult(
      request: requestJson is Map<String, dynamic>
          ? VolumeProfileBacktestRequest(
              stockCode: requestJson['stock_code'] as String? ?? '',
              startDate: _readDate(requestJson['start_date']) ?? DateTime(2000),
              endDate: _readDate(requestJson['end_date']) ?? DateTime(2000),
              deviationThreshold: _readDouble(
                requestJson['deviation_threshold'],
              ),
              bucketCount: (requestJson['bucket_count'] as num?)?.toInt() ?? 0,
              valueAreaRatio: _readDouble(requestJson['value_area_ratio']),
              stopLossMultiple: _readDouble(requestJson['stop_loss_multiple']),
            )
          : null,
      summary: _readMap(json['summary']),
      signals: (json['signals'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VolumeProfileSignal.fromJson)
          .toList(),
      chartProfile: profileJson is Map<String, dynamic>
          ? VolumeProfileDayProfile.fromJson(profileJson)
          : null,
      chartSignal: signalJson is Map<String, dynamic>
          ? VolumeProfileSignal.fromJson(signalJson)
          : null,
      chartCandles: (json['chart_candles'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Candle.fromJson)
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

double? _readNullableDouble(Object? value) {
  if (value == null) return null;
  return _readDouble(value);
}

Map<String, Object?> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value.cast<String, Object?>();
  return const {};
}
