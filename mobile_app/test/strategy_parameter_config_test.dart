import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/models/strategy_definition.dart';
import 'package:stock_mobile/models/strategy_parameter_config.dart';

void main() {
  test('strategyParameterSpecsFor returns MA parameters by default', () {
    final specs = strategyParameterSpecsFor('ma_cross');

    expect(specs.map((spec) => spec.key), ['short_window', 'long_window']);
  });

  test('strategyParameterSpecsFor returns RSI parameters', () {
    final specs = strategyParameterSpecsFor('rsi_reversal');

    expect(specs.map((spec) => spec.key), [
      'rsi_window',
      'oversold',
      'overbought',
    ]);
  });

  test('strategyParameterSpecsFor returns MACD parameters', () {
    final specs = strategyParameterSpecsFor('macd_trend');

    expect(specs.map((spec) => spec.key), [
      'fast_window',
      'slow_window',
      'signal_window',
    ]);
  });

  test('strategyParameterSpecsFor returns price break MA parameters', () {
    final specs = strategyParameterSpecsFor('price_break_ma');

    expect(specs.map((spec) => spec.key), ['ma_window', 'direction']);
    expect(specs[1].valueType, StrategyParameterValueType.option);
    expect(specs[1].options.map((option) => option.value), [
      'both',
      'break_down',
      'recover_up',
    ]);
  });

  test('strategyParameterSpecsFor returns new factor parameters', () {
    expect(
      strategyParameterSpecsFor('volume_breakout').map((spec) => spec.key),
      ['lookback_window', 'volume_window', 'volume_multiplier', 'direction'],
    );
    expect(
      strategyParameterSpecsFor('ma_breakdown_stop').map((spec) => spec.key),
      ['ma_window', 'stop_buffer_pct', 'direction'],
    );
    expect(
      strategyParameterSpecsFor('atr_trailing_stop').map((spec) => spec.key),
      ['atr_window', 'atr_multiplier', 'entry_ma_window', 'direction'],
    );
    expect(
      strategyParameterSpecsFor('rsi_oversold_rebound').map((spec) => spec.key),
      ['rsi_window', 'oversold', 'overbought', 'exit_mode'],
    );
    expect(strategyParameterSpecsFor('trend_score').map((spec) => spec.key), [
      'ma_window',
      'momentum_window',
      'volume_window',
      'buy_score',
      'sell_score',
    ]);
  });

  test('strategyParameterSpecsFor returns composite factor parameters', () {
    final specs = strategyParameterSpecsFor('composite_factor');

    expect(specs.map((spec) => spec.key), [
      'factor_codes',
      'mode',
      'confirm_window',
    ]);
    expect(specs[0].valueType, StrategyParameterValueType.multiOption);
    expect(
      specs[0].options.map((option) => option.value),
      contains('trend_score'),
    );
  });

  test('strategyParameterDefaultText reads backend defaults', () {
    const strategy = StrategyDefinition(
      id: 'strategy-1',
      code: 'rsi_reversal',
      name: 'RSI Reversal',
      description: '',
      defaultParameters: {'rsi_window': 14, 'oversold': 25.5},
    );
    final specs = strategyParameterSpecsFor(strategy.code);

    expect(strategyParameterDefaultText(strategy, specs[0]), '14');
    expect(strategyParameterDefaultText(strategy, specs[1]), '25.50');
    expect(strategyParameterDefaultText(strategy, specs[2]), '70');
  });

  test('strategyParameterDefaultText reads MACD backend defaults', () {
    const strategy = StrategyDefinition(
      id: 'strategy-2',
      code: 'macd_trend',
      name: 'MACD Trend',
      description: '',
      defaultParameters: {
        'fast_window': 12,
        'slow_window': 26,
        'signal_window': 9,
      },
    );
    final specs = strategyParameterSpecsFor(strategy.code);

    expect(strategyParameterDefaultText(strategy, specs[0]), '12');
    expect(strategyParameterDefaultText(strategy, specs[1]), '26');
    expect(strategyParameterDefaultText(strategy, specs[2]), '9');
  });

  test('strategyParameterDefaultText reads price break MA defaults', () {
    const strategy = StrategyDefinition(
      id: 'strategy-3',
      code: 'price_break_ma',
      name: 'Price Break MA',
      description: '',
      defaultParameters: {'ma_window': 10, 'direction': 'break_down'},
    );
    final specs = strategyParameterSpecsFor(strategy.code);

    expect(strategyParameterDefaultText(strategy, specs[0]), '10');
    expect(strategyParameterDefaultText(strategy, specs[1]), 'break_down');
  });

  test('strategyParameterDefaultText reads list defaults', () {
    const strategy = StrategyDefinition(
      id: 'strategy-4',
      code: 'composite_factor',
      name: 'Composite Factor',
      description: '',
      defaultParameters: {
        'factor_codes': ['volume_breakout', 'trend_score'],
        'mode': 'all',
        'confirm_window': 3,
      },
    );
    final specs = strategyParameterSpecsFor(strategy.code);

    expect(
      strategyParameterDefaultText(strategy, specs[0]),
      'volume_breakout,trend_score',
    );
  });
}
