import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../models/candle.dart';
import '../../utils/theme_helpers.dart';
import 'backtest_chart_values.dart';
import 'backtest_kline_trade_painter.dart';

class BacktestKlineTradeChart extends StatefulWidget {
  const BacktestKlineTradeChart({
    super.key,
    required this.candles,
    required this.trades,
    this.shortMaWindow = 5,
    this.longMaWindow = 20,
  });

  final List<Candle> candles;
  final List<BacktestTrade> trades;
  final int shortMaWindow;
  final int longMaWindow;

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
    final view = BacktestViewWindow.fromState(
      totalCount: candles.length,
      visibleCount: _visibleCount,
      visibleEndIndex: _visibleEndIndex,
    );
    final visibleCandles = candles.sublist(view.start, view.end);
    final shortWindow = widget.shortMaWindow.clamp(1, 240);
    final longWindow = widget.longMaWindow.clamp(1, 240);
    final fullShortMa = calculateMovingAverage(candles, shortWindow);
    final fullLongMa = calculateMovingAverage(candles, longWindow);
    final visibleShortMa = fullShortMa.sublist(view.start, view.end);
    final visibleLongMa = fullLongMa.sublist(view.start, view.end);
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
              painter: BacktestKlineTradePainter(
                candles: visibleCandles,
                shortMa: visibleShortMa,
                longMa: visibleLongMa,
                shortMaLabel: 'MA$shortWindow',
                longMaLabel: 'MA$longWindow',
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
                shortMaColor: const Color(0xFFE6B450),
                longMaColor: const Color(0xFF5BA7D7),
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
    BacktestViewWindow view,
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
}
