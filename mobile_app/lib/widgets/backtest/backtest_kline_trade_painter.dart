import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../models/candle.dart';
import 'backtest_chart_values.dart';

class BacktestKlineTradePainter extends CustomPainter {
  const BacktestKlineTradePainter({
    required this.candles,
    required this.shortMa,
    required this.longMa,
    required this.shortMaLabel,
    required this.longMaLabel,
    required this.trades,
    required this.selectedIndex,
    required this.gridColor,
    required this.axisColor,
    required this.panelColor,
    required this.textColor,
    required this.primaryTextColor,
    required this.upColor,
    required this.downColor,
    required this.shortMaColor,
    required this.longMaColor,
    required this.buyColor,
    required this.sellColor,
  });

  final List<Candle> candles;
  final List<double?> shortMa;
  final List<double?> longMa;
  final String shortMaLabel;
  final String longMaLabel;
  final List<BacktestTrade> trades;
  final int? selectedIndex;
  final Color gridColor;
  final Color axisColor;
  final Color panelColor;
  final Color textColor;
  final Color primaryTextColor;
  final Color upColor;
  final Color downColor;
  final Color shortMaColor;
  final Color longMaColor;
  final Color buyColor;
  final Color sellColor;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(0, 62, size.width, size.height - 88);
    _drawGrid(canvas, area);

    if (candles.length < 2) {
      _drawEmpty(canvas, size);
      return;
    }

    final range = BacktestPriceRange.fromCandles(
      candles: candles,
      maValues: [...shortMa.whereType<double>(), ...longMa.whereType<double>()],
      trades: visibleBacktestTrades(candles, trades),
    );

