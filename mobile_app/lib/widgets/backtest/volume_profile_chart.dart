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
    if (profile == null ||
        profile.buckets.isEmpty ||
        result.chartCandles.length < 2) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: softCardColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '暂无可绘制的价值区图',
          style: TextStyle(color: secondaryTextColor(context)),
        ),
      );
    }

    return Container(
      height: 360,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: VolumeProfileChartPainter(
          candles: result.chartCandles,
          profile: profile,
          signal: result.chartSignal,
          gridColor: borderColor(context).withValues(alpha: 0.45),
          textColor: secondaryTextColor(context),
          primaryTextColor: primaryTextColor(context),
          upColor: const Color(0xFF12B886),
          downColor: const Color(0xFFFF3B45),
          profileColor: appAccentColor(context).withValues(alpha: 0.58),
          pocColor: const Color(0xFFE6B450),
          valueAreaColor: appAccentColor(context),
          targetColor: const Color(0xFF12B886),
          stopColor: const Color(0xFFFF3B45),
        ),
        child: const SizedBox.expand(),
      ),
    );
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
    required this.profileColor,
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
  final Color profileColor;
  final Color pocColor;
  final Color valueAreaColor;
  final Color targetColor;
  final Color stopColor;

  @override
  void paint(Canvas canvas, Size size) {
    final plotArea = Rect.fromLTWH(0, 28, size.width * 0.70, size.height - 58);
    final profileArea = Rect.fromLTWH(
      plotArea.right + 8,
      plotArea.top,
      size.width - plotArea.right - 8,
      plotArea.height,
    );
    final range = _PriceRange.from(
      candles: candles,
      profile: profile,
      signal: signal,
    );

    _drawGrid(canvas, plotArea);
    _drawCandles(canvas, plotArea, range);
    _drawProfile(canvas, profileArea, range);
    _drawLevel(
      canvas,
      plotArea,
      profileArea,
      range,
      profile.vah,
      'VAH',
      valueAreaColor,
    );
    _drawLevel(
      canvas,
      plotArea,
      profileArea,
      range,
      profile.poc,
      'POC',
      pocColor,
    );
    _drawLevel(
      canvas,
      plotArea,
      profileArea,
      range,
      profile.val,
      'VAL',
      valueAreaColor,
    );
    _drawSignalLevels(canvas, plotArea, profileArea, range);
    _drawHeader(canvas, size);
  }

  void _drawGrid(Canvas canvas, Rect area) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = area.top + area.height * i / 4;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paint);
    }
    for (var i = 0; i <= 3; i++) {
      final x = area.left + area.width * i / 3;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), paint);
    }
  }

  void _drawCandles(Canvas canvas, Rect area, _PriceRange range) {
    final count = candles.length;
    final spacing = area.width / count;
    final candleWidth = (spacing * 0.55).clamp(1.4, 7.0);
    for (var index = 0; index < count; index++) {
      final candle = candles[index];
      final x = count == 1
          ? area.left
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
          ..strokeWidth = math.max(1, candleWidth * 0.2),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - candleWidth / 2,
            math.min(openY, closeY),
            candleWidth,
            math.max((openY - closeY).abs(), 1.4),
          ),
          const Radius.circular(1),
        ),
        Paint()..color = color,
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
      final rect = Rect.fromLTWH(area.left, yTop, width, height);
      canvas.drawRect(rect, Paint()..color = profileColor);
    }
  }

  void _drawLevel(
    Canvas canvas,
    Rect plotArea,
    Rect profileArea,
    _PriceRange range,
    double price,
    String label,
    Color color,
  ) {
    if (price <= 0) return;
    final y = _yFor(price, plotArea, range);
    canvas.drawLine(
      Offset(plotArea.left, y),
      Offset(profileArea.right, y),
      Paint()
        ..color = color.withValues(alpha: 0.78)
        ..strokeWidth = 1.2,
    );
    _drawText(
      canvas,
      '$label ${price.toStringAsFixed(2)}',
      Offset(profileArea.left + 2, y - 15),
      color: color,
      fontSize: 10,
    );
  }

  void _drawSignalLevels(
    Canvas canvas,
    Rect plotArea,
    Rect profileArea,
    _PriceRange range,
  ) {
    final currentSignal = signal;
    if (currentSignal == null) return;
    final target = currentSignal.targetPrice;
    final stop = currentSignal.stopPrice;
    if (target != null) {
      _drawLevel(
        canvas,
        plotArea,
        profileArea,
        range,
        target,
        'Target',
        targetColor,
      );
    }
    if (stop != null) {
      _drawLevel(canvas, plotArea, profileArea, range, stop, 'Stop', stopColor);
    }
  }

  void _drawHeader(Canvas canvas, Size size) {
    final signalDate = signal?.date;
    final profileDate = profile.date;
    _drawText(
      canvas,
      'K line + volume profile',
      const Offset(0, 2),
      color: primaryTextColor,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    _drawText(
      canvas,
      '${_dateText(profileDate)} -> ${_dateText(signalDate)}',
      Offset(size.width, 2),
      align: TextAlign.right,
      color: textColor,
      fontSize: 11,
    );
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
    )..layout(maxWidth: 150);
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

  @override
  bool shouldRepaint(covariant VolumeProfileChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.profile != profile ||
        oldDelegate.signal != signal;
  }
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
      if (signal?.targetPrice != null) signal!.targetPrice!,
      if (signal?.stopPrice != null) signal!.stopPrice!,
    ].where((value) => value > 0).toList();
    if (values.isEmpty) return const _PriceRange(min: 0, max: 1);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final padding = math.max((maxValue - minValue) * 0.08, maxValue * 0.001);
    return _PriceRange(min: minValue - padding, max: maxValue + padding);
  }
}
