import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../models/candle.dart';
import '../models/capital_flow.dart';
import '../models/notification_models.dart';
import '../models/position_snapshot.dart';
import '../models/position_trade.dart';
import '../models/stock_position.dart';
import '../models/strategy_monitor.dart';
import '../models/trade_signal.dart';
import '../utils/formatters.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/market_switch.dart';
import '../widgets/common/page_title.dart';
import '../widgets/position/brokerage_position_table.dart';
import 'position_detail_screen.dart';

class PositionsScreen extends StatelessWidget {
  const PositionsScreen({
    super.key,
    required this.positions,
    required this.selectedMarket,
    required this.onMarketChanged,
    required this.onAddPosition,
    required this.onEditPosition,
    required this.onDeletePosition,
    required this.onRefresh,
    required this.onLoadCandles,
    required this.onLoadCapitalFlow,
    required this.onLoadPositionTrades,
    required this.onLoadPositionSnapshots,
    required this.onCreatePositionTrade,
    required this.onDeletePositionTrade,
    required this.onLoadStrategyMonitors,
    required this.onLoadPositionSignals,
    required this.onLoadPositionPushRecords,
    required this.onUpdateStrategyMonitor,
    required this.onDeleteStrategyMonitor,
    required this.onIgnoreSignal,
    required this.onOpenStrategyMonitor,
  });

  final List<StockPosition> positions;
  final MarketFilter selectedMarket;
  final ValueChanged<MarketFilter> onMarketChanged;
  final VoidCallback onAddPosition;
  final Future<StockPosition?> Function(StockPosition position) onEditPosition;
  final ValueChanged<StockPosition> onDeletePosition;
  final Future<List<StockPosition>> Function() onRefresh;
  final Future<List<Candle>> Function(String code, {String period, int limit})
  onLoadCandles;
  final Future<CapitalFlowSnapshot> Function(String code) onLoadCapitalFlow;
  final Future<List<PositionTrade>> Function(StockPosition position)
  onLoadPositionTrades;
  final Future<List<PositionSnapshot>> Function(StockPosition position)
  onLoadPositionSnapshots;
  final Future<StockPosition?> Function(
    StockPosition position,
    PositionTradeDraft draft,
  )
  onCreatePositionTrade;
  final Future<StockPosition?> Function(
    StockPosition position,
    PositionTrade trade,
  )
  onDeletePositionTrade;
  final Future<List<StrategyMonitor>> Function(StockPosition position)
  onLoadStrategyMonitors;
  final Future<List<TradeSignal>> Function(StockPosition position)
  onLoadPositionSignals;
  final Future<List<PushRecord>> Function(
    StockPosition position,
    List<TradeSignal> signals,
  )
  onLoadPositionPushRecords;
  final Future<StrategyMonitor> Function(
    StrategyMonitor monitor, {
    bool? enabled,
    bool? pushCandidate,
  })
  onUpdateStrategyMonitor;
  final Future<void> Function(StrategyMonitor monitor) onDeleteStrategyMonitor;
  final Future<void> Function(TradeSignal signal) onIgnoreSignal;
  final Future<void> Function(StockPosition position) onOpenStrategyMonitor;

  @override
  Widget build(BuildContext context) {
    final hasBackendMetrics =
        positions.isNotEmpty &&
        positions.every((position) => position.hasBackendMetrics);
    final totalProfit = hasBackendMetrics
        ? positions.fold<double>(
            0,
            (sum, position) => sum + position.backendHoldingProfit!,
          )
        : 0.0;
    final totalMarketValue = hasBackendMetrics
        ? positions.fold<double>(
            0,
            (sum, position) => sum + position.backendMarketValue!,
          )
        : 0.0;
    final totalDailyProfit = hasBackendMetrics
        ? positions.fold<double>(
            0,
            (sum, position) => sum + position.backendDayProfit!,
          )
        : 0.0;
    final summaryProfitText = hasBackendMetrics
        ? formatHkd(totalProfit)
        : '后端收益未同步';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        itemCount: positions.isEmpty ? 2 : 3,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return PageTitle(
              title: '持仓',
              subtitle: '${positions.length} 只股票 · 总盈亏 $summaryProfitText',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MarketSwitch(
                    selectedMarket: selectedMarket,
                    onChanged: onMarketChanged,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onAddPosition,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('添加'),
                  ),
                ],
              ),
            );
          }
          if (positions.isEmpty) {
            return EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              title: '还没有持仓',
              subtitle: '先添加持仓，下一步再接后端行情和策略信号。',
              actionLabel: '添加持仓',
              onAction: onAddPosition,
            );
          }
          if (index == 1) {
            return _PositionAccountSummary(
              selectedMarket: selectedMarket,
              totalMarketValue: totalMarketValue,
              totalProfit: totalProfit,
              totalDailyProfit: totalDailyProfit,
              positionCount: positions.length,
              hasBackendMetrics: hasBackendMetrics,
            );
          }
          return BrokeragePositionTable(
            positions: positions,
            onPositionTap: (position) => _openPositionDetail(
              context,
              position,
              onEditPosition,
              () => onDeletePosition(position),
              onRefresh,
              onLoadCandles,
              onLoadCapitalFlow,
              onLoadPositionTrades,
              onLoadPositionSnapshots,
              onCreatePositionTrade,
              onDeletePositionTrade,
              onLoadStrategyMonitors,
              onLoadPositionSignals,
              onLoadPositionPushRecords,
              onUpdateStrategyMonitor,
              onDeleteStrategyMonitor,
              onIgnoreSignal,
              onOpenStrategyMonitor,
            ),
          );
        },
      ),
    );
  }
}

