import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/candle.dart';
import 'kline_chart_values.dart';

class InteractiveKLinePainter extends CustomPainter {
  const InteractiveKLinePainter({
    required this.candles,
    required this.allCandles,
    required this.startIndex,
    required this.selectedIndex,
    required this.gridColor,
    required this.extremeLabelBackgroundColor,
    required this.extremeLabelBorderColor,
    required this.upColor,
    required this.downColor,
    required this.ma5Color,
    required this.ma10Color,
    required this.ma20Color,
    required this.ma60Color,
    required this.crosshairColor,
    required this.axisLabelColor,
  });

  final List<Candle> candles;
  final List<Candle> allCandles;
  final int startIndex;
  final int? selectedIndex;
  final Color gridColor;
  final Color extremeLabelBackgroundColor;
  final Color extremeLabelBorderColor;
  final Color upColor;
  final Color downColor;
  final Color ma5Color;
  final Color ma10Color;
  final Color ma20Color;
  final Color ma60Color;
  final Color crosshairColor;
  final Color axisLabelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = math.max(40.0, size.height - 24);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), gridPaint);
    }
    if (candles.isEmpty) return;

    final scaleValues = <double>[
      for (final candle in candles) ...[candle.high, candle.low],
      ..._visibleMovingAverages(5),
      ..._visibleMovingAverages(10),
      ..._visibleMovingAverages(20),
      ..._visibleMovingAverages(60),
    ];
    final rawMaxPrice = scaleValues.reduce(math.max);
    final rawMinPrice = scaleValues.reduce(math.min);
    final rawRange = math.max(rawMaxPrice - rawMinPrice, 0.01);
    final maxPrice = rawMaxPrice + rawRange * 0.06;
    final minPrice = rawMinPrice - rawRange * 0.06;
    final priceRange = math.max(maxPrice - minPrice, 0.01);
    final slotWidth = size.width / candles.length;
    final bodyWidth = math.max(1.8, math.min(5.2, slotWidth * 0.42));

    double yFor(double price) {
      return chartHeight - (price - minPrice) / priceRange * chartHeight;
    }

    for (var index = 0; index < candles.length; index++) {
      final candle = candles[index];
      final centerX = slotWidth * index + slotWidth / 2;
      final openY = yFor(candle.open);
      final closeY = yFor(candle.close);
      final highY = yFor(candle.high);
      final lowY = yFor(candle.low);
      final isUp = candle.close >= candle.open;
      final color = isUp ? upColor : downColor;

      canvas.drawLine(
        Offset(centerX, highY),
        Offset(centerX, lowY),
        Paint()
          ..color = color.withValues(alpha: 0.82)
          ..strokeWidth = 0.75,
      );
      final rect = Rect.fromLTWH(
        centerX - bodyWidth / 2,
        math.min(openY, closeY),
        bodyWidth,
        math.max((openY - closeY).abs(), 1.0),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
    }

    _drawMa(canvas, size, 5, ma5Color, yFor, slotWidth);
    _drawMa(
      canvas,
      Size(size.width, chartHeight),
      10,
      ma10Color,
      yFor,
      slotWidth,
    );
    _drawMa(
      canvas,
      Size(size.width, chartHeight),
      20,
      ma20Color,
      yFor,
      slotWidth,
    );
    _drawMa(
      canvas,
      Size(size.width, chartHeight),
      60,
      ma60Color,
      yFor,
      slotWidth,
    );
    _drawRangeExtremes(canvas, Size(size.width, chartHeight), yFor, slotWidth);
    _drawSelectedCrosshair(
      canvas,
      Size(size.width, chartHeight),
      yFor,
      slotWidth,
    );
    _drawDateAxis(canvas, size, chartHeight, slotWidth);
  }

  void _drawMa(
    Canvas canvas,
    Size size,
    int period,
    Color color,
    double Function(double price) yFor,
    double slotWidth,
  ) {
    final path = Path();
    var hasPoint = false;
    for (var index = 0; index < candles.length; index++) {
      final globalIndex = startIndex + index;
      final average = klineMovingAverageAt(allCandles, globalIndex, period);
      if (average == null) continue;
      final point = Offset(slotWidth * index + slotWidth / 2, yFor(average));
      if (!hasPoint) {
        path.moveTo(point.dx, point.dy);
        hasPoint = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (!hasPoint) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  Iterable<double> _visibleMovingAverages(int period) sync* {
    for (var index = 0; index < candles.length; index++) {
      final average = klineMovingAverageAt(
        allCandles,
        startIndex + index,
        period,
      );
      if (average != null) yield average;
    }
  }

  void _drawSelectedCrosshair(
    Canvas canvas,
    Size size,
    double Function(double price) yFor,
    double slotWidth,
  ) {
    final index = selectedIndex;
    if (index == null || index < 0 || index >= candles.length) return;

    final candle = candles[index];
    final centerX = slotWidth * index + slotWidth / 2;
    final closeY = yFor(candle.close);
    final paint = Paint()
      ..color = crosshairColor
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), paint);
    canvas.drawLine(Offset(0, closeY), Offset(size.width, closeY), paint);

    final markerPaint = Paint()
      ..color = candle.close >= candle.open ? upColor : downColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, closeY), 3.2, markerPaint);
  }

  void _drawRangeExtremes(
    Canvas canvas,
    Size size,
    double Function(double price) yFor,
    double slotWidth,
  ) {
    if (candles.isEmpty) return;

    var highIndex = 0;
    var lowIndex = 0;
    for (var index = 1; index < candles.length; index++) {
      if (candles[index].high > candles[highIndex].high) highIndex = index;
      if (candles[index].low < candles[lowIndex].low) lowIndex = index;
    }

    _drawExtremeLabel(
      canvas,
      size,
      text: formatKlinePrice(candles[highIndex].high),
      point: Offset(
        slotWidth * highIndex + slotWidth / 2,
        yFor(candles[highIndex].high),
      ),
      isHigh: true,
    );
    _drawExtremeLabel(
      canvas,
      size,
      text: formatKlinePrice(candles[lowIndex].low),
      point: Offset(
        slotWidth * lowIndex + slotWidth / 2,
        yFor(candles[lowIndex].low),
      ),
      isHigh: false,
    );
  }

  void _drawExtremeLabel(
    Canvas canvas,
    Size size, {
    required String text,
    required Offset point,
    required bool isHigh,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: axisLabelColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    const horizontalPadding = 4.0;
    const verticalPadding = 2.0;
    const gap = 4.0;
    final labelWidth = textPainter.width + horizontalPadding * 2;
    final labelHeight = textPainter.height + verticalPadding * 2;
    final preferRight = point.dx < size.width * 0.62;
    var left = preferRight ? point.dx + gap : point.dx - labelWidth - gap;
    left = left.clamp(0.0, math.max(0.0, size.width - labelWidth)).toDouble();
    var top = isHigh ? point.dy - labelHeight - gap : point.dy + gap;
    top = top.clamp(0.0, math.max(0.0, size.height - labelHeight)).toDouble();
    final rect = Rect.fromLTWH(left, top, labelWidth, labelHeight);

    final borderPaint = Paint()
      ..color = extremeLabelBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    final backgroundPaint = Paint()
      ..color = extremeLabelBackgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, backgroundPaint);
    canvas.drawRect(rect, borderPaint);

    final connectorStart = preferRight
        ? Offset(rect.left, rect.center.dy)
        : Offset(rect.right, rect.center.dy);
    canvas.drawLine(point, connectorStart, borderPaint);
    textPainter.paint(
      canvas,
      Offset(left + horizontalPadding, top + verticalPadding),
    );
  }

  void _drawDateAxis(
    Canvas canvas,
    Size size,
    double chartHeight,
    double slotWidth,
  ) {
    final axisPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );

    final indexes = <int>{0, candles.length ~/ 2, candles.length - 1};
    for (final index in indexes) {
      if (index < 0 || index >= candles.length) continue;
      final centerX = slotWidth * index + slotWidth / 2;
      canvas.drawLine(
        Offset(centerX, chartHeight),
        Offset(centerX, chartHeight + 5),
        axisPaint,
      );
      final label = formatKlineAxisDate(candles[index].time);
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: axisLabelColor.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final dx = (centerX - painter.width / 2)
          .clamp(0.0, math.max(0.0, size.width - painter.width))
          .toDouble();
      painter.paint(canvas, Offset(dx, chartHeight + 7));
    }
  }

  @override
  bool shouldRepaint(covariant InteractiveKLinePainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.allCandles != allCandles ||
        oldDelegate.startIndex != startIndex ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.extremeLabelBackgroundColor !=
            extremeLabelBackgroundColor ||
        oldDelegate.extremeLabelBorderColor != extremeLabelBorderColor ||
        oldDelegate.axisLabelColor != axisLabelColor;
  }
}
