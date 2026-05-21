import 'package:flutter/material.dart';

import '../../models/stock_position.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';

class BrokeragePositionTable extends StatelessWidget {
  const BrokeragePositionTable({
    super.key,
    required this.positions,
    required this.onPositionTap,
  });

  final List<StockPosition> positions;
  final ValueChanged<StockPosition> onPositionTap;

  @override
  Widget build(BuildContext context) {
    final totalMarketValue = positions.fold<double>(
      0,
      (sum, position) => sum + position.marketValue,
    );

    return Container(
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _TableToolbar(count: positions.length),
          Divider(height: 1, color: borderColor(context)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Column(
                  children: [
                    const _FixedHeaderCell(),
                    ...positions.map(
                      (position) => _FixedNameCell(
                        position: position,
                        onTap: () => onPositionTap(position),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: borderColor(context)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 540,
                    child: Column(
                      children: [
                        const _MetricHeaderRow(),
                        ...positions.map(
                          (position) => _MetricRow(
                            position: position,
                            totalMarketValue: totalMarketValue,
                            onTap: () => onPositionTap(position),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableToolbar extends StatelessWidget {
  const _TableToolbar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          _PillButton(label: '持仓($count)', isSelected: true),
          const SizedBox(width: 8),
          const _PillButton(label: '订单(0)', isSelected: false),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: 0.75)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '合资格融资证券名单',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.isSelected});

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.08)
            : softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? accent : borderColor(context),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? accent : secondaryTextColor(context),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FixedHeaderCell extends StatelessWidget {
  const _FixedHeaderCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '名称',
        style: TextStyle(
          color: secondaryTextColor(context),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricHeaderRow extends StatelessWidget {
  const _MetricHeaderRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: const [
          _MetricHeaderCell(label: '可卖/持有'),
          _MetricHeaderCell(label: '现价/成本'),
          _MetricHeaderCell(label: '今日盈亏'),
          _MetricHeaderCell(label: '持仓盈亏'),
          _MetricHeaderCell(label: '市值/持仓占比'),
        ],
      ),
    );
  }
}

class _MetricHeaderCell extends StatelessWidget {
  const _MetricHeaderCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (label == '今日盈亏') ...[
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: mutedIconColor(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _FixedNameCell extends StatelessWidget {
  const _FixedNameCell({required this.position, required this.onTap});

  final StockPosition position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 82,
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor(context))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              position.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 3,
              children: [
                _MarketTag(label: _marketTag(position.code)),
                Text(
                  '${position.code} ${_currencyCode(position.code)}',
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
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.position,
    required this.totalMarketValue,
    required this.onTap,
  });

  final StockPosition position;
  final double totalMarketValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dailyColor = _profitColor(position.dailyProfit);
    final profitColor = _profitColor(position.profit);
    final weight = totalMarketValue <= 0
        ? 0
        : position.marketValue / totalMarketValue * 100;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor(context))),
        ),
        child: Row(
          children: [
            _MetricCell(
              primary: formatNumberInput(position.quantity),
              secondary: formatNumberInput(position.quantity),
            ),
            _MetricCell(
              primary: _formatPrice(position.currentPrice),
              secondary: _formatPrice(position.costPrice),
            ),
            _MetricCell(
              primary: _formatSignedMoney(position, position.dailyProfit),
              secondary: formatPercent(position.dailyProfitRate),
              color: dailyColor,
            ),
            _MetricCell(
              primary: _formatSignedMoney(position, position.profit),
              secondary: formatPercent(position.profitRate),
              color: profitColor,
            ),
            _MetricCell(
              primary: _formatMoney(position, position.marketValue),
              secondary: '${weight.toStringAsFixed(2)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.primary,
    required this.secondary,
    this.color,
  });

  final String primary;
  final String secondary;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? primaryTextColor(context);
    return SizedBox(
      width: 108,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              primary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.78),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketTag extends StatelessWidget {
  const _MarketTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF8E57FF),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF4D67);
}

String _formatPrice(double value) {
  return value == 0 ? '--' : value.toStringAsFixed(3);
}

String _formatMoney(StockPosition position, double value) {
  return '${_currencyPrefix(position.code)} ${value.abs().toStringAsFixed(2)}';
}

String _formatSignedMoney(StockPosition position, double value) {
  if (value == 0) return '${_currencyPrefix(position.code)} 0.00';
  final sign = value > 0 ? '+' : '-';
  return '$sign${_currencyPrefix(position.code)} ${value.abs().toStringAsFixed(2)}';
}

String _currencyPrefix(String code) {
  final upper = code.toUpperCase();
  if (upper.startsWith('US.')) return 'US\$';
  if (upper.startsWith('SH.') || upper.startsWith('SZ.')) return 'CN¥';
  return 'HK\$';
}

String _currencyCode(String code) {
  final upper = code.toUpperCase();
  if (upper.startsWith('US.')) return 'USD';
  if (upper.startsWith('SH.') || upper.startsWith('SZ.')) return 'CNY';
  return 'HKD';
}

String _marketTag(String code) {
  final upper = code.toUpperCase();
  if (upper.startsWith('US.')) return 'US';
  if (upper.startsWith('SH.')) return 'SH';
  if (upper.startsWith('SZ.')) return 'SZ';
  return 'HK';
}
