import '../models/app_enums.dart';

String formatHkd(double value, {bool showSign = true, int decimals = 0}) {
  final sign = showSign
      ? value > 0
            ? '+'
            : value < 0
            ? '-'
            : ''
      : '';
  return '${sign}HK\$ ${value.abs().toStringAsFixed(decimals)}';
}

String formatMarketMoney(
  MarketFilter market,
  double value, {
  bool showSign = true,
  int decimals = 0,
}) {
  final sign = showSign
      ? value > 0
            ? '+'
            : value < 0
            ? '-'
            : ''
      : '';
  return '$sign${market.currencyPrefix} ${value.abs().toStringAsFixed(decimals)}';
}

String formatCompactHkd(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  final amount = value.abs();
  if (amount >= 10000) {
    return '$sign${(amount / 10000).toStringAsFixed(1)}万';
  }
  return '$sign${amount.toStringAsFixed(0)}';
}

String currencySymbol(String stockCode) {
  final code = stockCode.toUpperCase();
  if (code.startsWith('SH.') ||
      code.startsWith('SZ.') ||
      code.startsWith('CN.')) {
    return '¥';
  }
  return r'$';
}

String formatPercent(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  return '$sign${value.abs().toStringAsFixed(2)}%';
}

String formatNumberInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
