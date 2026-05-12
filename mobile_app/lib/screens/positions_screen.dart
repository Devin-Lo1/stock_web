import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../models/candle.dart';
import '../models/stock_position.dart';
import '../utils/formatters.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/market_switch.dart';
import '../widgets/common/page_title.dart';
import '../widgets/position/position_tile.dart';
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

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        itemCount: positions.isEmpty ? 2 : positions.length + 1,
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
          final position = positions[index - 1];
          return PositionTile(
            position: position,
            onTap: () => _openPositionDetail(
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
