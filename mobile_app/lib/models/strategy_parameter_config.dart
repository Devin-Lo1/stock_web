import '../utils/formatters.dart';
import 'strategy_definition.dart';

enum StrategyParameterValueType {
  positiveInt,
  boundedDouble,
  option,
  multiOption,
}

class StrategyParameterOption {
  const StrategyParameterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class StrategyParameterSpec {
  const StrategyParameterSpec({
    required this.key,
    required this.label,
    required this.fallback,
    required this.valueType,
    this.options = const [],
  });

  final String key;
  final String label;
  final String fallback;
  final StrategyParameterValueType valueType;
  final List<StrategyParameterOption> options;
}

const _maCrossSpecs = [
  StrategyParameterSpec(
    key: 'short_window',
    label: '短均线',
    fallback: '5',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'long_window',
    label: '长均线',
    fallback: '20',
    valueType: StrategyParameterValueType.positiveInt,
  ),
];

const _rsiReversalSpecs = [
  StrategyParameterSpec(
    key: 'rsi_window',
    label: 'RSI 周期',
    fallback: '14',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'oversold',
    label: '超卖线',
    fallback: '30',
    valueType: StrategyParameterValueType.boundedDouble,
  ),
  StrategyParameterSpec(
    key: 'overbought',
    label: '超买线',
    fallback: '70',
    valueType: StrategyParameterValueType.boundedDouble,
  ),
];

const _macdTrendSpecs = [
  StrategyParameterSpec(
    key: 'fast_window',
    label: '快线周期',
    fallback: '12',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'slow_window',
    label: '慢线周期',
    fallback: '26',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'signal_window',
    label: '信号周期',
    fallback: '9',
    valueType: StrategyParameterValueType.positiveInt,
  ),
];

const _priceBreakMaSpecs = [
  StrategyParameterSpec(
    key: 'ma_window',
    label: '均线周期',
    fallback: '10',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'direction',
    label: '触发方向',
    fallback: 'both',
    valueType: StrategyParameterValueType.option,
    options: [
      StrategyParameterOption(value: 'both', label: '双向'),
      StrategyParameterOption(value: 'break_down', label: '跌破'),
      StrategyParameterOption(value: 'recover_up', label: '站回'),
    ],
  ),
];

const _volumeBreakoutSpecs = [
  StrategyParameterSpec(
    key: 'lookback_window',
    label: '突破窗口',
    fallback: '20',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'volume_window',
    label: '均量窗口',
    fallback: '20',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'volume_multiplier',
    label: '放量倍数',
    fallback: '1.50',
    valueType: StrategyParameterValueType.boundedDouble,
  ),
  StrategyParameterSpec(
    key: 'direction',
    label: '触发方向',
    fallback: 'both',
    valueType: StrategyParameterValueType.option,
    options: [
      StrategyParameterOption(value: 'both', label: '双向'),
      StrategyParameterOption(value: 'break_up', label: '向上突破'),
      StrategyParameterOption(value: 'break_down', label: '向下跌破'),
    ],
  ),
];

const _maBreakdownStopSpecs = [
  StrategyParameterSpec(
    key: 'ma_window',
    label: '止损均线',
    fallback: '20',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'stop_buffer_pct',
    label: '缓冲%',
    fallback: '0',
    valueType: StrategyParameterValueType.boundedDouble,
  ),
  StrategyParameterSpec(
    key: 'direction',
    label: '触发方向',
    fallback: 'break_down',
    valueType: StrategyParameterValueType.option,
    options: [
      StrategyParameterOption(value: 'break_down', label: '止损'),
      StrategyParameterOption(value: 'recover_up', label: '站回'),
      StrategyParameterOption(value: 'both', label: '双向'),
    ],
  ),
];

const _atrTrailingStopSpecs = [
  StrategyParameterSpec(
    key: 'atr_window',
    label: 'ATR周期',
    fallback: '14',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'atr_multiplier',
    label: 'ATR倍数',
    fallback: '3',
    valueType: StrategyParameterValueType.boundedDouble,
  ),
  StrategyParameterSpec(
    key: 'entry_ma_window',
    label: '入场均线',
    fallback: '20',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'direction',
    label: '触发方向',
    fallback: 'stop_only',
    valueType: StrategyParameterValueType.option,
    options: [
      StrategyParameterOption(value: 'stop_only', label: '仅止损'),
      StrategyParameterOption(value: 'reentry_and_stop', label: '入场+止损'),
      StrategyParameterOption(value: 'both', label: '双向'),
    ],
  ),
];

const _rsiOversoldReboundSpecs = [
  StrategyParameterSpec(
    key: 'rsi_window',
    label: 'RSI 周期',
    fallback: '14',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'oversold',
    label: '超卖线',
    fallback: '30',
    valueType: StrategyParameterValueType.boundedDouble,
  ),
  StrategyParameterSpec(
    key: 'overbought',
    label: '止盈线',
    fallback: '70',
    valueType: StrategyParameterValueType.boundedDouble,
  ),
  StrategyParameterSpec(
    key: 'exit_mode',
    label: '退出方式',
    fallback: 'overbought',
    valueType: StrategyParameterValueType.option,
    options: [
      StrategyParameterOption(value: 'overbought', label: '高位回落'),
      StrategyParameterOption(value: 'none', label: '不退出'),
    ],
  ),
];

const _trendScoreSpecs = [
  StrategyParameterSpec(
    key: 'ma_window',
    label: '均线窗口',
    fallback: '20',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'momentum_window',
    label: '动量窗口',
    fallback: '20',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'volume_window',
    label: '均量窗口',
    fallback: '20',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'buy_score',
    label: '转强分',
    fallback: '3',
    valueType: StrategyParameterValueType.positiveInt,
  ),
  StrategyParameterSpec(
    key: 'sell_score',
    label: '转弱分',
    fallback: '1',
    valueType: StrategyParameterValueType.positiveInt,
  ),
];

const _compositeFactorSpecs = [
  StrategyParameterSpec(
    key: 'factor_codes',
    label: '组合因子',
    fallback: 'volume_breakout,trend_score',
    valueType: StrategyParameterValueType.multiOption,
    options: [
      StrategyParameterOption(value: 'ma_cross', label: '均线交叉'),
      StrategyParameterOption(value: 'rsi_reversal', label: 'RSI反转'),
      StrategyParameterOption(value: 'macd_trend', label: 'MACD趋势'),
      StrategyParameterOption(value: 'price_break_ma', label: '突破均线'),
      StrategyParameterOption(value: 'volume_breakout', label: '放量突破'),
      StrategyParameterOption(value: 'ma_breakdown_stop', label: '均线止损'),
      StrategyParameterOption(value: 'atr_trailing_stop', label: 'ATR止损'),
      StrategyParameterOption(value: 'rsi_oversold_rebound', label: 'RSI反弹'),
      StrategyParameterOption(value: 'trend_score', label: '趋势评分'),
    ],
  ),
  StrategyParameterSpec(
    key: 'mode',
    label: '确认模式',
    fallback: 'all',
    valueType: StrategyParameterValueType.option,
    options: [
      StrategyParameterOption(value: 'all', label: '全部确认'),
      StrategyParameterOption(value: 'any', label: '任一触发'),
    ],
  ),
  StrategyParameterSpec(
    key: 'confirm_window',
    label: '确认窗口',
    fallback: '3',
    valueType: StrategyParameterValueType.positiveInt,
  ),
];

const compositeFactorCodes = [
  'ma_cross',
  'rsi_reversal',
  'macd_trend',
  'price_break_ma',
  'volume_breakout',
  'ma_breakdown_stop',
  'atr_trailing_stop',
  'rsi_oversold_rebound',
  'trend_score',
];

List<StrategyParameterSpec> strategyParameterSpecsFor(String strategyCode) {
  return switch (strategyCode) {
    'atr_trailing_stop' => _atrTrailingStopSpecs,
    'composite_factor' => _compositeFactorSpecs,
    'ma_breakdown_stop' => _maBreakdownStopSpecs,
    'macd_trend' => _macdTrendSpecs,
    'price_break_ma' => _priceBreakMaSpecs,
    'rsi_oversold_rebound' => _rsiOversoldReboundSpecs,
    'rsi_reversal' => _rsiReversalSpecs,
    'trend_score' => _trendScoreSpecs,
    'volume_breakout' => _volumeBreakoutSpecs,
    _ => _maCrossSpecs,
  };
}

Set<String> allStrategyParameterKeys() {
  return {
    for (final spec in _maCrossSpecs) spec.key,
    for (final spec in _rsiReversalSpecs) spec.key,
    for (final spec in _macdTrendSpecs) spec.key,
    for (final spec in _priceBreakMaSpecs) spec.key,
    for (final spec in _volumeBreakoutSpecs) spec.key,
    for (final spec in _maBreakdownStopSpecs) spec.key,
    for (final spec in _atrTrailingStopSpecs) spec.key,
    for (final spec in _rsiOversoldReboundSpecs) spec.key,
    for (final spec in _trendScoreSpecs) spec.key,
    for (final spec in _compositeFactorSpecs) spec.key,
    for (final factorCode in compositeFactorCodes)
      for (final spec in strategyParameterSpecsFor(factorCode))
        compositeFactorParameterKey(factorCode, spec.key),
  };
}

String strategyParameterDefaultText(
  StrategyDefinition strategy,
  StrategyParameterSpec spec,
) {
  final value = strategy.defaultParameters[spec.key];
  if (value is num) return formatNumberInput(value.toDouble());
  if (value is String && value.isNotEmpty) return value;
  if (value is List) return value.map((item) => '$item').join(',');
  return spec.fallback;
}

String compositeFactorParameterKey(String factorCode, String parameterKey) {
  return 'factor_parameters.$factorCode.$parameterKey';
}

List<String> compositeFactorCodesFromText(String text) {
  final allowed = compositeFactorCodes.toSet();
  final selected = text
      .split(RegExp(r'[,\uFF0C;\uFF1B\s]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && allowed.contains(item))
      .toList();
  return [
    for (final code in compositeFactorCodes)
      if (selected.contains(code)) code,
  ];
}

String compositeFactorParameterDefaultText(
  StrategyDefinition strategy,
  String factorCode,
  StrategyParameterSpec spec,
) {
  final factorParameters = strategy.defaultParameters['factor_parameters'];
  if (factorParameters is Map) {
    final rawParameters = factorParameters[factorCode];
    if (rawParameters is Map) {
      final value = rawParameters[spec.key];
      if (value is num) return formatNumberInput(value.toDouble());
      if (value is String && value.isNotEmpty) return value;
      if (value is List) return value.map((item) => '$item').join(',');
    }
  }
  return spec.fallback;
}
