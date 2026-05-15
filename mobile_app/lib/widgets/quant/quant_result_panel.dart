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
                  label: '交易次数',
                  value: '${result.trades.length}',
                  color: primaryTextColor(context),
                ),
              ),
            ],
          ),
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
