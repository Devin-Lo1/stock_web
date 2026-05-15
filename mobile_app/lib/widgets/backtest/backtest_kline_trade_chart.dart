import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../models/candle.dart';
import '../../utils/theme_helpers.dart';

class BacktestKlineTradeChart extends StatefulWidget {
  const BacktestKlineTradeChart({
    super.key,
    required this.candles,
    required this.trades,
  });

  final List<Candle> candles;
  final List<BacktestTrade> trades;

  @override
  State<BacktestKlineTradeChart> createState() =>
      _BacktestKlineTradeChartState();
}

class _BacktestKlineTradeChartState extends State<BacktestKlineTradeChart> {
  static const int _defaultVisibleCount = 90;
  static const int _minVisibleCount = 24;

  int _visibleCount = _defaultVisibleCount;
  int _visibleEndIndex = 0;
  int? _selectedVisibleIndex;
  int _scaleStartVisibleCount = _defaultVisibleCount;
  double _dragRemainder = 0;

  @override
  void didUpdateWidget(covariant BacktestKlineTradeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles != widget.candles) {
      _visibleEndIndex = 0;
      _selectedVisibleIndex = null;
      _dragRemainder = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final candles = _sortedCandles;
    final view = _ViewWindow.fromState(
      totalCount: candles.length,
      visibleCount: _visibleCount,
      visibleEndIndex: _visibleEndIndex,
    );
    final visibleCandles = candles.sublist(view.start, view.end);
    final fullMa5 = _movingAverage(candles, 5);
    final fullMa20 = _movingAverage(candles, 20);
    final visibleMa5 = fullMa5.sublist(view.start, view.end);
    final visibleMa20 = fullMa20.sublist(view.start, view.end);
    final selectedIndex = _normalizedSelectedIndex(visibleCandles.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _selectAt(
            details.localPosition.dx,
            constraints.maxWidth,
            visibleCandles.length,
          ),
          onScaleStart: (_) {
            _scaleStartVisibleCount = _visibleCount;
            _dragRemainder = 0;
          },
          onScaleUpdate: (details) => _handleScaleUpdate(
            details,
            constraints.maxWidth,
            candles.length,
            view,
          ),
          child: SizedBox(
            height: 310,
            width: double.infinity,
            child: CustomPaint(
              painter: _BacktestKlineTradePainter(
                candles: visibleCandles,
                ma5: visibleMa5,
                ma20: visibleMa20,
                trades: widget.trades,
                selectedIndex: selectedIndex,
                gridColor: borderColor(context).withValues(alpha: 0.56),
                axisColor: mutedIconColor(context).withValues(alpha: 0.72),
                panelColor: pageBackgroundColor(
                  context,
                ).withValues(alpha: 0.72),
                textColor: secondaryTextColor(context),
                primaryTextColor: primaryTextColor(context),
                upColor: const Color(0xFF12B886),
                downColor: const Color(0xFFFF3B45),
                ma5Color: const Color(0xFFE6B450),
                ma20Color: const Color(0xFFD75AC8),
                buyColor: const Color(0xFF12B886),
                sellColor: const Color(0xFFFF3B45),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Candle> get _sortedCandles {
    return widget.candles.where((candle) => candle.time != null).toList()
      ..sort((a, b) => a.time!.compareTo(b.time!));
  }

  int? _normalizedSelectedIndex(int visibleLength) {
    final selected = _selectedVisibleIndex;
    if (selected == null || visibleLength == 0) return null;
    return selected.clamp(0, visibleLength - 1);
  }

  void _selectAt(double dx, double width, int visibleLength) {
    if (visibleLength <= 0 || width <= 0) return;
    final rawIndex = (dx / width * visibleLength).floor();
    setState(() {
      _selectedVisibleIndex = rawIndex.clamp(0, visibleLength - 1);
    });
  }

  void _handleScaleUpdate(
    ScaleUpdateDetails details,
    double width,
    int totalCount,
    _ViewWindow view,
  ) {
    if (totalCount <= 1 || width <= 0) return;
    if ((details.scale - 1).abs() > 0.02) {
      final nextVisibleCount = (_scaleStartVisibleCount / details.scale)
          .round()
          .clamp(_minVisibleCount, totalCount);
      if (nextVisibleCount == _visibleCount) return;
      setState(() {
        _visibleCount = nextVisibleCount;
        _visibleEndIndex = view.end;
        _selectedVisibleIndex = null;
      });
      return;
    }

    final candleWidth = width / math.max(1, view.count);
    _dragRemainder += details.focalPointDelta.dx;
    final shift = (_dragRemainder / candleWidth).truncate();
    if (shift == 0) return;
    _dragRemainder -= shift * candleWidth;
    final nextEnd = (view.end - shift).clamp(view.count, totalCount);
    if (nextEnd == view.end) return;
    setState(() {
      _visibleEndIndex = nextEnd;
      _selectedVisibleIndex = null;
    });
  }

  List<double?> _movingAverage(List<Candle> values, int window) {
    final result = List<double?>.filled(values.length, null);
    var sum = 0.0;
    for (var index = 0; index < values.length; index++) {
      sum += values[index].close;
      if (index >= window) sum -= values[index - window].close;
      if (index >= window - 1) result[index] = sum / window;
    }
    return result;
  }
}

class _BacktestKlineTradePainter extends CustomPainter {
  const _BacktestKlineTradePainter({
    required this.candles,
    required this.ma5,
    required this.ma20,
    required this.trades,
    required this.selectedIndex,
    required this.gridColor,
    required this.axisColor,
    required this.panelColor,
    required this.textColor,
    required this.primaryTextColor,
    required this.upColor,
    required this.downColor,
    required this.ma5Color,
    required this.ma20Color,
    required this.buyColor,
    required this.sellColor,
  });

  final List<Candle> candles;
  final List<double?> ma5;
  final List<double?> ma20;
  final List<BacktestTrade> trades;
  final int? selectedIndex;
  final Color gridColor;
  final Color axisColor;
  final Color panelColor;
  final Color textColor;
  final Color primaryTextColor;
  final Color upColor;
  final Color downColor;
  final Color ma5Color;
  final Color ma20Color;
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

    final range = _PriceRange.fromCandles(
      candles: candles,
      maValues: [...ma5.whereType<double>(), ...ma20.whereType<double>()],
      trades: _visibleTrades(candles, trades),
    );

    _drawMaLine(canvas, area, ma20, range, ma20Color);
    _drawMaLine(canvas, area, ma5, range, ma5Color);
    _drawCandles(canvas, area, range);
    _drawTradeMarkers(canvas, area, range);
    _drawSelection(canvas, area, range);
    _drawLabels(canvas, area, range);
    _drawInfoPanel(canvas, size, selectedIndex);
  }

  void _drawCandles(Canvas canvas, Rect area, _PriceRange range) {
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

  void _drawTradeMarkers(Canvas canvas, Rect area, _PriceRange range) {
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

  void _drawSelection(Canvas canvas, Rect area, _PriceRange range) {
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
    _PriceRange range,
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

  double _yFor(double value, Rect area, _PriceRange range) {
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

  void _drawLabels(Canvas canvas, Rect area, _PriceRange range) {
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
      _dateText(candles.first.time),
      Offset(area.left + 2, area.bottom + 8),
    );
    _drawText(
      canvas,
      _dateText(candles.last.time),
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
      value: _fullDateText(selected.time),
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
      value: _compactNumber(selected.volume),
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
      value: tradeText ?? _compactNumber(selected.turnover),
      offset: Offset(columnXs[3], 27),
      maxWidth: columnWidths[3] - 6,
      valueColor: tradeText == null ? primaryTextColor : changeColor,
    );
  }

  List<BacktestTrade> _tradesForCandle(Candle candle) {
    final time = candle.time;
    if (time == null) return const [];
    return trades.where((trade) {
      final tradeTime = trade.time;
      if (tradeTime == null) return false;
      return _dateKey(tradeTime) == _dateKey(time);
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
  bool shouldRepaint(covariant _BacktestKlineTradePainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.ma5 != ma5 ||
        oldDelegate.ma20 != ma20 ||
        oldDelegate.trades != trades ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.panelColor != panelColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.primaryTextColor != primaryTextColor ||
        oldDelegate.upColor != upColor ||
        oldDelegate.downColor != downColor ||
        oldDelegate.ma5Color != ma5Color ||
        oldDelegate.ma20Color != ma20Color ||
        oldDelegate.buyColor != buyColor ||
        oldDelegate.sellColor != sellColor;
  }
}

class _ViewWindow {
  const _ViewWindow({
    required this.start,
    required this.end,
    required this.count,
  });

  factory _ViewWindow.fromState({
    required int totalCount,
    required int visibleCount,
    required int visibleEndIndex,
  }) {
    if (totalCount <= 0) {
      return const _ViewWindow(start: 0, end: 0, count: 0);
    }
    final count = visibleCount.clamp(1, totalCount);
    final end = (visibleEndIndex <= 0 ? totalCount : visibleEndIndex).clamp(
      count,
      totalCount,
    );
    return _ViewWindow(start: end - count, end: end, count: count);
  }

  final int start;
  final int end;
  final int count;
}

class _PriceRange {
  const _PriceRange({required this.min, required this.max});

  factory _PriceRange.fromCandles({
    required List<Candle> candles,
    required List<double> maValues,
    required List<BacktestTrade> trades,
  }) {
    var minValue = candles.map((candle) => candle.low).reduce(math.min);
    var maxValue = candles.map((candle) => candle.high).reduce(math.max);
    for (final value in maValues) {
      minValue = math.min(minValue, value);
      maxValue = math.max(maxValue, value);
    }
    for (final trade in trades) {
      minValue = math.min(minValue, trade.price);
      maxValue = math.max(maxValue, trade.price);
    }
    final padding = math.max((maxValue - minValue) * 0.08, 0.01);
    return _PriceRange(min: minValue - padding, max: maxValue + padding);
  }

  final double min;
  final double max;

  double get size {
    final value = max - min;
    return value.abs() < 0.0001 ? 1 : value;
  }
}

List<BacktestTrade> _visibleTrades(
  List<Candle> candles,
  List<BacktestTrade> trades,
) {
  if (candles.isEmpty) return const [];
  final firstTime = candles.first.time;
  final lastTime = candles.last.time;
  if (firstTime == null || lastTime == null) return const [];
  final firstKey = _dateKey(firstTime);
  final lastKey = _dateKey(lastTime);
  return trades.where((trade) {
    final tradeTime = trade.time;
    if (tradeTime == null) return false;
    final key = _dateKey(tradeTime);
    return key >= firstKey && key <= lastKey;
  }).toList();
}

int _dateKey(DateTime value) {
  return value.year * 10000 + value.month * 100 + value.day;
}

String _dateText(DateTime? value) {
  if (value == null) return '--';
  return '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

String _fullDateText(DateTime? value) {
  if (value == null) return '--';
  return '${value.year.toString().padLeft(4, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

String _compactNumber(double value) {
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}\u4ebf';
  }
  if (absValue >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}\u4e07';
  }
  if (absValue >= 100) {
    return value.toStringAsFixed(0);
  }
  if (absValue >= 1) {
    return value.toStringAsFixed(2);
  }
  return value.toStringAsFixed(0);
}
