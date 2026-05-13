import 'package:flutter/material.dart';

import '../../models/stock_position.dart';
import '../../utils/market_data_formatters.dart';
import '../../utils/theme_helpers.dart';

class QuoteOverviewGrid extends StatelessWidget {
  const QuoteOverviewGrid({super.key, required this.position});

  final StockPosition position;

  @override
  Widget build(BuildContext context) {
    final previousClose = position.previousClose;
    final items = [
      _QuoteOverviewItem(
        label: '今开',
        value: formatQuotePrice(position.openPrice, previousClose),
        color: _quoteColor(position.openPrice, previousClose),
      ),
      _QuoteOverviewItem(
        label: '最高',
        value: formatQuotePrice(position.highPrice, previousClose),
        color: _quoteColor(position.highPrice, previousClose),
      ),
      _QuoteOverviewItem(
        label: '成交额',
        value: formatMarketAmount(position.turnover),
      ),
      _QuoteOverviewItem(
        label: '昨收',
        value: formatQuotePrice(position.previousClose, previousClose),
      ),
      _QuoteOverviewItem(
        label: '最低',
        value: formatQuotePrice(position.lowPrice, previousClose),
        color: _quoteColor(position.lowPrice, previousClose),
      ),
      _QuoteOverviewItem(
        label: '成交量',
        value: formatMarketVolume(position.volume),
      ),
      _QuoteOverviewItem(
        label: '市盈率',
        value: formatOptionalRatio(position.peRatio),
      ),
      _QuoteOverviewItem(label: '每手', value: formatLotSize(position.lotSize)),
      _QuoteOverviewItem(
        label: '换手率',
        value: formatOptionalPercent(position.turnoverRate),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 30,
        crossAxisSpacing: 6,
        mainAxisSpacing: 5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _QuoteOverviewItem extends StatelessWidget {
  const _QuoteOverviewItem({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color ?? primaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

Color? _quoteColor(double value, double previousClose) {
  if (value == 0 || previousClose == 0 || value == previousClose) return null;
  return value > previousClose
      ? const Color(0xFF12B886)
      : const Color(0xFFFF3B45);
}
