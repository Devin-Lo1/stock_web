import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/candle.dart';
import '../../models/stock_position.dart';
import '../../utils/formatters.dart';
import '../../utils/market_data_formatters.dart';
import '../../utils/theme_helpers.dart';
import 'kline_chart_period.dart';
import 'kline_chart_values.dart';
import 'kline_info_panel.dart';
import 'kline_painter.dart';

class FullScreenKLineScreen extends StatefulWidget {
  const FullScreenKLineScreen({
    super.key,
    required this.position,
    required this.candles,
    required this.period,
  });

  final StockPosition position;
  final List<Candle> candles;
  final KLineChartPeriod period;

  @override
  State<FullScreenKLineScreen> createState() => _FullScreenKLineScreenState();
}

class _FullScreenKLineScreenState extends State<FullScreenKLineScreen> {
  static const _defaultVisibleCount = 96;
  static const _minVisibleCount = 16;
  static const _maxVisibleCount = 320;
  int _visibleCount = _defaultVisibleCount;
  int _rightOffset = 0;
  int? _selectedVisibleIndex;
  int _scaleStartVisibleCount = _defaultVisibleCount;
  double _dragSlotRemainder = 0;
  final Set<int> _activePointerIds = <int>{};

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  int get _effectiveVisibleCount {
    if (widget.candles.isEmpty) return _visibleCount;
    return math.min(_visibleCount, widget.candles.length);
  }

  int get _maxOffset =>
      math.max(0, widget.candles.length - _effectiveVisibleCount);

  List<Candle> get _visibleCandles {
    if (widget.candles.isEmpty) return const [];
    final end = (widget.candles.length - _rightOffset).clamp(
      0,
      widget.candles.length,
    );
    final start = math.max(0, end - _effectiveVisibleCount);
    return widget.candles.sublist(start, end);
  }

  int get _visibleStartIndex {
    if (widget.candles.isEmpty) return 0;
    final end = (widget.candles.length - _rightOffset).clamp(
      0,
      widget.candles.length,
    );
    return math.max(0, end - _effectiveVisibleCount);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _scaleStartVisibleCount = _visibleCount;
    _dragSlotRemainder = 0;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointerIds.add(event.pointer);
    if (_activePointerIds.length == 2) {
      _scaleStartVisibleCount = _visibleCount;
      _dragSlotRemainder = 0;
    }
  }

