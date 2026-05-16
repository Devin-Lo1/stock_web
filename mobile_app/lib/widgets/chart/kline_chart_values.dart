import 'package:flutter/material.dart';

import '../../models/candle.dart';

Map<int, double?> klineMaValuesAt(List<Candle> candles, int index) {
  if (candles.isEmpty) {
    return {5: null, 10: null, 20: null, 60: null};
  }
  final effectiveIndex = index.clamp(0, candles.length - 1).toInt();
  return {
    5: klineMovingAverageAt(candles, effectiveIndex, 5),
    10: klineMovingAverageAt(candles, effectiveIndex, 10),
    20: klineMovingAverageAt(candles, effectiveIndex, 20),
    60: klineMovingAverageAt(candles, effectiveIndex, 60),
  };
}

Map<int, double?> volumeMaValuesAt(List<Candle> candles, int index) {
  if (candles.isEmpty) {
    return {5: null, 10: null, 20: null};
  }
  final effectiveIndex = index.clamp(0, candles.length - 1).toInt();
  return {
    5: volumeMovingAverageAt(candles, effectiveIndex, 5),
    10: volumeMovingAverageAt(candles, effectiveIndex, 10),
    20: volumeMovingAverageAt(candles, effectiveIndex, 20),
  };
}

double? klineMovingAverageAt(List<Candle> candles, int index, int period) {
  if (index < period - 1 || index >= candles.length) return null;
  var sum = 0.0;
  for (var i = index - period + 1; i <= index; i++) {
    sum += candles[i].close;
  }
  return sum / period;
}

double? volumeMovingAverageAt(List<Candle> candles, int index, int period) {
  if (index < period - 1 || index >= candles.length) return null;
  var sum = 0.0;
  for (var i = index - period + 1; i <= index; i++) {
    sum += candles[i].volume;
  }
  return sum / period;
}

String formatKlineMa(double? value) {
  if (value == null) return '--';
  return value.toStringAsFixed(2);
}

String formatVolumeMa(double? value) {
  if (value == null) return '--';
  return formatKlineLargeNumber(value);
}

String formatKlinePrice(double value) {
  return value.toStringAsFixed(2);
}

String formatKlineDate(DateTime? value) {
  if (value == null) return '--';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}

String formatKlineAxisDate(DateTime? value) {
  if (value == null) return '--';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}

String formatKlineLargeNumber(double value) {
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (absValue >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return value.toStringAsFixed(0);
}

Color klineProfitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF3B45);
}

Color? klineQuoteColor(
  double value,
  double previousClose,
  BuildContext context,
) {
  if (value == 0 || previousClose == 0 || value == previousClose) return null;
  return klineProfitColor(value - previousClose);
}