    _drawMaLine(canvas, area, longMa, range, longMaColor);
    _drawMaLine(canvas, area, shortMa, range, shortMaColor);
    _drawCandles(canvas, area, range);
    _drawTradeMarkers(canvas, area, range);
    _drawSelection(canvas, area, range);
    _drawLabels(canvas, area, range);
    _drawMaLegend(canvas);
    _drawInfoPanel(canvas, size, selectedIndex);
  }

  void _drawCandles(Canvas canvas, Rect area, BacktestPriceRange range) {
    final count = candles.length;
    final spacing = area.width / count;
    final candleWidth = (spacing * 0.58).clamp(2.0, 9.0);
    for (var index = 0; index < count; index++) {
      final candle = candles[index];
      final x = _xFor(index, count, area);
      final openY = _yFor(candle.open, area, range);
      final closeY = _yFor(candle.close, area, range);
      final highY = _yFor(candle.high, area, range);
      final lowY = _yFor(candle.low, area, range);
      final color = candle.close >= candle.open ? upColor : downColor;
      final paint = Paint()
        ..color = color
        ..strokeWidth = math.max(1, candleWidth * 0.22);
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), paint);

      final bodyTop = math.min(openY, closeY);
      final bodyHeight = math.max((openY - closeY).abs(), 1.5);
      final rect = Rect.fromLTWH(
        x - candleWidth / 2,
        bodyTop,
        candleWidth,
        bodyHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.2)),
        Paint()..color = color,
      );
    }
  }

  void _drawTradeMarkers(Canvas canvas, Rect area, BacktestPriceRange range) {
    for (final trade in trades) {
      final tradeTime = trade.time;
      if (tradeTime == null) continue;
      final index = _nearestCandleIndex(candles, tradeTime);
      if (index == -1) continue;

      final candle = candles[index];
      final x = _xFor(index, candles.length, area);
      final isBuy = trade.side == 'buy';
      final anchorPrice = isBuy
          ? math.min(candle.low, trade.price)
          : math.max(candle.high, trade.price);
      final anchorY = _yFor(anchorPrice, area, range);
      final markerY = isBuy
          ? math.min(area.bottom - 12, anchorY + 22)
          : math.max(area.top + 12, anchorY - 22);
      final color = isBuy ? buyColor : sellColor;

      canvas.drawLine(
        Offset(x, anchorY),
        Offset(x, markerY),
        Paint()
          ..color = color.withValues(alpha: 0.72)
          ..strokeWidth = 1.1,
      );
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, markerY), width: 24, height: 20),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.2));
      canvas.drawRRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      _drawText(
        canvas,
        isBuy ? 'B' : 'S',
        Offset(x, markerY - 7),
        align: TextAlign.center,
        color: color,
        fontSize: 12,
      );
    }
  }

  void _drawSelection(Canvas canvas, Rect area, BacktestPriceRange range) {
    final index = selectedIndex;
    if (index == null || index < 0 || index >= candles.length) return;
    final candle = candles[index];
    final x = _xFor(index, candles.length, area);
    canvas.drawLine(
      Offset(x, area.top),
      Offset(x, area.bottom),
      Paint()
        ..color = axisColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(x, _yFor(candle.close, area, range)),
      4,
      Paint()..color = candle.close >= candle.open ? upColor : downColor,
    );
  }

  void _drawMaLine(
    Canvas canvas,
    Rect area,
    List<double?> values,
    BacktestPriceRange range,
    Color color,
  ) {
    final path = Path();
    var started = false;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        started = false;
        continue;
      }
      final point = Offset(
        _xFor(index, candles.length, area),
        _yFor(value, area, range),
      );
      if (!started) {
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2,
    );
  }

  int _nearestCandleIndex(List<Candle> values, DateTime tradeTime) {
    var bestIndex = -1;
    var bestDistance = const Duration(days: 100000);
    for (var index = 0; index < values.length; index++) {
      final time = values[index].time;
      if (time == null) continue;
      final distance = time.difference(tradeTime).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestDistance.inDays <= 7 ? bestIndex : -1;
  }

  double _xFor(int index, int count, Rect area) {
    if (count <= 1) return area.left;
    return area.left + area.width * index / (count - 1);
  }

  double _yFor(double value, Rect area, BacktestPriceRange range) {
    return area.bottom - (value - range.min) / range.size * area.height;
  }

  void _drawGrid(Canvas canvas, Rect area) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paint);
    }
    for (var i = 0; i <= 3; i++) {
      final x = area.left + area.width * i / 3;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), paint);
    }
    canvas.drawLine(
      Offset(area.left, area.bottom),
      Offset(area.right, area.bottom),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1.2,
    );
  }

  void _drawLabels(Canvas canvas, Rect area, BacktestPriceRange range) {
    _drawText(
      canvas,
      range.max.toStringAsFixed(2),
      Offset(area.left + 2, area.top - 16),
    );
    _drawText(
      canvas,
      range.min.toStringAsFixed(2),
      Offset(area.left + 2, area.bottom - 18),
    );
    _drawText(
      canvas,
      formatBacktestAxisDate(candles.first.time),
      Offset(area.left + 2, area.bottom + 8),
    );
    _drawText(
      canvas,
      formatBacktestAxisDate(candles.last.time),
      Offset(area.right - 2, area.bottom + 8),
      align: TextAlign.right,
    );
  }

  void _drawInfoPanel(Canvas canvas, Size size, int? index) {
    final selected = index == null || index < 0 || index >= candles.length
        ? candles.last
        : candles[index];
    final selectedTrades = _tradesForCandle(selected);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, 48),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = panelColor);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = gridColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final change = selected.close - selected.open;
    final changeRate = selected.open.abs() < 0.0001
        ? 0.0
        : change / selected.open * 100;
    final changeColor = change >= 0 ? upColor : downColor;
    final tradeText = selectedTrades.isEmpty
        ? null
        : selectedTrades
              .map((trade) => trade.side == 'buy' ? 'B' : 'S')
              .join('/');
    final innerWidth = size.width - 16;
    final columnWidths = <double>[
      innerWidth * 0.33,
      innerWidth * 0.21,
      innerWidth * 0.21,
      innerWidth * 0.25,
    ];
    final columnXs = <double>[8];
    for (var index = 1; index < columnWidths.length; index++) {
      columnXs.add(columnXs[index - 1] + columnWidths[index - 1]);
    }

    _drawMetricText(
      canvas,
      label: '日',
      value: formatBacktestFullDate(selected.time),
      offset: Offset(columnXs[0], 6),
      maxWidth: columnWidths[0] - 6,
      valueColor: primaryTextColor,
    );
    _drawMetricText(
      canvas,
      label: '收',
      value: selected.close.toStringAsFixed(2),
      offset: Offset(columnXs[1], 6),
      maxWidth: columnWidths[1] - 6,
      valueColor: changeColor,
    );
    _drawMetricText(
      canvas,
      label: '高',
      value: selected.high.toStringAsFixed(2),
      offset: Offset(columnXs[2], 6),
      maxWidth: columnWidths[2] - 6,
      valueColor: upColor,
    );
    _drawMetricText(
      canvas,
      label: '幅',
      value: '${changeRate.toStringAsFixed(2)}%',
      offset: Offset(columnXs[3], 6),
      maxWidth: columnWidths[3] - 6,
      valueColor: changeColor,
    );
    _drawMetricText(
      canvas,
      label: '量',
      value: formatBacktestCompactNumber(selected.volume),
      offset: Offset(columnXs[0], 27),
      maxWidth: columnWidths[0] - 6,
      valueColor: primaryTextColor,
    );
    _drawMetricText(
      canvas,
      label: '开',
      value: selected.open.toStringAsFixed(2),
      offset: Offset(columnXs[1], 27),
      maxWidth: columnWidths[1] - 6,
      valueColor: selected.close >= selected.open ? upColor : downColor,
    );
    _drawMetricText(
      canvas,
      label: '低',
      value: selected.low.toStringAsFixed(2),
      offset: Offset(columnXs[2], 27),
      maxWidth: columnWidths[2] - 6,
      valueColor: downColor,
    );
    _drawMetricText(
      canvas,
      label: tradeText == null ? '额' : '信号',
      value: tradeText ?? formatBacktestCompactNumber(selected.turnover),
      offset: Offset(columnXs[3], 27),
      maxWidth: columnWidths[3] - 6,
      valueColor: tradeText == null ? primaryTextColor : changeColor,
    );
  }

  void _drawMaLegend(Canvas canvas) {
    final selected = selectedIndex == null || selectedIndex! >= candles.length
        ? candles.length - 1
        : selectedIndex!;
    final shortValue = selected < 0 || selected >= shortMa.length
        ? null
        : shortMa[selected];
    final longValue = selected < 0 || selected >= longMa.length
        ? null
        : longMa[selected];
    final painter = TextPainter(
      text: TextSpan(
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        children: [
          TextSpan(
            text: '$shortMaLabel:${_maText(shortValue)}',
            style: TextStyle(color: shortMaColor),
          ),
          const TextSpan(text: '  '),
          TextSpan(
            text: '$longMaLabel:${_maText(longValue)}',
            style: TextStyle(color: longMaColor),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 180);
    painter.paint(canvas, const Offset(4, 50));
  }

  String _maText(double? value) {
    if (value == null) return '--';
    return value.toStringAsFixed(2);
  }

  List<BacktestTrade> _tradesForCandle(Candle candle) {
    final time = candle.time;
    if (time == null) return const [];
    return trades.where((trade) {
      final tradeTime = trade.time;
      if (tradeTime == null) return false;
      return backtestDateKey(tradeTime) == backtestDateKey(time);
    }).toList();
  }

  void _drawEmpty(Canvas canvas, Size size) {
    _drawText(
      canvas,
      '\u6682\u65e0K\u7ebf\u4e70\u5356\u70b9',
      Offset(size.width / 2, size.height / 2 - 8),
      align: TextAlign.center,
      fontSize: 13,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    TextAlign align = TextAlign.left,
    Color? color,
    double fontSize = 11,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    final dx = switch (align) {
      TextAlign.center => offset.dx - painter.width / 2,
      TextAlign.right => offset.dx - painter.width,
      _ => offset.dx,
    };
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  void _drawMetricText(
    Canvas canvas, {
    required String label,
    required String value,
    required Offset offset,
    required double maxWidth,
    required Color valueColor,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      maxLines: 1,
      ellipsis: '',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant BacktestKlineTradePainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.shortMa != shortMa ||
        oldDelegate.longMa != longMa ||
        oldDelegate.shortMaLabel != shortMaLabel ||
        oldDelegate.longMaLabel != longMaLabel ||
        oldDelegate.trades != trades ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.panelColor != panelColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.primaryTextColor != primaryTextColor ||
        oldDelegate.upColor != upColor ||
        oldDelegate.downColor != downColor ||
        oldDelegate.shortMaColor != shortMaColor ||
        oldDelegate.longMaColor != longMaColor ||
        oldDelegate.buyColor != buyColor ||
        oldDelegate.sellColor != sellColor;
  }
}
