import '../utils/formatters.dart';
import 'strategy_definition.dart';

enum StrategyParameterValueType { positiveInt, boundedDouble }

class StrategyParameterSpec {
  const StrategyParameterSpec({
    required this.key,
    required this.label,
    required this.fallback,
    required this.valueType,
  });

  final String key;
  final String label;
  final String fallback;
  final StrategyParameterValueType valueType;
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

List<StrategyParameterSpec> strategyParameterSpecsFor(String strategyCode) {
  return switch (strategyCode) {
    'macd_trend' => _macdTrendSpecs,
    'rsi_reversal' => _rsiReversalSpecs,
    _ => _maCrossSpecs,
  };
}

Set<String> allStrategyParameterKeys() {
  return {
    for (final spec in _maCrossSpecs) spec.key,
    for (final spec in _rsiReversalSpecs) spec.key,
    for (final spec in _macdTrendSpecs) spec.key,
  };
}

String strategyParameterDefaultText(
  StrategyDefinition strategy,
  StrategyParameterSpec spec,
) {
  final value = strategy.defaultParameters[spec.key];
  if (value is num) return formatNumberInput(value.toDouble());
  if (value is String && value.isNotEmpty) return value;
  return spec.fallback;
}
