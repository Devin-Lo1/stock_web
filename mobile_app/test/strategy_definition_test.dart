import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/models/strategy_definition.dart';

void main() {
  test('StrategyDefinition displayName appends Chinese strategy label', () {
    const strategy = StrategyDefinition(
      id: 'strategy-1',
      code: 'ma_cross',
      name: 'MA Cross',
      description: '',
      defaultParameters: {},
    );

    expect(strategy.displayName, 'MA Cross（均线交叉）');
  });

  test('strategyDisplayNameForCode falls back to known English name', () {
    expect(
      strategyDisplayNameForCode('composite_factor'),
      'Composite Factor（组合因子）',
    );
  });
}
