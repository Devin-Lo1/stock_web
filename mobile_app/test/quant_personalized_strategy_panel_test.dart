import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/models/personalized_strategy.dart';
import 'package:stock_mobile/widgets/backtest/backtest_kline_trade_chart.dart';
import 'package:stock_mobile/widgets/quant/quant_personalized_strategy_panel.dart';

void main() {
  testWidgets('personalized strategies are separated by market first', (
    tester,
  ) async {
    await tester.pumpWidget(
      _panelHarness(templates: [_template('HK.02628'), _template('US.NVDA')]),
    );

    expect(find.text('港股策略'), findsOneWidget);
    expect(find.text('美股策略'), findsOneWidget);
    expect(find.text('HK.02628'), findsNothing);
    expect(find.text('US.NVDA'), findsNothing);

    await tester.tap(find.text('港股策略'));
    await tester.pumpAndSettle();

    expect(find.text('HK.02628'), findsWidgets);
    expect(find.text('US.NVDA'), findsNothing);
  });

  testWidgets('personalized strategy details show replay trades after scan', (
    tester,
  ) async {
    final template = _template('HK.02628');
    await tester.pumpWidget(
      _panelHarness(
        templates: [template],
        scanResults: {template.code.toUpperCase(): _scanResult(template)},
      ),
    );

    await tester.tap(find.text('港股策略'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('策略细节'));
    await tester.tap(find.text('策略细节'));
    await tester.pumpAndSettle();

    expect(find.text('买卖点回放'), findsOneWidget);
    expect(find.byType(BacktestKlineTradeChart), findsOneWidget);
    expect(find.text('买入'), findsOneWidget);
    expect(find.text('卖出'), findsOneWidget);
  });
}

Widget _panelHarness({
  required List<PersonalizedStrategyTemplate> templates,
  Map<String, PersonalizedStrategyScanResult> scanResults = const {},
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: QuantPersonalizedStrategyPanel(
          templates: templates,
          scanResults: scanResults,
          recommendations: const [],
          scanningTemplateCodes: const {},
          isLoading: false,
          isScanningAll: false,
          onReload: () {},
          onScan: (_) {},
          onScanAll: () {},
        ),
      ),
    ),
  );
}

PersonalizedStrategyTemplate _template(String symbol) {
  return PersonalizedStrategyTemplate(
    code: 'template_$symbol',
    symbol: symbol,
    name: '$symbol 测试策略',
    description: '测试策略',
    benchmarkSymbol: symbol.startsWith('HK.') ? 'HK.800000' : 'US.QQQ',
    directionMode: 'long_short',
    riskLevel: 'steady',
    positionRatio: 1,
    maxHoldDays: 20,
    parameters: const {
      'engine': 'ma_cross',
      'short_window': 5,
      'long_window': 20,
    },
    entryRules: const ['均线金叉做多'],
    exitRules: const ['均线死叉退出'],
    segments: [
      PersonalizedStrategySegment(
        label: '2026YTD',
        startDate: DateTime(2026),
        endDate: DateTime(2026, 6, 8),
        totalReturn: 0.12,
        maxDrawdown: -0.05,
        winRate: 1,
        roundTripCount: 2,
      ),
    ],
  );
}

PersonalizedStrategyScanResult _scanResult(
  PersonalizedStrategyTemplate template,
) {
  final decision = PersonalizedStrategyDecision(
    kind: 'previous_close',
    title: '昨日收盘信号',
    action: 'long_exit',
    actionLabel: '平多观察',
    currentPosition: 'flat',
    latestDate: DateTime(2026, 6, 8),
    latestPrice: 28,
    signalDate: DateTime(2026, 6, 8),
    reason: 'take_profit',
    flatDecision: '等待',
    longDecision: '退出',
    shortDecision: '等待',
    isRealtime: false,
    isConfirmed: true,
    detail: const {
      'candles': [
        {
          'code': 'HK.02628',
          'market': 'HK',
          'period': 'day',
          'time': '2026-06-01T00:00:00Z',
          'open': 20.0,
          'high': 21.0,
          'low': 19.5,
          'close': 20.5,
          'volume': 1000.0,
          'turnover': 20500.0,
        },
        {
          'code': 'HK.02628',
          'market': 'HK',
          'period': 'day',
          'time': '2026-06-02T00:00:00Z',
          'open': 20.5,
          'high': 22.0,
          'low': 20.0,
          'close': 21.5,
          'volume': 1200.0,
          'turnover': 25800.0,
        },
      ],
      'events': [
        {
          'date': '2026-06-01',
          'action': 'long_entry',
          'price': 20.5,
          'reason': 'ma_cross_up_with_filters',
        },
        {
          'date': '2026-06-02',
          'action': 'long_exit',
          'price': 21.5,
          'reason': 'take_profit',
        },
      ],
    },
  );
  return PersonalizedStrategyScanResult(
    template: template,
    status: 'completed',
    action: 'long_exit',
    actionLabel: '平多观察',
    currentPosition: 'flat',
    latestDate: DateTime(2026, 6, 8),
    latestClose: 28,
    signalDate: DateTime(2026, 6, 8),
    reason: 'take_profit',
    refreshError: null,
    todaySignal: decision,
    previousCloseSignal: decision,
    detail: const {},
  );
}
