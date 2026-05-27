import 'package:flutter/material.dart';

import '../../models/stock_position.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';
import 'extended_session_line.dart';

const double _fixedNameColumnWidth = 148;

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
                width: _fixedNameColumnWidth,
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
                    width: 520,
                    child: Column(
                      children: [
                        const _MetricHeaderRow(),
                        ...positions.map(
                          (position) => _MetricRow(
                            position: position,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [_PillButton(label: '持仓($count)', isSelected: true)],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '名称',
        style: TextStyle(
          color: secondaryTextColor(context),
          fontSize: 12,
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
      width: 104,
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
                fontSize: 12,
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
        height: _rowHeight(position),
        padding: const EdgeInsets.fromLTRB(8, 10, 6, 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor(context))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FitText(
              position.name,
              color: primaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                _MarketTag(label: _marketTag(position.code)),
                const SizedBox(width: 4),
                Expanded(
                  child: _FitText(
                    '${position.code} ${_currencyCode(position.code)}',
                    color: secondaryTextColor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ],
            ),
            if (position.hasExtendedSession) ...[
              const SizedBox(height: 4),
              ExtendedSessionLine(
                position: position,
                fontSize: 9.2,
                fontWeight: FontWeight.w800,
                fitToWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.position, required this.onTap});

  final StockPosition position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dailyProfit = position.backendDayProfit;
    final dailyProfitRate = position.backendDayProfitRate;
    final holdingProfit = position.backendHoldingProfit;
    final holdingProfitRate = position.backendHoldingProfitRate;
    final marketValue = position.backendMarketValue;
    final weight = position.backendPositionWeight;
    final dailyColor = _profitColor(dailyProfit ?? 0);
    final profitColor = _profitColor(holdingProfit ?? 0);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: _rowHeight(position),
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
              primary: _formatSignedMoneyOrDash(position, dailyProfit),
              secondary: _formatPercentOrDash(dailyProfitRate),
              color: dailyColor,
            ),
            _MetricCell(
              primary: _formatSignedMoneyOrDash(position, holdingProfit),
              secondary: _formatPercentOrDash(holdingProfitRate),
              color: profitColor,
            ),
            _MetricCell(
              primary: _formatMoneyOrDash(position, marketValue),
              secondary: _formatPercentOrDash(weight),
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
      width: 104,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _FitText(
              primary,
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            const SizedBox(height: 4),
            _FitText(
              secondary,
              color: textColor.withValues(alpha: 0.78),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
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

class _FitText extends StatelessWidget {
  const _FitText(
    this.text, {
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.alignment = Alignment.centerRight,
  });

  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}

double _rowHeight(StockPosition position) {
  return position.hasExtendedSession ? 96 : 82;
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF4D67);
}

String _formatPrice(double value) {
  return value == 0 ? '--' : value.toStringAsFixed(2);
}

String _formatMoney(StockPosition position, double value) {
  return '${_currencyPrefix(position.code)}${value.abs().toStringAsFixed(2)}';
}

String _formatSignedMoney(StockPosition position, double value) {
  if (value == 0) return '${_currencyPrefix(position.code)}0.00';
  final sign = value > 0 ? '+' : '-';
  return '$sign${_currencyPrefix(position.code)}${value.abs().toStringAsFixed(2)}';
}

String _formatMoneyOrDash(StockPosition position, double? value) {
  if (value == null) return '--';
  return _formatMoney(position, value);
}

String _formatSignedMoneyOrDash(StockPosition position, double? value) {
  if (value == null) return '--';
  return _formatSignedMoney(position, value);
}

String _formatPercentOrDash(double? value) {
  if (value == null) return '--';
  return formatPercent(value);
}

String _currencyPrefix(String code) {
  final upper = code.toUpperCase();
  if (upper.startsWith('US.')) return 'US\$';
  if (upper.startsWith('SH.') ||
      upper.startsWith('SZ.') ||
      upper.startsWith('CN.')) {
    return 'CN¥';
  }
  return 'HK\$';
}

String _currencyCode(String code) {
  final upper = code.toUpperCase();
  if (upper.startsWith('US.')) return 'USD';
  if (upper.startsWith('SH.') ||
      upper.startsWith('SZ.') ||
      upper.startsWith('CN.')) {
    return 'CNY';
  }
  return 'HKD';
}

String _marketTag(String code) {
  final upper = code.toUpperCase();
  if (upper.startsWith('US.')) return 'US';
  if (upper.startsWith('SH.')) return 'SH';
  if (upper.startsWith('SZ.')) return 'SZ';
  if (upper.startsWith('CN.')) return 'CN';
  return 'HK';
}
