import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../utils/theme_helpers.dart';
import 'quant_common_widgets.dart';

class QuantTradeList extends StatelessWidget {
  const QuantTradeList({
    super.key,
    required this.trades,
    this.maxVisibleRows = 8,
  });

  final List<BacktestTrade> trades;
  final int maxVisibleRows;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Text('暂无交易', style: TextStyle(color: secondaryTextColor(context)));
    }
    final visibleRows = trades.length < maxVisibleRows
        ? trades.length
        : maxVisibleRows;
    final listHeight = visibleRows * 44.0 + (visibleRows - 1) * 8.0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: SizedBox(
        height: listHeight,
        child: Scrollbar(
          child: ListView.separated(
            primary: false,
            padding: EdgeInsets.zero,
            itemCount: trades.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _TradeRow(trade: trades[index]),
          ),
        ),
      ),
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.trade});

  final BacktestTrade trade;

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.side == 'buy';
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: (isBuy ? const Color(0xFF12B886) : const Color(0xFFFF3B45))
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isBuy ? '买入' : '卖出',
              style: TextStyle(
                color: isBuy
                    ? const Color(0xFF12B886)
                    : const Color(0xFFFF3B45),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${quantDateText(trade.time)}  ${trade.quantity.toStringAsFixed(2)}股',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: primaryTextColor(context)),
            ),
          ),
          Text(
            trade.price.toStringAsFixed(2),
            style: TextStyle(
              color: primaryTextColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
