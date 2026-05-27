import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../models/candle.dart';
import '../../utils/theme_helpers.dart';

class VolumeProfileChart extends StatelessWidget {
  const VolumeProfileChart({super.key, required this.result});

  final VolumeProfileBacktestResult result;

  @override
  Widget build(BuildContext context) {
    final profile = result.chartProfile;
    final candles = _visibleCandles(result);
    if (profile == null || profile.buckets.isEmpty || candles.length < 2) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: softCardColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No drawable volume profile data',
          style: TextStyle(color: secondaryTextColor(context)),
        ),
      );
    }

    return Container(
      height: 390,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: VolumeProfileChartPainter(
          candles: candles,
          profile: profile,
          signal: result.chartSignal,
          gridColor: borderColor(context).withValues(alpha: 0.45),
          textColor: secondaryTextColor(context),
          primaryTextColor: primaryTextColor(context),
          upColor: const Color(0xFF12B886),
          downColor: const Color(0xFFFF3B45),
          profileBaseColor: const Color(0xFF5CD6E8).withValues(alpha: 0.34),
          profileValueColor: const Color(0xFFFF7AA2).withValues(alpha: 0.62),
          pocColor: const Color(0xFFE6B450),
          valueAreaColor: const Color(0xFF55D7F7),
          targetColor: const Color(0xFF12B886),
          stopColor: const Color(0xFFFF3B45),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  List<Candle> _visibleCandles(VolumeProfileBacktestResult result) {
    final signalDate = result.chartSignal?.date;
    if (signalDate == null) return result.chartCandles;
    final sameDay = result.chartCandles.where((candle) {
      final time = candle.time;
      return time != null &&
          time.year == signalDate.year &&
          time.month == signalDate.month &&
          time.day == signalDate.day;
    }).toList();
    return sameDay.length >= 2 ? sameDay : result.chartCandles;
  }
}

class VolumeProfileChartPainter extends CustomPainter {
  const VolumeProfileChartPainter({
    required this.candles,
    required this.profile,
    required this.signal,
    required this.gridColor,
    required this.textColor,
    required this.primaryTextColor,
    required this.upColor,
    required this.downColor,
    required this.profileBaseColor,
    required this.profileValueColor,
    required this.pocColor,
    required this.valueAreaColor,
    required this.targetColor,
    required this.stopColor,
  });

  final List<Candle> candles;
  final VolumeProfileDayProfile profile;
  final VolumeProfileSignal? signal;
  final Color gridColor;
  final Color textColor;
  final Color primaryTextColor;
  final Color upColor;
  final Color downColor;
  final Color profileBaseColor;
  final Color profileValueColor;
  final Color pocColor;
  final Color valueAreaColor;
  final Color targetColor;
  final Color stopColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chartArea = Rect.fromLTWH(0, 32, size.width, size.height - 68);
    final profileArea = Rect.fromLTWH(
      chartArea.left,
      chartArea.top,
      chartArea.width * 0.30,
      chartArea.height,
    );
    final plotArea = Rect.fromLTWH(
      profileArea.right + 10,
      chartArea.top,
      chartArea.right - profileArea.right - 10,
      chartArea.height,
    );
    final range = _PriceRange.from(
      candles: candles,
      profile: profile,
      signal: signal,
    );

    _drawGrid(canvas, chartArea, plotArea);
    _drawProfile(canvas, profileArea, range);
    _drawProfileDivider(canvas, profileArea);
    _drawCandles(canvas, plotArea, range);
    _drawPriceLevels(canvas, chartArea, profileArea, plotArea, range);
    _drawHeader(canvas, size);
  }

  void _drawGrid(Canvas canvas, Rect chartArea, Rect plotArea) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartArea.top + chartArea.height * i / 4;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        paint,
      );
    }
    for (var i = 0; i <= 4; i++) {
      final x = plotArea.left + plotArea.width * i / 4;
      canvas.drawLine(
        Offset(x, plotArea.top),
        Offset(x, plotArea.bottom),
        paint,
      );
    }
  }

  void _drawProfile(Canvas canvas, Rect area, _PriceRange range) {
    final maxVolume = profile.buckets.fold<double>(
      0,
      (maxValue, bucket) => math.max(maxValue, bucket.volume),
    );
    if (maxVolume <= 0) return;

    for (final bucket in profile.buckets) {
      if (bucket.volume <= 0) continue;
      final yTop = _yFor(bucket.priceHigh, area, range);
      final yBottom = _yFor(bucket.priceLow, area, range);
      final height = math.max((yBottom - yTop).abs(), 1.0);
      final width = area.width * bucket.volume / maxVolume;
      final inValueArea =
          bucket.priceMid >= profile.val && bucket.priceMid <= profile.vah;
      final rect = Rect.fromLTWH(
        area.left,
        yTop,
        math.max(width, 1.0),
        height + 0.35,
      );
      canvas.drawRect(
        rect,
        Paint()..color = inValueArea ? profileValueColor : profileBaseColor,
      );
    }
  }

  void _drawProfileDivider(Canvas canvas, Rect area) {
    canvas.drawLine(
      Offset(area.right, area.top),
      Offset(area.right, area.bottom),
      Paint()
        ..color = gridColor.withValues(alpha: 0.9)
        ..strokeWidth = 1,
    );
  }

  void _drawCandles(Canvas canvas, Rect area, _PriceRange range) {
    final count = candles.length;
    final spacing = area.width / count;
    final candleWidth = (spacing * 0.62).clamp(1.1, 6.0);
    for (var index = 0; index < count; index++) {
      final candle = candles[index];
      final x = count == 1
          ? area.left + area.width / 2
          : area.left + area.width * index / (count - 1);
      final color = candle.close >= candle.open ? upColor : downColor;
      final highY = _yFor(candle.high, area, range);
      final lowY = _yFor(candle.low, area, range);
      final openY = _yFor(candle.open, area, range);
      final closeY = _yFor(candle.close, area, range);
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        Paint()
          ..color = color
          ..strokeWidth = math.max(1, candleWidth * 0.22),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - candleWidth / 2,
            math.min(openY, closeY),
            candleWidth,
            math.max((openY - closeY).abs(), 1.2),
          ),
          const Radius.circular(1),
        ),
        Paint()..color = color,
      );
    }
  }

  void _drawPriceLevels(
    Canvas canvas,
    Rect chartArea,
    Rect profileArea,
    Rect plotArea,
    _PriceRange range,
  ) {
    final levels = <_LevelLabel>[
      _LevelLabel('VAH', profile.vah, valueAreaColor),
      _LevelLabel('POC', profile.poc, pocColor),
      _LevelLabel('VAL', profile.val, valueAreaColor),
    ];
    final currentSignal = signal;
    if (currentSignal?.targetPrice != null &&
        currentSignal!.outcome != 'skipped') {
      levels.add(
        _LevelLabel('Target', currentSignal.targetPrice!, targetColor),
      );
    }
    if (currentSignal?.stopPrice != null &&
        currentSignal!.outcome != 'skipped') {
      levels.add(_LevelLabel('Stop', currentSignal.stopPrice!, stopColor));
    }

    final placedLabelYs = <double>[];
    for (final level in levels.where((level) => level.price > 0)) {
      final y = _yFor(level.price, chartArea, range);
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        Paint()
          ..color = level.color.withValues(alpha: 0.82)
          ..strokeWidth = level.name == 'POC' ? 1.4 : 1.1,
      );

      var labelY = y - 8;
      for (final usedY in placedLabelYs) {
        if ((labelY - usedY).abs() < 13) labelY = usedY + 13;
      }
      labelY = labelY.clamp(chartArea.top, chartArea.bottom - 12);
      placedLabelYs.add(labelY);
      _drawText(
        canvas,
        '${level.name} ${_formatPrice(level.price)}',
        Offset(plotArea.right - 2, labelY),
        color: level.color,
        fontSize: 10,
        align: TextAlign.right,
      );
    }

    final openPrice = currentSignal?.openPrice;
    if (openPrice != null && openPrice > 0) {
      final y = _yFor(openPrice, chartArea, range);
      final paint = Paint()
        ..color = primaryTextColor.withValues(alpha: 0.42)
        ..strokeWidth = 1;
      _drawDashedLine(
        canvas,
        Offset(plotArea.left, y),
        Offset(plotArea.right, y),
        paint,
      );
      _drawText(
        canvas,
        'Open ${_formatPrice(openPrice)}',
        Offset(plotArea.right - 2, y + 4),
        color: textColor,
        fontSize: 9,
        align: TextAlign.right,
      );
    }
  }

  void _drawHeader(Canvas canvas, Size size) {
    final signalDate = signal?.date;
    final profileDate = profile.date;
    _drawText(
      canvas,
      'Volume Profile',
      const Offset(0, 3),
      color: primaryTextColor,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    _drawText(
      canvas,
      'Profile ${_dateText(profileDate)} -> Signal ${_dateText(signalDate)}',
      Offset(size.width, 3),
      color: textColor,
      fontSize: 10,
      align: TextAlign.right,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashGap = 4.0;
    final totalWidth = end.dx - start.dx;
    var x = start.dx;
    while (x < end.dx) {
      final nextX = math.min(x + dashWidth, start.dx + totalWidth);
      canvas.drawLine(Offset(x, start.dy), Offset(nextX, end.dy), paint);
      x += dashWidth + dashGap;
    }
  }

  double _yFor(double price, Rect area, _PriceRange range) {
    return area.bottom - (price - range.min) / range.size * area.height;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: 220);
    final dx = align == TextAlign.right
        ? offset.dx - painter.width
        : align == TextAlign.center
        ? offset.dx - painter.width / 2
        : offset.dx;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  String _dateText(DateTime? value) {
    if (value == null) return '--';
    return '${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _formatPrice(double value) {
    if (value.abs() < 1) return value.toStringAsFixed(3);
    if (value.abs() < 100) return value.toStringAsFixed(2);
    return value.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant VolumeProfileChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.profile != profile ||
        oldDelegate.signal != signal;
  }
}

class _LevelLabel {
  const _LevelLabel(this.name, this.price, this.color);

  final String name;
  final double price;
  final Color color;
}

class _PriceRange {
  const _PriceRange({required this.min, required this.max});

  final double min;
  final double max;

  double get size => math.max(max - min, 0.0001);

  factory _PriceRange.from({
    required List<Candle> candles,
    required VolumeProfileDayProfile profile,
    required VolumeProfileSignal? signal,
  }) {
    final values = <double>[
      for (final candle in candles) ...[candle.low, candle.high],
      profile.val,
      profile.vah,
      profile.poc,
      if (signal?.outcome != 'skipped' && signal?.targetPrice != null)
        signal!.targetPrice!,
      if (signal?.outcome != 'skipped' && signal?.stopPrice != null)
        signal!.stopPrice!,
      if (signal?.openPrice != null) signal!.openPrice!,
    ].where((value) => value > 0).toList();
    if (values.isEmpty) return const _PriceRange(min: 0, max: 1);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final padding = math.max((maxValue - minValue) * 0.10, maxValue * 0.001);
    return _PriceRange(min: minValue - padding, max: maxValue + padding);
  }
}
