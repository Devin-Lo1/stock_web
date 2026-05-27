import 'package:flutter/material.dart';

import '../models/backtest_models.dart';
import '../utils/formatters.dart';
import '../utils/theme_helpers.dart';
import '../widgets/backtest/volume_profile_chart.dart';
import '../widgets/quant/quant_common_widgets.dart';

class VolumeProfileResultScreen extends StatelessWidget {
  const VolumeProfileResultScreen({super.key, required this.result});

  final VolumeProfileBacktestResult result;

  @override
  Widget build(BuildContext context) {
    final request = result.request;
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: pageBackgroundColor(context),
                border: Border(bottom: BorderSide(color: borderColor(context))),
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: primaryTextColor(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '价值区回归结果',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request?.stockCode ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryTextColor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _SummaryPanel(result: result),
                  const SizedBox(height: 12),
                  QuantPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const QuantPanelHeader(
                          title: 'K线与成交量剖面',
                          icon: Icons.stacked_bar_chart_rounded,
                        ),
                        const SizedBox(height: 10),
                        VolumeProfileChart(result: result),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SignalListPanel(signals: result.signals),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.result});

  final VolumeProfileBacktestResult result;

  @override
  Widget build(BuildContext context) {
    final successRate = result.summaryDouble('success_rate') * 100;
    final triggerRate = result.summaryDouble('trigger_rate') * 100;
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuantPanelHeader(title: '统计', icon: Icons.analytics_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: QuantMetric(
                  label: '成功率',
                  value: formatPercent(successRate),
                  color: quantProfitColor(successRate),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuantMetric(
                  label: '触发率',
                  value: formatPercent(triggerRate),
                  color: appAccentColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: QuantMetric(
                  label: '触发次数',
                  value: '${result.summaryInt('triggered_count')}',
                  color: primaryTextColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuantMetric(
                  label: '成功/失败',
                  value:
                      '${result.summaryInt('success_count')}/${result.summaryInt('failed_count')}',
                  color: primaryTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: QuantMetric(
                  label: '无信号',
                  value: '${result.summaryInt('no_signal_count')}',
                  color: secondaryTextColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuantMetric(
                  label: '跳过/未完结',
                  value:
                      '${result.summaryInt('skipped_count')}/${result.summaryInt('no_result_count')}',
                  color: secondaryTextColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalListPanel extends StatelessWidget {
  const _SignalListPanel({required this.signals});

  final List<VolumeProfileSignal> signals;

  @override
  Widget build(BuildContext context) {
    final visibleSignals = signals.reversed.take(30).toList();
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuantPanelHeader(title: '每日结果', icon: Icons.list_alt_rounded),
          const SizedBox(height: 8),
          if (visibleSignals.isEmpty)
            Text('暂无结果', style: TextStyle(color: secondaryTextColor(context)))
          else
            for (final signal in visibleSignals) _SignalTile(signal: signal),
        ],
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.signal});

  final VolumeProfileSignal signal;

  @override
  Widget build(BuildContext context) {
    final color = _outcomeColor(context, signal.outcome);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor(context))),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _outcomeText(signal.outcome),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_dateText(signal.date)}  ${_directionText(signal.direction)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _signalMeta(signal),
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

  String _signalMeta(VolumeProfileSignal signal) {
    final open = signal.openPrice?.toStringAsFixed(2) ?? '--';
    final target = signal.targetPrice?.toStringAsFixed(2) ?? '--';
    final stop = signal.stopPrice?.toStringAsFixed(2) ?? '--';
    final deviation = signal.deviation == null
        ? '--'
        : formatPercent(signal.deviation! * 100);
    return '开 $open  目标 $target  止损 $stop  偏离 $deviation';
  }
}

Color _outcomeColor(BuildContext context, String outcome) {
  return switch (outcome) {
    'success' => const Color(0xFF12B886),
    'failed' => const Color(0xFFFF3B45),
    'skipped' => const Color(0xFFE6B450),
    _ => secondaryTextColor(context),
  };
}

String _outcomeText(String outcome) {
  return switch (outcome) {
    'success' => '成功',
    'failed' => '失败',
    'skipped' => '跳过',
    'no_result' => '未完结',
    'no_profile' => '无剖面',
    _ => '无信号',
  };
}

String _directionText(String? direction) {
  return switch (direction) {
    'long' => '做多',
    'short' => '做空',
    _ => '观察',
  };
}

String _dateText(DateTime? value) {
  if (value == null) return '--';
  return '${value.year.toString().padLeft(4, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}
