import 'package:flutter/material.dart';

import '../../utils/theme_helpers.dart';

enum KLineChartPeriod {
  intraday('分时', '1m', 240),
  day('日K', 'day', 360),
  week('周K', 'week', 240),
  month('月K', 'month', 180);

  const KLineChartPeriod(this.label, this.apiPeriod, this.limit);

  final String label;
  final String apiPeriod;
  final int limit;
}

class KLineChartTabs extends StatelessWidget {
  const KLineChartTabs({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final KLineChartPeriod selectedPeriod;
  final ValueChanged<KLineChartPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final period in KLineChartPeriod.values)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onPeriodChanged(period),
              child: Column(
                children: [
                  Text(
                    period.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: period == selectedPeriod
                          ? primaryTextColor(context)
                          : secondaryTextColor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 22,
                    height: 3,
                    decoration: BoxDecoration(
                      color: period == selectedPeriod
                          ? appAccentColor(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
