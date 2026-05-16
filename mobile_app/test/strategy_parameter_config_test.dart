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
}
