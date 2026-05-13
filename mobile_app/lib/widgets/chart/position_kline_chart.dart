import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/candle.dart';
import '../../models/stock_position.dart';
import '../../utils/theme_helpers.dart';
import 'kline_chart_period.dart';
import 'kline_chart_values.dart';
import 'kline_info_panel.dart';
import 'kline_painter.dart';

class PositionKLineChart extends StatefulWidget {
  const PositionKLineChart({
    super.key,
    required this.position,
    required this.candles,
    required this.period,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onOpenFullScreen,
  });

  final StockPosition position;
  final List<Candle> candles;
  final KLineChartPeriod period;
  final bool isLoading;
  final bool hasError;
  final Future<List<Candle>> Function() onRetry;
  final VoidCallback onOpenFullScreen;

  @override
  State<PositionKLineChart> createState() => _PositionKLineChartState();
}

class _PositionKLineChartState extends State<PositionKLineChart> {
  static const _defaultVisibleCount = 64;
  static const _minVisibleCount = 12;
  static const _maxVisibleCount = 240;
  int _visibleCount = _defaultVisibleCount;
  int _rightOffset = 0;
  int? _selectedVisibleIndex;
  int _scaleStartVisibleCount = _defaultVisibleCount;
  double _dragSlotRemainder = 0;
  final Set<int> _activePointerIds = <int>{};

  int get _effectiveVisibleCount {
    if (widget.candles.isEmpty) return _visibleCount;
    return math.min(_visibleCount, widget.candles.length);
  }

  int get _maxOffset =>
      math.max(0, widget.candles.length - _effectiveVisibleCount);

  @override
  void didUpdateWidget(covariant PositionKLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _visibleCount = _defaultVisibleCount;
      _rightOffset = 0;
      _selectedVisibleIndex = null;
    }
    if (oldWidget.candles != widget.candles && _rightOffset > _maxOffset) {
      _rightOffset = _maxOffset;
    }
  }

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
    final visibleCandles = _visibleCandles;
    if (visibleCandles.isEmpty || width <= 0) return;
    final slotWidth = width / visibleCandles.length;
    final nextIndex = (localPosition.dx / slotWidth)
        .floor()
        .clamp(0, visibleCandles.length - 1)
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

    return Container(
      height: selectedCandle == null ? 304 : 356,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Listener(
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerUp,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _selectCandle(details.localPosition, constraints.maxWidth),
              onLongPressDown: (details) =>
                  _selectCandle(details.localPosition, constraints.maxWidth),
              onDoubleTap: widget.onOpenFullScreen,
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
                    top: selectedCandle == null ? 0 : 62,
                    child: KLineMaStrip(maValues: maValues),
                  ),
                  Positioned.fill(
                    top: selectedCandle == null ? 28 : 90,
                    child: ClipRect(
                      child: CustomPaint(
                        painter: InteractiveKLinePainter(
                          candles: visibleCandles,
                          allCandles: widget.candles,
                          startIndex: _visibleStartIndex,
                          selectedIndex: _selectedVisibleIndex,
                          gridColor: borderColor(context),
                          extremeLabelBackgroundColor: isDarkMode(context)
                              ? const Color(0xFF0A141F).withValues(alpha: 0.78)
                              : const Color(0xFFFFFFFF).withValues(alpha: 0.88),
                          extremeLabelBorderColor: isDarkMode(context)
                              ? secondaryTextColor(
                                  context,
                                ).withValues(alpha: 0.72)
                              : const Color(0xFF6B7A88).withValues(alpha: 0.65),
                          upColor: const Color(0xFF12B886),
                          downColor: const Color(0xFFFF3B45),
                          ma5Color: const Color(0xFFE0A84C),
                          ma10Color: const Color(0xFF5BA7D7),
                          ma20Color: const Color(0xFFC65BB8),
                          ma60Color: const Color(0xFF5CC9C7),
                          crosshairColor: secondaryTextColor(
                            context,
                          ).withValues(alpha: 0.5),
                          axisLabelColor: secondaryTextColor(context),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton(
                      tooltip: '横屏全图',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onOpenFullScreen,
                      icon: Icon(
                        Icons.open_in_full_rounded,
                        color: secondaryTextColor(
                          context,
                        ).withValues(alpha: 0.55),
                        size: 18,
                      ),
                    ),
                  ),
                  if (_rightOffset > 0)
                    Positioned(
                      right: 0,
                      top: 36,
                      child: IconButton(
                        tooltip: '回到最新',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _rightOffset = 0),
                        icon: const Icon(
                          Icons.keyboard_double_arrow_right_rounded,
                        ),
                      ),
                    ),
                  if (widget.isLoading)
                    const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  if (!widget.isLoading && widget.hasError)
                    Center(
                      child: FilledButton.tonalIcon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试K线'),
                      ),
                    ),
                  if (!widget.isLoading &&
                      !widget.hasError &&
                      widget.candles.isEmpty)
                    Center(
                      child: Text(
                        '暂无K线数据',
                        style: TextStyle(
                          color: secondaryTextColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
