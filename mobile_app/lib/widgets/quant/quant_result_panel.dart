import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../models/candle.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';
import '../backtest/backtest_equity_chart.dart';
import '../backtest/backtest_kline_trade_chart.dart';
import 'quant_common_widgets.dart';
import 'quant_trade_list.dart';

class QuantResultPanel extends StatelessWidget {
  const QuantResultPanel({
    super.key,
    required this.result,
    required this.candles,
  });

  final BacktestResult result;
  final List<Candle> candles;

  @override
  Widget build(BuildContext context) {
    final run = result.run;
    final totalReturn = run.summaryDouble('total_return') * 100;
    final maxDrawdown = run.summaryDouble('max_drawdown') * 100;
    final finalEquity = run.summaryDouble('final_equity');
    final winRate = run.summaryDouble('win_rate') * 100;
    final roundTripCount = run.summaryDouble('round_trip_count').round();

    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuantPanelHeader(title: '结果', icon: Icons.analytics_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: QuantMetric(
                  label: '总收益',
                  value: formatPercent(totalReturn),
                  color: quantProfitColor(totalReturn),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuantMetric(
                  label: '最大回撤',
                  value: formatPercent(maxDrawdown),
                  color: const Color(0xFFFF3B45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: QuantMetric(
                  label: '期末权益',
                  value: formatHkd(finalEquity, showSign: false),
                  color: primaryTextColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuantMetric(
                  label: '胜率',
                  value: roundTripCount == 0 ? '--' : formatPercent(winRate),
                  color: roundTripCount == 0
                      ? secondaryTextColor(context)
                      : quantProfitColor(winRate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: QuantMetric(
                  label: '交易次数',
                  value: '${run.summaryDouble('trade_count').round()}',
                  color: primaryTextColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuantMetric(
                  label: '买卖回合',
                  value: '$roundTripCount',
                  color: primaryTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _QuantResultSectionTitle(title: '参数'),
          const SizedBox(height: 8),
          _BacktestParameterSnapshot(run: run),
          const SizedBox(height: 14),
          _QuantResultSectionTitle(title: '收益曲线'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: softCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: BacktestEquityChart(points: result.equityCurve),
          ),
          const SizedBox(height: 14),
          _QuantResultSectionTitle(title: '买卖点'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: softCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: BacktestKlineTradeChart(
              candles: candles,
              trades: result.trades,
            ),
          ),
          const SizedBox(height: 14),
          _QuantResultSectionTitle(title: '交易记录'),
          const SizedBox(height: 8),
          QuantTradeList(trades: result.trades),
        ],
      ),
    );
  }
}

class _BacktestParameterSnapshot extends StatelessWidget {
  const _BacktestParameterSnapshot({required this.run});

  final BacktestRun run;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SnapshotItem('策略', _strategyLabel(run.strategyCode)),
      _SnapshotItem('股票', run.stockCode),
      _SnapshotItem(
        '区间',
        '${quantDateText(run.startDate)} - ${quantDateText(run.endDate)}',
        span: 3,
      ),
      _SnapshotItem('初始资金', formatHkd(run.initialCash, showSign: false)),
      _SnapshotItem('手续费率', _formatRate(run.feeRate)),
      _SnapshotItem('滑点率', _formatRate(run.slippageRate)),
      ..._strategyParameterItems(run),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final columnWidth = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                _SnapshotChip(
                  item: item,
                  width: item.span == 3
                      ? constraints.maxWidth
                      : columnWidth * item.span + gap * (item.span - 1),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SnapshotItem {
  const _SnapshotItem(this.label, this.value, {this.span = 1});

  final String label;
  final String value;
  final int span;
}

class _SnapshotChip extends StatelessWidget {
  const _SnapshotChip({required this.item, required this.width});

  final _SnapshotItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: item.span == 3 ? 54 : 56,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.value,
              maxLines: item.span == 3 ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: item.span == 3 ? 12 : 12,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantResultSectionTitle extends StatelessWidget {
  const _QuantResultSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: primaryTextColor(context),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

List<_SnapshotItem> _strategyParameterItems(BacktestRun run) {
  if (run.strategyCode == 'rsi_reversal') {
    return [
      _SnapshotItem('RSI 周期', _parameterText(run, 'rsi_window')),
      _SnapshotItem('超卖线', _parameterText(run, 'oversold')),
      _SnapshotItem('超买线', _parameterText(run, 'overbought')),
    ];
  }
  return [
    _SnapshotItem('短均线', _parameterText(run, 'short_window')),
    _SnapshotItem('长均线', _parameterText(run, 'long_window')),
  ];
}

String _strategyLabel(String code) {
  return switch (code) {
    'ma_cross' => 'MA Cross',
    'rsi_reversal' => 'RSI Reversal',
    _ => code,
  };
}

String _parameterText(BacktestRun run, String key) {
  final value = run.parameters[key];
  if (value is num) return formatNumberInput(value.toDouble());
  if (value is String && value.isNotEmpty) return value;
  return '--';
}

String _formatRate(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
