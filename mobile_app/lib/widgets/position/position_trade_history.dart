import 'package:flutter/material.dart';

import '../../models/position_trade.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';

class PositionTradeHistory extends StatelessWidget {
  const PositionTradeHistory({
    super.key,
    required this.trades,
    this.onDeleteTrade,
  });

  final List<PositionTrade> trades;
  final ValueChanged<PositionTrade>? onDeleteTrade;

  @override
  Widget build(BuildContext context) {
    final rows = List<PositionTrade>.of(trades)
      ..sort((a, b) {
        final left = a.tradeTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.tradeTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return Container(
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              '交易历史',
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              child: Text(
                '暂无交易记录',
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...rows.map(
              (trade) => _TradeHistoryRow(
                trade: trade,
                showBorder: trade != rows.last,
                onDelete: onDeleteTrade == null
                    ? null
                    : () => onDeleteTrade!(trade),
              ),
            ),
        ],
      ),
    );
  }
}

class _TradeHistoryRow extends StatelessWidget {
  const _TradeHistoryRow({
    required this.trade,
    required this.showBorder,
    required this.onDelete,
  });

  final PositionTrade trade;
  final bool showBorder;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = switch (trade.action) {
      'open' || 'add' => const Color(0xFF12B886),
      'reduce' || 'close' => const Color(0xFFFF4D67),
      _ => primaryTextColor(context),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(bottom: BorderSide(color: borderColor(context)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              trade.actionLabel,
              style: TextStyle(
                color: color,
                fontSize: 12,
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
                  '${formatNumberInput(trade.quantity)} 股 · ${_formatMoney(trade.currency, trade.price)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateTime(trade.tradeTime)} · 费用 ${_formatMoney(trade.currency, trade.fee)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: '删除交易记录',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatMoney(String currency, double value) {
  final prefix = switch (currency.toUpperCase()) {
    'USD' => 'US\$',
    'CNY' => 'CN¥',
    _ => 'HK\$',
  };
  return '$prefix${value.toStringAsFixed(2)}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '--';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}/$month/$day $hour:$minute';
}
