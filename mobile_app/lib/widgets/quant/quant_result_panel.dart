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
    this.isHistoricalResult = false,
  });

  final BacktestResult result;
  final List<Candle> candles;
  final bool isHistoricalResult;

  @override
  Widget build(BuildContext context) {
    final run = result.run;
    final totalReturn = run.summaryDouble('total_return') * 100;
    final maxDrawdown = run.summaryDouble('max_drawdown') * 100;
    final finalEquity = run.summaryDouble('final_equity');
    final winRate = run.summaryDouble('win_rate') * 100;
    final roundTripCount = run.summaryDouble('round_trip_count').round();
    final failureMessage = _failureMessage(run);

    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuantPanelHeader(
            title: isHistoricalResult ? '历史回测详情' : '回测结果',
            icon: Icons.analytics_rounded,
          ),
          const SizedBox(height: 10),
          _ResultContextBar(run: run, isHistoricalResult: isHistoricalResult),
          const SizedBox(height: 10),
          if (failureMessage != null) ...[
            _ResultNotice(
              icon: Icons.error_outline_rounded,
              text: failureMessage,
              color: const Color(0xFFFF3B45),
            ),
            const SizedBox(height: 14),
            _QuantResultSectionTitle(title: '参数'),
            const SizedBox(height: 8),
            _BacktestParameterSnapshot(run: run),
          ] else ...[
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
            if (candles.isEmpty)
              _ResultNotice(
                icon: Icons.candlestick_chart_rounded,
                text: '历史结果已加载，但当前 K 线数据不足，无法绘制买卖点图。',
                color: secondaryTextColor(context),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: softCardColor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: BacktestKlineTradeChart(
                  candles: candles,
                  trades: result.trades,
                  shortMaWindow: _chartShortMaWindow(run),
                  longMaWindow: _chartLongMaWindow(run),
                ),
              ),
            const SizedBox(height: 14),
            _QuantResultSectionTitle(title: '交易记录'),
            const SizedBox(height: 8),
            QuantTradeList(trades: result.trades),
          ],
        ],
      ),
    );
  }
}

class _ResultContextBar extends StatelessWidget {
  const _ResultContextBar({
    required this.run,
    required this.isHistoricalResult,
  });

  final BacktestRun run;
  final bool isHistoricalResult;

  @override
  Widget build(BuildContext context) {
    final title = run.name.isEmpty ? run.stockCode : run.name;
    final subtitle =
        '${_strategyLabel(run.strategyCode)} / ${run.stockCode} / '
        '${quantDateText(run.startDate)} - ${quantDateText(run.endDate)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Row(
        children: [
          Icon(
            isHistoricalResult
                ? Icons.manage_search_rounded
                : Icons.play_circle_outline_rounded,
            color: mutedIconColor(context),
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHistoricalResult ? '当前查看历史回测' : '刚刚完成的回测',
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultNotice extends StatelessWidget {
  const _ResultNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
  if (run.strategyCode == 'macd_trend') {
    return [
      _SnapshotItem('快线周期', _parameterText(run, 'fast_window')),
      _SnapshotItem('慢线周期', _parameterText(run, 'slow_window')),
      _SnapshotItem('信号周期', _parameterText(run, 'signal_window')),
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
    'macd_trend' => 'MACD Trend',
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

int _chartShortMaWindow(BacktestRun run) {
  if (run.strategyCode != 'ma_cross') return 5;
  return _intParameter(run, 'short_window', fallback: 5);
}

int _chartLongMaWindow(BacktestRun run) {
  if (run.strategyCode != 'ma_cross') return 20;
  return _intParameter(run, 'long_window', fallback: 20);
}

int _intParameter(BacktestRun run, String key, {required int fallback}) {
  final value = run.parameters[key];
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.round();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) return parsed;
  }
  return fallback;
}

String? _failureMessage(BacktestRun run) {
  if (run.status != 'failed') return null;
  final errorMessage = run.summary['error_message'];
  if (errorMessage is String && errorMessage.isNotEmpty) return errorMessage;
  final error = run.summary['error'];
  return switch (error) {
    'unsupported_strategy' => '暂不支持该策略',
    'invalid_ma_parameters' => '均线参数不合法，短均线必须小于长均线',
    'invalid_rsi_parameters' => 'RSI 参数不合法，请检查周期和超买超卖线',
    'invalid_macd_parameters' => 'MACD 参数不合法，请检查快线和慢线周期',
    'not_enough_candles' => 'K 线数据不足，无法完成回测',
    String value when value.isNotEmpty => value,
    _ => '回测失败，请检查参数和 K 线数据',
  };
}

String _formatRate(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
