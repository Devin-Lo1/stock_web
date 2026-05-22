import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../models/backend_connection_state.dart';
import '../models/candle.dart';
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
import '../widgets/common/section_header.dart';
import '../widgets/position/position_tile.dart';
import '../widgets/signal/signal_tile.dart';
import 'position_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.positions,
    required this.signals,
    required this.selectedMarket,
    required this.onMarketChanged,
    required this.onAccountTap,
    required this.onAddPosition,
    required this.onEditPosition,
    required this.onDeletePosition,
    required this.onRefresh,
    required this.onLoadCandles,
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
    required this.isRefreshing,
    required this.backendState,
    required this.lastUpdatedAt,
  });

  final List<StockPosition> positions;
  final List<TradeSignal> signals;
  final MarketFilter selectedMarket;
  final ValueChanged<MarketFilter> onMarketChanged;
  final VoidCallback onAccountTap;
  final VoidCallback onAddPosition;
  final Future<StockPosition?> Function(StockPosition position) onEditPosition;
  final ValueChanged<StockPosition> onDeletePosition;
  final Future<List<StockPosition>> Function() onRefresh;
  final Future<List<Candle>> Function(String code, {String period, int limit})
  onLoadCandles;
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
  final bool isRefreshing;
  final BackendConnectionState backendState;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF38BDF8),
      backgroundColor: cardColor(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    onAccountTap: onAccountTap,
                    onRefresh: onRefresh,
                    isRefreshing: isRefreshing,
                    backendState: backendState,
                    lastUpdatedAt: lastUpdatedAt,
                  ),
                  const SizedBox(height: 14),
                  _AssetOverview(positions: positions),
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: '持仓追踪',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarketSwitch(
                          selectedMarket: selectedMarket,
                          onChanged: onMarketChanged,
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: onAddPosition,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('添加'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverList.separated(
            itemCount: positions.isEmpty ? 1 : positions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (positions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    title: '还没有持仓',
                    subtitle: '添加第一只股票后，这里会展示现价、盈亏和信号。',
                    actionLabel: '添加持仓',
                    onAction: onAddPosition,
                  ),
                );
              }
              final position = positions[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PositionTile(
                  position: position,
                  onTap: () => _openPositionDetail(
                    context,
                    position,
                    onEditPosition,
                    () => onDeletePosition(position),
                    onRefresh,
                    onLoadCandles,
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
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '最新信号'),
                  const SizedBox(height: 8),
                  if (signals.isEmpty)
                    const ReadOnlyEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: '暂无信号',
                      subtitle: '触发止盈、止损或当日异动后会出现在这里。',
                    )
                  else
                    ...signals.map(
                      (signal) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SignalTile(signal: signal),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onAccountTap,
    required this.onRefresh,
    required this.isRefreshing,
    required this.backendState,
    required this.lastUpdatedAt,
  });

  final VoidCallback onAccountTap;
  final Future<List<StockPosition>> Function() onRefresh;
  final bool isRefreshing;
  final BackendConnectionState backendState;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: softCardColor(context),
              foregroundColor: primaryTextColor(context),
            ),
            onPressed: onAccountTap,
            icon: const Icon(Icons.person_rounded, size: 28),
            tooltip: '查看账户',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${backendState.headerLabel} · ${_updatedLabel(lastUpdatedAt)}',
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '点击头像查看账户',
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: softCardColor(context),
            foregroundColor: primaryTextColor(context),
          ),
          onPressed: isRefreshing ? null : () => onRefresh(),
          icon: isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          tooltip: '刷新行情',
        ),
      ],
    );
  }
}

String _updatedLabel(DateTime? value) {
  if (value == null) return '尚未更新';
  final now = DateTime.now();
  final difference = now.difference(value);
  if (difference.inSeconds < 60) return '刚刚更新';
  if (difference.inMinutes < 60) return '${difference.inMinutes} 分钟前更新';
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} 更新';
}

class _AssetOverview extends StatelessWidget {
  const _AssetOverview({required this.positions});

  final List<StockPosition> positions;

  @override
  Widget build(BuildContext context) {
    final totalMarketValue = positions.fold<double>(
      0,
      (sum, position) => sum + position.marketValue,
    );
    final totalCost = positions.fold<double>(
      0,
      (sum, position) => sum + position.costValue,
    );
    final totalDailyProfit = positions.fold<double>(
      0,
      (sum, position) => sum + position.dailyProfit,
    );
    final totalProfit = totalMarketValue - totalCost;
    final totalProfitRate = totalCost == 0
        ? 0.0
        : totalProfit / totalCost * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '总资产估值',
            style: TextStyle(color: secondaryTextColor(context), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            formatHkd(totalMarketValue, showSign: false, decimals: 2),
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '当日收益',
                  value: formatHkd(totalDailyProfit),
                  subValue: formatPercent(_dailyProfitRate(positions)),
                  color: _profitColor(totalDailyProfit),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: '持有收益',
                  value: formatHkd(totalProfit),
                  subValue: formatPercent(totalProfitRate),
                  color: _profitColor(totalProfit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.subValue,
    required this.color,
  });

  final String label;
  final String value;
  final String? subValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subValue != null)
            Text(
              subValue!,
              style: TextStyle(
                color: color.withValues(alpha: 0.82),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
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

double _dailyProfitRate(List<StockPosition> positions) {
  final previousMarketValue = positions.fold<double>(
    0,
    (sum, position) => sum + position.previousClose * position.quantity,
  );
  final dailyProfit = positions.fold<double>(
    0,
    (sum, position) => sum + position.dailyProfit,
  );
  return previousMarketValue == 0 ? 0 : dailyProfit / previousMarketValue * 100;
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF3B45);
}
