import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../models/candle.dart';
import '../models/stock_position.dart';
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

  @override
  Widget build(BuildContext context) {
    final totalProfit = positions.fold<double>(
      0,
      (sum, position) => sum + position.profit,
    );
    final totalMarketValue = positions.fold<double>(
      0,
      (sum, position) => sum + position.marketValue,
    );
    final totalDailyProfit = positions.fold<double>(
      0,
      (sum, position) => sum + position.dailyProfit,
    );

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
              subtitle:
                  '${positions.length} 只股票 · 总盈亏 ${formatHkd(totalProfit)}',
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
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PositionDetailScreen(
        position: position,
        onEdit: onEdit,
        onDelete: onDelete,
        onRefresh: onRefresh,
        onLoadCandles: onLoadCandles,
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
  });

  final MarketFilter selectedMarket;
  final double totalMarketValue;
  final double totalProfit;
  final double totalDailyProfit;
  final int positionCount;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '$marketLabel($currency)',
                  value: _formatSummaryMoney(
                    selectedMarket,
                    totalMarketValue,
                    signed: false,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  label: '持仓盈亏',
                  value: _formatSummaryMoney(selectedMarket, totalProfit),
                  subValue: formatPercent(profitRate),
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
                  value: _formatSummaryMoney(selectedMarket, totalDailyProfit),
                  subValue: formatPercent(dailyRate),
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
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
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
  if (!signed) return '$prefix ${value.abs().toStringAsFixed(2)}';
  if (value == 0) return '$prefix 0.00';
  final sign = value > 0 ? '+' : '-';
  return '$sign$prefix ${value.abs().toStringAsFixed(2)}';
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF4D67);
}