  void _handlePointerUp(PointerEvent event) {
    _activePointerIds.remove(event.pointer);
    if (_activePointerIds.length < 2) {
      _scaleStartVisibleCount = _visibleCount;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, double width) {
    if (widget.candles.isEmpty || width <= 0) return;
    if (_activePointerIds.length >= 2) {
      final focalRatio = (details.localFocalPoint.dx / width).clamp(0.0, 1.0);
      final focalGlobalIndex =
          _visibleStartIndex + focalRatio * math.max(1, _effectiveVisibleCount);
      final adjustedScale = math.pow(details.scale, 1.25).toDouble();
      final rawCount = (_scaleStartVisibleCount / adjustedScale).round();
      final nextVisibleCount = rawCount
          .clamp(
            _minVisibleCount,
            math.min(_maxVisibleCount, widget.candles.length),
          )
          .toInt();
      if (nextVisibleCount != _visibleCount) {
        setState(() {
          _visibleCount = nextVisibleCount;
          final nextStart = (focalGlobalIndex - focalRatio * nextVisibleCount)
              .round()
              .clamp(0, math.max(0, widget.candles.length - nextVisibleCount))
              .toInt();
          _rightOffset = widget.candles.length - (nextStart + nextVisibleCount);
          if (_selectedVisibleIndex != null &&
              _selectedVisibleIndex! >= _effectiveVisibleCount) {
            _selectedVisibleIndex = _effectiveVisibleCount - 1;
          }
        });
      }
      _selectCandle(details.localFocalPoint, width);
      return;
    }

    if (_maxOffset > 0) {
      final slotWidth = width / math.max(1, _effectiveVisibleCount);
      final delta = details.focalPointDelta.dx / slotWidth + _dragSlotRemainder;
      final slotDelta = delta.truncate();
      _dragSlotRemainder = delta - slotDelta;
      if (slotDelta != 0) {
        final nextOffset = (_rightOffset - slotDelta).clamp(0, _maxOffset);
        if (nextOffset != _rightOffset) {
          setState(() => _rightOffset = nextOffset);
        }
      }
    }
    _selectCandle(details.localFocalPoint, width);
  }

  void _selectCandle(Offset localPosition, double width) {
    final visible = _visibleCandles;
    if (visible.isEmpty || width <= 0) return;
    final slotWidth = width / visible.length;
    final nextIndex = (localPosition.dx / slotWidth)
        .floor()
        .clamp(0, visible.length - 1)
        .toInt();
    setState(() => _selectedVisibleIndex = nextIndex);
  }

  double _previousCloseForSelected(List<Candle> visibleCandles) {
    final selectedIndex = _selectedVisibleIndex;
    if (selectedIndex == null) return 0;
    final globalIndex = _visibleStartIndex + selectedIndex;
    if (globalIndex <= 0 || globalIndex > widget.candles.length - 1) {
      return visibleCandles[selectedIndex].open;
    }
    return widget.candles[globalIndex - 1].close;
  }

  @override
  Widget build(BuildContext context) {
    final visibleCandles = _visibleCandles;
    final selectedGlobalIndex = _selectedVisibleIndex == null
        ? null
        : _visibleStartIndex + _selectedVisibleIndex!;
    final maValues = klineMaValuesAt(
      widget.candles,
      selectedGlobalIndex ?? widget.candles.length - 1,
    );
    final selectedCandle =
        _selectedVisibleIndex == null ||
            _selectedVisibleIndex! >= visibleCandles.length
        ? null
        : visibleCandles[_selectedVisibleIndex!];
    final changeColor = klineProfitColor(widget.position.dailyProfit);

    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const headerHeight = 96.0;
            return Stack(
              children: [
                Positioned(
                  left: 14,
                  right: 14,
                  top: 8,
                  height: headerHeight,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 18,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.position.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: primaryTextColor(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  widget.position.code,
                                  style: TextStyle(
                                    color: secondaryTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.position.price,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: changeColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${formatMarketMoney(widget.position.market, widget.position.currentPrice - widget.position.previousClose)}  ${widget.position.change}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: changeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 17,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FullMetric(
                                  label: '今开',
                                  value: formatQuotePrice(
                                    widget.position.openPrice,
                                    widget.position.previousClose,
                                  ),
                                  valueColor: klineQuoteColor(
                                    widget.position.openPrice,
                                    widget.position.previousClose,
                                    context,
                                  ),
                                ),
                                _FullMetric(
                                  label: '昨收',
                                  value: formatQuotePrice(
                                    widget.position.previousClose,
                                    widget.position.previousClose,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 17,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FullMetric(
                                  label: '最高',
                                  value: formatQuotePrice(
                                    widget.position.highPrice,
                                    widget.position.previousClose,
                                  ),
                                  valueColor: klineQuoteColor(
                                    widget.position.highPrice,
                                    widget.position.previousClose,
                                    context,
                                  ),
                                ),
                                _FullMetric(
                                  label: '最低',
                                  value: formatQuotePrice(
                                    widget.position.lowPrice,
                                    widget.position.previousClose,
                                  ),
                                  valueColor: klineQuoteColor(
                                    widget.position.lowPrice,
                                    widget.position.previousClose,
                                    context,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 17,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FullMetric(
                                  label: '成交量',
                                  value: formatMarketVolume(
                                    widget.position.volume,
                                  ),
                                ),
                                _FullMetric(
                                  label: '成交额',
                                  value: formatMarketAmount(
                                    widget.position.turnover,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '退出全屏',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _FullPeriodTabs(selectedPeriod: widget.period),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: headerHeight + 6,
                  bottom: 10,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final chartTop = selectedCandle == null ? 22.0 : 80.0;
                      return Listener(
                        onPointerDown: _handlePointerDown,
                        onPointerUp: _handlePointerUp,
                        onPointerCancel: _handlePointerUp,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) => _selectCandle(
                            details.localPosition,
                            constraints.maxWidth,
                          ),
                          onScaleStart: _handleScaleStart,
                          onScaleUpdate: (details) =>
                              _handleScaleUpdate(details, constraints.maxWidth),
                          child: Stack(
                            children: [
                              if (selectedCandle != null)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  child: SelectedCandleInfoPanel(
                                    candle: selectedCandle,
                                    previousClose: _previousCloseForSelected(
                                      visibleCandles,
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: selectedCandle == null ? 0 : 58,
                                child: KLineMaStrip(maValues: maValues),
                              ),
                              Positioned.fill(
                                top: chartTop,
                                child: ClipRect(
                                  child: CustomPaint(
                                    painter: InteractiveKLinePainter(
                                      candles: visibleCandles,
                                      allCandles: widget.candles,
                                      startIndex: _visibleStartIndex,
                                      selectedIndex: _selectedVisibleIndex,
                                      gridColor: borderColor(context),
                                      extremeLabelBackgroundColor:
                                          isDarkMode(context)
                                          ? const Color(
                                              0xFF0A141F,
                                            ).withValues(alpha: 0.78)
                                          : const Color(
                                              0xFFFFFFFF,
                                            ).withValues(alpha: 0.88),
                                      extremeLabelBorderColor:
                                          isDarkMode(context)
                                          ? secondaryTextColor(
                                              context,
                                            ).withValues(alpha: 0.72)
                                          : const Color(
                                              0xFF6B7A88,
                                            ).withValues(alpha: 0.65),
                                      upColor: const Color(0xFF12B886),
                                      downColor: const Color(0xFFFF3B45),
                                      ma5Color: const Color(0xFFE0A84C),
                                      ma10Color: const Color(0xFF5BA7D7),
                                      ma20Color: const Color(0xFFC65BB8),
                                      ma60Color: const Color(0xFF5CC9C7),
                                      crosshairColor: secondaryTextColor(
                                        context,
                                      ).withValues(alpha: 0.5),
                                      axisLabelColor: secondaryTextColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FullPeriodTabs extends StatelessWidget {
  const _FullPeriodTabs({required this.selectedPeriod});

  final KLineChartPeriod selectedPeriod;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final period in KLineChartPeriod.values) ...[
          _FullPeriodTab(
            label: period.label,
            isSelected: period == selectedPeriod,
          ),
          if (period != KLineChartPeriod.values.last) const SizedBox(width: 24),
        ],
      ],
    );
  }
}

class _FullPeriodTab extends StatelessWidget {
  const _FullPeriodTab({required this.label, required this.isSelected});

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? primaryTextColor(context)
        : secondaryTextColor(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: isSelected ? appAccentColor(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _FullMetric extends StatelessWidget {
  const _FullMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: secondaryTextColor(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(
              color: valueColor ?? primaryTextColor(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
