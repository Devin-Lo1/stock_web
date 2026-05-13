import 'package:flutter/material.dart';

import '../../models/candle.dart';
import '../../utils/theme_helpers.dart';
import 'kline_chart_values.dart';

class KLineMaStrip extends StatelessWidget {
  const KLineMaStrip({super.key, required this.maValues});

  final Map<int, double?> maValues;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _MaLabel(
            text: 'MA5:${formatKlineMa(maValues[5])}',
            color: const Color(0xFFE0A84C),
          ),
          _MaLabel(
            text: 'MA10:${formatKlineMa(maValues[10])}',
            color: const Color(0xFF5BA7D7),
          ),
          _MaLabel(
            text: 'MA20:${formatKlineMa(maValues[20])}',
            color: const Color(0xFFC65BB8),
          ),
          _MaLabel(
            text: 'MA60:${formatKlineMa(maValues[60])}',
            color: const Color(0xFF5CC9C7),
          ),
        ],
      ),
    );
  }
}

class _MaLabel extends StatelessWidget {
  const _MaLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class SelectedCandleInfoPanel extends StatelessWidget {
  const SelectedCandleInfoPanel({
    super.key,
    required this.candle,
    required this.previousClose,
  });

  final Candle candle;
  final double previousClose;

  @override
  Widget build(BuildContext context) {
    final change = candle.close - previousClose;
    final changeRate = previousClose == 0 ? 0 : change / previousClose * 100;
    final changeColor = klineProfitColor(change);
    final labelStyle = TextStyle(
      color: secondaryTextColor(context),
      fontSize: 10,
      fontWeight: FontWeight.w800,
      height: 1.08,
    );
    final valueStyle = TextStyle(
      color: primaryTextColor(context),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      height: 1.08,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: pageBackgroundColor(context).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor(context).withValues(alpha: 0.7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = (constraints.maxWidth - 12) / 4;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _InfoCell(
                    width: cellWidth,
                    label: '日',
                    value: formatKlineDate(candle.time),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '收',
                    value: formatKlinePrice(candle.close),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(color: changeColor),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '高',
                    value: formatKlinePrice(candle.high),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: klineProfitColor(candle.high - previousClose),
                    ),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '幅',
                    value:
                        '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(2)}%',
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(color: changeColor),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _InfoCell(
                    width: cellWidth,
                    label: '量',
                    value: formatKlineLargeNumber(candle.volume),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '开',
                    value: formatKlinePrice(candle.open),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: klineProfitColor(candle.open - previousClose),
                    ),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '低',
                    value: formatKlinePrice(candle.low),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: klineProfitColor(candle.low - previousClose),
                    ),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '额',
                    value: formatKlineLargeNumber(candle.turnover),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(color: changeColor),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.width,
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final double width;
  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            if (label.isNotEmpty) TextSpan(text: '$label ', style: labelStyle),
            TextSpan(text: value, style: valueStyle),
          ],
        ),
      ),
    );
  }
}
