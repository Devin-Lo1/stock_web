import 'dart:math' as math;

import '../../models/backtest_models.dart';
import '../../models/candle.dart';

class BacktestViewWindow {
  const BacktestViewWindow({
    required this.start,
    required this.end,
    required this.count,
  });

  factory BacktestViewWindow.fromState({
    required int totalCount,
    required int visibleCount,
    required int visibleEndIndex,
  }) {
    if (totalCount <= 0) {
      return const BacktestViewWindow(start: 0, end: 0, count: 0);
    }
    final count = visibleCount.clamp(1, totalCount);
    final end = (visibleEndIndex <= 0 ? totalCount : visibleEndIndex).clamp(
      count,
      totalCount,
    );
    return BacktestViewWindow(start: end - count, end: end, count: count);
  }

  final int start;
  final int end;
  final int count;
}

class BacktestPriceRange {
  const BacktestPriceRange({required this.min, required this.max});

  factory BacktestPriceRange.fromCandles({
    required List<Candle> candles,
    required List<double> maValues,
    required List<BacktestTrade> trades,
  }) {
    var minValue = candles.map((candle) => candle.low).reduce(math.min);
    var maxValue = candles.map((candle) => candle.high).reduce(math.max);
    for (final value in maValues) {
      minValue = math.min(minValue, value);
      maxValue = math.max(maxValue, value);
    }
    for (final trade in trades) {
      minValue = math.min(minValue, trade.price);
      maxValue = math.max(maxValue, trade.price);
    }
    final padding = math.max((maxValue - minValue) * 0.08, 0.01);
    return BacktestPriceRange(min: minValue - padding, max: maxValue + padding);
  }

  final double min;
  final double max;

  double get size {
    final value = max - min;
    return value.abs() < 0.0001 ? 1 : value;
  }
}

List<double?> calculateMovingAverage(List<Candle> values, int window) {
  final result = List<double?>.filled(values.length, null);
  var sum = 0.0;
  for (var index = 0; index < values.length; index++) {
    sum += values[index].close;
    if (index >= window) sum -= values[index - window].close;
    if (index >= window - 1) result[index] = sum / window;
  }
  return result;
}

List<BacktestTrade> visibleBacktestTrades(
  List<Candle> candles,
  List<BacktestTrade> trades,
) {
  if (candles.isEmpty) return const [];
  final firstTime = candles.first.time;
  final lastTime = candles.last.time;
  if (firstTime == null || lastTime == null) return const [];
  final firstKey = backtestDateKey(firstTime);
  final lastKey = backtestDateKey(lastTime);
  return trades.where((trade) {
    final tradeTime = trade.time;
    if (tradeTime == null) return false;
    final key = backtestDateKey(tradeTime);
    return key >= firstKey && key <= lastKey;
  }).toList();
}

int backtestDateKey(DateTime value) {
  return value.year * 10000 + value.month * 100 + value.day;
}

String formatBacktestAxisDate(DateTime? value) {
  if (value == null) return '--';
  return '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

String formatBacktestFullDate(DateTime? value) {
  if (value == null) return '--';
  return '${value.year.toString().padLeft(4, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

String formatBacktestCompactNumber(double value) {
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (absValue >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  if (absValue >= 100) {
    return value.toStringAsFixed(0);
  }
  if (absValue >= 1) {
    return value.toStringAsFixed(2);
  }
  return value.toStringAsFixed(0);
}