void _openPositionDetail(
  BuildContext context,
  StockPosition position,
  Future<StockPosition?> Function(StockPosition position) onEdit,
  VoidCallback onDelete,
  Future<List<StockPosition>> Function() onRefresh,
  Future<List<Candle>> Function(String code, {String period, int limit})
  onLoadCandles,
  Future<CapitalFlowSnapshot> Function(String code) onLoadCapitalFlow,
  Future<List<PositionTrade>> Function(StockPosition position)
  onLoadPositionTrades,
  Future<List<PositionSnapshot>> Function(StockPosition position)
  onLoadPositionSnapshots,
  Future<StockPosition?> Function(
    StockPosition position,
    PositionTradeDraft draft,
  )
  onCreatePositionTrade,
  Future<StockPosition?> Function(StockPosition position, PositionTrade trade)
  onDeletePositionTrade,
  Future<List<StrategyMonitor>> Function(StockPosition position)
  onLoadStrategyMonitors,
  Future<List<TradeSignal>> Function(StockPosition position)
  onLoadPositionSignals,
  Future<List<PushRecord>> Function(
    StockPosition position,
    List<TradeSignal> signals,
  )
  onLoadPositionPushRecords,
  Future<StrategyMonitor> Function(
    StrategyMonitor monitor, {
    bool? enabled,
    bool? pushCandidate,
  })
  onUpdateStrategyMonitor,
  Future<void> Function(StrategyMonitor monitor) onDeleteStrategyMonitor,
  Future<void> Function(TradeSignal signal) onIgnoreSignal,
  Future<void> Function(StockPosition position) onOpenStrategyMonitor,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PositionDetailScreen(
        position: position,
        onEdit: onEdit,
        onDelete: onDelete,
        onRefresh: onRefresh,
        onLoadCandles: onLoadCandles,
        onLoadCapitalFlow: onLoadCapitalFlow,
        onLoadPositionTrades: onLoadPositionTrades,
        onLoadPositionSnapshots: onLoadPositionSnapshots,
        onCreatePositionTrade: onCreatePositionTrade,
        onDeletePositionTrade: onDeletePositionTrade,
        onLoadStrategyMonitors: onLoadStrategyMonitors,
        onLoadPositionSignals: onLoadPositionSignals,
        onLoadPositionPushRecords: onLoadPositionPushRecords,
        onUpdateStrategyMonitor: onUpdateStrategyMonitor,
        onDeleteStrategyMonitor: onDeleteStrategyMonitor,
        onIgnoreSignal: onIgnoreSignal,
        onOpenStrategyMonitor: onOpenStrategyMonitor,
      ),
    ),
  );
}

class _PositionAccountSummary extends StatelessWidget {
  const _PositionAccountSummary({
    required this.selectedMarket,
    required this.totalMarketValue,
    required this.totalProfit,
    required this.totalDailyProfit,
    required this.positionCount,
    required this.hasBackendMetrics,
  });

  final MarketFilter selectedMarket;
  final double totalMarketValue;
  final double totalProfit;
  final double totalDailyProfit;
  final int positionCount;
  final bool hasBackendMetrics;

  @override
  Widget build(BuildContext context) {
    final profitRate = totalMarketValue <= 0
        ? 0.0
        : totalProfit / totalMarketValue * 100;
    final dailyRate = totalMarketValue <= 0
        ? 0.0
        : totalDailyProfit / totalMarketValue * 100;
    final currency = selectedMarket == MarketFilter.us ? 'USD' : 'HKD';
    final marketLabel = selectedMarket == MarketFilter.us ? '美股市值' : '港股市值';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasBackendMetrics) ...[
            Text(
              '后端持仓收益快照未同步',
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '$marketLabel($currency)',
                  value: hasBackendMetrics
                      ? _formatSummaryMoney(
                          selectedMarket,
                          totalMarketValue,
                          signed: false,
                        )
                      : '--',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  label: '持仓盈亏',
                  value: hasBackendMetrics
                      ? _formatSummaryMoney(selectedMarket, totalProfit)
                      : '--',
                  subValue: hasBackendMetrics
                      ? formatPercent(profitRate)
                      : null,
                  color: _profitColor(totalProfit),
                  crossAxisAlignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '今日盈亏',
                  value: hasBackendMetrics
                      ? _formatSummaryMoney(selectedMarket, totalDailyProfit)
                      : '--',
                  subValue: hasBackendMetrics ? formatPercent(dailyRate) : null,
                  color: _profitColor(totalDailyProfit),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  label: '持仓数量',
                  value: '$positionCount',
                  crossAxisAlignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    this.subValue,
    this.color,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? subValue;
  final Color? color;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final valueColor = color ?? primaryTextColor(context);
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: secondaryTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: crossAxisAlignment == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: crossAxisAlignment == CrossAxisAlignment.end
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          Text(
            subValue!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor.withValues(alpha: 0.82),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

String _formatSummaryMoney(
  MarketFilter market,
  double value, {
  bool signed = true,
}) {
  final prefix = market == MarketFilter.us ? 'US\$' : 'HK\$';
  if (!signed) return '$prefix${value.abs().toStringAsFixed(2)}';
  if (value == 0) return '${prefix}0.00';
  final sign = value > 0 ? '+' : '-';
  return '$sign$prefix${value.abs().toStringAsFixed(2)}';
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF4D67);
}
