import 'package:flutter/material.dart';

import '../models/backtest_models.dart';
import '../models/candle.dart';
import '../utils/theme_helpers.dart';
import '../widgets/quant/quant_result_panel.dart';

class BacktestResultScreen extends StatelessWidget {
  const BacktestResultScreen({
    super.key,
    required this.result,
    required this.candles,
    required this.isHistoricalResult,
  });

  final BacktestResult result;
  final List<Candle> candles;
  final bool isHistoricalResult;

  @override
  Widget build(BuildContext context) {
    final title = isHistoricalResult ? '历史回测详情' : '回测结果';
    final subtitle = result.run.name.isEmpty
        ? result.run.stockCode
        : result.run.name;

    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: pageBackgroundColor(context),
                border: Border(bottom: BorderSide(color: borderColor(context))),
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: primaryTextColor(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryTextColor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  QuantResultPanel(
                    result: result,
                    candles: candles,
                    isHistoricalResult: isHistoricalResult,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
