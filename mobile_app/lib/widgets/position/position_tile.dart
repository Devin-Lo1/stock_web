import 'package:flutter/material.dart';

import '../../models/stock_position.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';
import 'compact_metric.dart';
import 'extended_session_line.dart';

class PositionTile extends StatelessWidget {
  const PositionTile({super.key, required this.position, required this.onTap});

  final StockPosition position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _profitColor(position.profit);
    final dailyAccent = _profitColor(position.dailyProfit);

    return Material(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 3),
                    Text(
                      '${position.code} · ${formatNumberInput(position.quantity)}股',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 11,
                      ),
                    ),
                    if (position.hasExtendedSession) ...[
                      const SizedBox(height: 3),
                      ExtendedSessionLine(position: position),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 18,
                child: CompactMetric(
                  label: '实时',
                  value: position.shortPrice,
                  rate: position.change,
                  color: dailyAccent,
                ),
              ),
              Expanded(
                flex: 20,
                child: CompactMetric(
                  label: '当日',
                  value: formatCompactHkd(position.dailyProfit),
                  rate: formatPercent(position.dailyProfitRate),
                  color: dailyAccent,
                ),
              ),
              Expanded(
                flex: 20,
                child: CompactMetric(
                  label: '持有',
                  value: formatCompactHkd(position.profit),
                  rate: formatPercent(position.profitRate),
                  color: accent,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: mutedIconColor(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF3B45);
}
