String formatQuotePrice(double value, double fallback) {
  final effectiveValue = value == 0 ? fallback : value;
  if (effectiveValue == 0) return '--';
  return effectiveValue.toStringAsFixed(2);
}

String formatMarketVolume(double value) {
  if (value <= 0) return '--';
  if (value >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(1)}万';
  }
  return value.toStringAsFixed(0);
}

String formatMarketAmount(double value) {
  if (value <= 0) return '--';
  if (value >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return value.toStringAsFixed(0);
}

String formatOptionalRatio(double value) {
  if (value <= 0) return '--';
  return value.toStringAsFixed(2);
}

String formatOptionalPercent(double value) {
  if (value <= 0) return '--';
  return '${value.toStringAsFixed(2)}%';
}

String formatLotSize(double value) {
  if (value <= 0) return '--';
  return '${value.toStringAsFixed(0)}股';
}

String formatCandleDate(DateTime? value) {
  if (value == null) return '--';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}

String formatAxisDate(DateTime? value) {
  if (value == null) return '--';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}

String formatLargeNumber(double value) {
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (absValue >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return value.toStringAsFixed(0);
}
