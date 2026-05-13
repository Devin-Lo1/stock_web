import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/candle.dart';
import '../models/stock_position.dart';
import '../utils/formatters.dart';
import '../utils/market_data_formatters.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/chart/kline_chart_period.dart';
import '../widgets/position/position_detail_metric.dart';
import '../widgets/quote/quote_overview_grid.dart';

class PositionDetailScreen extends StatefulWidget {
  const PositionDetailScreen({
    super.key,
    required this.position,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
    required this.onLoadCandles,
  });

  final StockPosition position;
  final Future<StockPosition?> Function(StockPosition position) onEdit;
  final VoidCallback onDelete;
  final Future<List<StockPosition>> Function() onRefresh;
  final Future<List<Candle>> Function(String code, {String period, int limit})
  onLoadCandles;

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
  late StockPosition _position = widget.position;
  List<Candle> _candles = const [];
  bool _isLoadingCandles = true;
  Object? _candleError;
  KLineChartPeriod _selectedPeriod = KLineChartPeriod.day;

  @override
  void initState() {
    super.initState();
    _loadCandles();
  }

  Future<void> _editPosition() async {
    final updated = await widget.onEdit(_position);
    if (updated != null && mounted) {
      setState(() => _position = updated);
    }
  }

  void _deletePosition() {
    widget.onDelete();
    Navigator.of(context).pop();
  }

  void _openFullScreenChart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _FullScreenKLineScreen(
          position: _position,
          candles: _candles,
          period: _selectedPeriod,
        ),
      ),
    );
  }

  Future<void> _refreshPosition() async {
    final results = await Future.wait<Object>([
      widget.onRefresh(),
      _loadCandles(silent: true),
    ]);
    if (!mounted) return;
    final positions = results.first as List<StockPosition>;
    final latest = _findLatestPosition(positions, _position);
    if (latest != null) {
      setState(() => _position = latest);
    }
  }

  Future<List<Candle>> _loadCandles({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoadingCandles = true;
        _candleError = null;
      });
    }
    try {
      final candles = await widget.onLoadCandles(
        _position.code,
        period: _selectedPeriod.apiPeriod,
        limit: _selectedPeriod.limit,
      );
      if (mounted) {
        setState(() {
          _candles = candles;
          _isLoadingCandles = false;
          _candleError = null;
        });
      }
      return candles;
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingCandles = false;
          _candleError = error;
        });
      }
      return const [];
    }
  }

  Future<void> _changeChartPeriod(KLineChartPeriod period) async {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
      _candles = const [];
      _candleError = null;
    });
    await _loadCandles();
  }

  @override
  Widget build(BuildContext context) {
    final dailyColor = _profitColor(_position.dailyProfit);

    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: pageBackgroundColor(context),
        title: Column(
          children: [
            Text(_position.name, style: const TextStyle(fontSize: 19)),
            Text(
              _position.code,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '删除持仓',
            onPressed: _deletePosition,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: '编辑持仓',
            onPressed: _editPosition,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosition,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          children: [
            Text(
              _position.price,
              style: TextStyle(
                color: dailyColor,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${formatHkd(_position.currentPrice - _position.previousClose)}  ${_position.change}',
              style: TextStyle(
                color: dailyColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            QuoteOverviewGrid(position: _position),
            const SizedBox(height: 14),
            KLineChartTabs(
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: _changeChartPeriod,
            ),
            const SizedBox(height: 10),
            _InteractiveKLinePreview(
              position: _position,
              candles: _candles,
              period: _selectedPeriod,
              isLoading: _isLoadingCandles,
              hasError: _candleError != null,
              onRetry: _loadCandles,
              onOpenFullScreen: _openFullScreenChart,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppTag(text: _position.signal),
                AppTag(text: '数量 ${formatNumberInput(_position.quantity)}'),
                AppTag(text: '现价 ${_position.price}'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PositionDetailMetric(
                    label: '当日收益',
                    value: formatHkd(_position.dailyProfit),
                    subValue: formatPercent(_position.dailyProfitRate),
                    color: _profitColor(_position.dailyProfit),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PositionDetailMetric(
                    label: '持有收益',
                    value: _position.pnl,
                    subValue: formatPercent(_position.profitRate),
                    color: _profitColor(_position.profit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PositionDetailMetric(
                    label: '成本价',
                    value: formatHkd(
                      _position.costPrice,
                      showSign: false,
                      decimals: 2,
                    ),
                    subValue:
                        '成本 ${formatHkd(_position.costValue, showSign: false)}',
                    color: primaryTextColor(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PositionDetailMetric(
                    label: '昨收',
                    value: formatHkd(
                      _position.previousClose,
                      showSign: false,
                      decimals: 2,
                    ),
                    subValue: '涨跌 ${_position.change}',
                    color: primaryTextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _editPosition,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('修改持仓'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _deletePosition,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

StockPosition? _findLatestPosition(
  List<StockPosition> positions,
  StockPosition current,
) {
  for (final position in positions) {
    if (current.id != null && position.id == current.id) return position;
  }
  for (final position in positions) {
    if (position.code.toUpperCase() == current.code.toUpperCase()) {
      return position;
    }
  }
  return null;
}

// ignore: unused_element
class _KLinePreview extends StatelessWidget {
  const _KLinePreview({
    required this.position,
    required this.candles,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onOpenFullScreen,
  });

  final StockPosition position;
  final List<Candle> candles;
  final bool isLoading;
  final bool hasError;
  final Future<List<Candle>> Function() onRetry;
  final VoidCallback onOpenFullScreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            top: 28,
            child: CustomPaint(
              painter: _KLinePreviewPainter(
                color: position.dailyProfit >= 0
                    ? const Color(0xFFF05252)
                    : const Color(0xFF22C55E),
                gridColor: borderColor(context),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  '模拟分时',
                  style: TextStyle(
                    color: _profitColor(position.dailyProfit),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KLinePreviewPainter extends CustomPainter {
  const _KLinePreviewPainter({required this.color, required this.gridColor});

  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final points = [
      Offset(0, size.height * 0.55),
      Offset(size.width * 0.08, size.height * 0.32),
      Offset(size.width * 0.16, size.height * 0.60),
      Offset(size.width * 0.28, size.height * 0.70),
      Offset(size.width * 0.42, size.height * 0.62),
      Offset(size.width * 0.56, size.height * 0.78),
      Offset(size.width * 0.70, size.height * 0.66),
      Offset(size.width * 0.84, size.height * 0.72),
      Offset(size.width, size.height * 0.64),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _KLinePreviewPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.gridColor != gridColor;
  }
}

// ignore: unused_element
class _RealKLinePreview extends StatelessWidget {
  const _RealKLinePreview({
    required this.position,
    required this.candles,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onOpenFullScreen,
  });

  final StockPosition position;
  final List<Candle> candles;
  final bool isLoading;
  final bool hasError;
  final Future<List<Candle>> Function() onRetry;
  final VoidCallback onOpenFullScreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            top: 28,
            child: CustomPaint(
              painter: _RealKLinePainter(
                candles: candles,
                gridColor: borderColor(context),
                upColor: const Color(0xFF12B886),
                downColor: const Color(0xFFFF3B45),
                mutedColor: secondaryTextColor(context).withValues(alpha: 0.55),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              candles.isEmpty ? '日K' : '日K ${candles.length}根',
              style: TextStyle(
                color: _profitColor(position.dailyProfit),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          if (!isLoading && hasError)
            Center(
              child: FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试K线'),
              ),
            ),
          if (!isLoading && !hasError && candles.isEmpty)
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
    );
  }
}

class _RealKLinePainter extends CustomPainter {
  const _RealKLinePainter({
    required this.candles,
    required this.gridColor,
    required this.upColor,
    required this.downColor,
    required this.mutedColor,
  });

  final List<Candle> candles;
  final Color gridColor;
  final Color upColor;
  final Color downColor;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    if (candles.isEmpty) return;

    final visibleCandles = candles.length > 60
        ? candles.sublist(candles.length - 60)
        : candles;
    final maxPrice = visibleCandles
        .map((candle) => candle.high)
        .reduce(math.max);
    final minPrice = visibleCandles
        .map((candle) => candle.low)
        .reduce(math.min);
    final priceRange = math.max(maxPrice - minPrice, 0.01);
    final slotWidth = size.width / visibleCandles.length;
    final bodyWidth = math.max(3.0, math.min(9.0, slotWidth * 0.56));

    double yFor(double price) {
      return size.height - (price - minPrice) / priceRange * size.height;
    }

    final maPath = Path();
    for (var index = 0; index < visibleCandles.length; index++) {
      final candle = visibleCandles[index];
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
          ..color = color
          ..strokeWidth = 1.2,
      );
      final rect = Rect.fromLTWH(
        centerX - bodyWidth / 2,
        math.min(openY, closeY),
        bodyWidth,
        math.max((openY - closeY).abs(), 1.5),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = isUp ? color.withValues(alpha: 0.15) : color
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );

      final start = math.max(0, index - 4);
      final average =
          visibleCandles
              .sublist(start, index + 1)
              .fold<double>(0, (sum, item) => sum + item.close) /
          (index - start + 1);
      final maPoint = Offset(centerX, yFor(average));
      if (index == 0) {
        maPath.moveTo(maPoint.dx, maPoint.dy);
      } else {
        maPath.lineTo(maPoint.dx, maPoint.dy);
      }
    }

    canvas.drawPath(
      maPath,
      Paint()
        ..color = mutedColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RealKLinePainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.upColor != upColor ||
        oldDelegate.downColor != downColor ||
        oldDelegate.mutedColor != mutedColor;
  }
}

class _InteractiveKLinePreview extends StatefulWidget {
  const _InteractiveKLinePreview({
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
  State<_InteractiveKLinePreview> createState() =>
      _InteractiveKLinePreviewState();
}

class _InteractiveKLinePreviewState extends State<_InteractiveKLinePreview> {
  static const _visibleCount = 64;
  int _rightOffset = 0;
  int? _selectedVisibleIndex;

  int get _maxOffset => math.max(0, widget.candles.length - _visibleCount);

  @override
  void didUpdateWidget(covariant _InteractiveKLinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
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
    final start = math.max(0, end - _visibleCount);
    return widget.candles.sublist(start, end);
  }

  int get _visibleStartIndex {
    if (widget.candles.isEmpty) return 0;
    final end = (widget.candles.length - _rightOffset).clamp(
      0,
      widget.candles.length,
    );
    return math.max(0, end - _visibleCount);
  }

  void _handleHorizontalDrag(DragUpdateDetails details) {
    if (_maxOffset == 0) return;
    final delta = (details.primaryDelta ?? 0) / 7;
    final nextOffset = (_rightOffset + delta.round()).clamp(0, _maxOffset);
    if (nextOffset != _rightOffset) {
      setState(() => _rightOffset = nextOffset);
    }
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
    final maValues = _maValuesAt(
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
      child: Stack(
        children: [
          Positioned.fill(
            top: selectedCandle == null ? 42 : 94,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _selectCandle(
                    details.localPosition,
                    constraints.maxWidth,
                  ),
                  onLongPressDown: (details) => _selectCandle(
                    details.localPosition,
                    constraints.maxWidth,
                  ),
                  onDoubleTap: widget.onOpenFullScreen,
                  onHorizontalDragDown: (details) => _selectCandle(
                    details.localPosition,
                    constraints.maxWidth,
                  ),
                  onHorizontalDragUpdate: (details) {
                    _handleHorizontalDrag(details);
                    _selectCandle(details.localPosition, constraints.maxWidth);
                  },
                  child: ClipRect(
                    child: CustomPaint(
                      painter: _InteractiveKLinePainter(
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
                );
              },
            ),
          ),
          if (selectedCandle != null)
            Positioned(
              left: 0,
              right: 0,
              top: 32,
              child: _SelectedCandleInfoPanel(
                candle: selectedCandle,
                previousClose: _previousCloseForSelected(visibleCandles),
              ),
            ),
          Align(
            alignment: Alignment.topLeft,
            child: Wrap(
              spacing: 7,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MaLabel(
                  text: 'MA5:${_formatMa(maValues[5])}',
                  color: const Color(0xFFE0A84C),
                ),
                _MaLabel(
                  text: '10:${_formatMa(maValues[10])}',
                  color: const Color(0xFF5BA7D7),
                ),
                _MaLabel(
                  text: '20:${_formatMa(maValues[20])}',
                  color: const Color(0xFFC65BB8),
                ),
                _MaLabel(
                  text: '60:${_formatMa(maValues[60])}',
                  color: const Color(0xFF5CC9C7),
                ),
              ],
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
                color: secondaryTextColor(context).withValues(alpha: 0.55),
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
                icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
              ),
            ),
          if (widget.isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          if (!widget.isLoading && widget.hasError)
            Center(
              child: FilledButton.tonalIcon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试K线'),
              ),
            ),
          if (!widget.isLoading && !widget.hasError && widget.candles.isEmpty)
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

class _SelectedCandleInfoPanel extends StatelessWidget {
  const _SelectedCandleInfoPanel({
    required this.candle,
    required this.previousClose,
  });

  final Candle candle;
  final double previousClose;

  @override
  Widget build(BuildContext context) {
    final change = candle.close - previousClose;
    final changeRate = previousClose == 0 ? 0 : change / previousClose * 100;
    final changeColor = _profitColor(change);
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
                    value: _formatCandleDate(candle.time),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '收',
                    value: _formatPrice(candle.close),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(color: changeColor),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '高',
                    value: _formatPrice(candle.high),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: _profitColor(candle.high - previousClose),
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
                    value: _formatLargeNumber(candle.volume),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '开',
                    value: _formatPrice(candle.open),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: _profitColor(candle.open - previousClose),
                    ),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '低',
                    value: _formatPrice(candle.low),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: _profitColor(candle.low - previousClose),
                    ),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '额',
                    value: _formatLargeNumber(candle.turnover),
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

// ignore: unused_element
class _SelectedCandleInfoGrid extends StatelessWidget {
  const _SelectedCandleInfoGrid({
    required this.candle,
    required this.previousClose,
  });

  final Candle candle;
  final double previousClose;

  @override
  Widget build(BuildContext context) {
    final change = candle.close - previousClose;
    final changeRate = previousClose == 0 ? 0 : change / previousClose * 100;
    final changeColor = _profitColor(change);
    final labelStyle = TextStyle(
      color: secondaryTextColor(context),
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      height: 1.08,
    );
    final valueStyle = TextStyle(
      color: primaryTextColor(context),
      fontSize: 10.5,
      fontWeight: FontWeight.w900,
      height: 1.08,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: pageBackgroundColor(context).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor(context).withValues(alpha: 0.7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = (constraints.maxWidth - 12) / 3;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _InfoCell(
                    width: cellWidth,
                    label: '日',
                    value: _formatCandleDate(candle.time),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '收',
                    value: _formatPrice(candle.close),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(color: changeColor),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '高',
                    value: _formatPrice(candle.high),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: _profitColor(candle.high - previousClose),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _InfoCell(
                    width: cellWidth,
                    label: '量',
                    value: _formatLargeNumber(candle.volume),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '开',
                    value: _formatPrice(candle.open),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: _profitColor(candle.open - previousClose),
                    ),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '低',
                    value: _formatPrice(candle.low),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(
                      color: _profitColor(candle.low - previousClose),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _InfoCell(
                    width: cellWidth,
                    label: '幅',
                    value:
                        '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(2)}%',
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(color: changeColor),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '额',
                    value: _formatLargeNumber(candle.turnover),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle.copyWith(color: changeColor),
                  ),
                  _InfoCell(
                    width: cellWidth,
                    label: '',
                    value: change >= 0
                        ? '+${_formatPrice(change)}'
                        : _formatPrice(change),
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

// ignore: unused_element
class _SelectedCandleInfo extends StatelessWidget {
  const _SelectedCandleInfo({
    required this.candle,
    required this.previousClose,
  });

  final Candle candle;
  final double previousClose;

  @override
  Widget build(BuildContext context) {
    final change = candle.close - previousClose;
    final changeRate = previousClose == 0 ? 0 : change / previousClose * 100;
    final color = _profitColor(change);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: pageBackgroundColor(context).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor(context).withValues(alpha: 0.7)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _CandleInfoText(label: '日', value: _formatCandleDate(candle.time)),
          _CandleInfoText(
            label: '开',
            value: _formatPrice(candle.open),
            valueColor: _profitColor(candle.open - previousClose),
          ),
          _CandleInfoText(label: '高', value: _formatPrice(candle.high)),
          _CandleInfoText(label: '低', value: _formatPrice(candle.low)),
          _CandleInfoText(label: '收', value: _formatPrice(candle.close)),
          _CandleInfoText(
            label: '幅',
            value:
                '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(2)}%',
            valueColor: color,
          ),
          _CandleInfoText(label: '量', value: _formatLargeNumber(candle.volume)),
          _CandleInfoText(
            label: '额',
            value: _formatLargeNumber(candle.turnover),
          ),
        ],
      ),
    );
  }
}

class _CandleInfoText extends StatelessWidget {
  const _CandleInfoText({
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

class _InteractiveKLinePainter extends CustomPainter {
  const _InteractiveKLinePainter({
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
      final average = _movingAverageAt(allCandles, globalIndex, period);
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
      final average = _movingAverageAt(allCandles, startIndex + index, period);
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
      text: _formatPrice(candles[highIndex].high),
      point: Offset(
        slotWidth * highIndex + slotWidth / 2,
        yFor(candles[highIndex].high),
      ),
      isHigh: true,
    );
    _drawExtremeLabel(
      canvas,
      size,
      text: _formatPrice(candles[lowIndex].low),
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
      final label = _formatAxisDate(candles[index].time);
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
  bool shouldRepaint(covariant _InteractiveKLinePainter oldDelegate) {
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

class _FullScreenKLineScreen extends StatefulWidget {
  const _FullScreenKLineScreen({
    required this.position,
    required this.candles,
    required this.period,
  });

  final StockPosition position;
  final List<Candle> candles;
  final KLineChartPeriod period;

  @override
  State<_FullScreenKLineScreen> createState() => _FullScreenKLineScreenState();
}

class _FullScreenKLineScreenState extends State<_FullScreenKLineScreen> {
  static const _visibleCount = 96;
  int _rightOffset = 0;
  int? _selectedVisibleIndex;

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

  int get _maxOffset => math.max(0, widget.candles.length - _visibleCount);

  List<Candle> get _visibleCandles {
    if (widget.candles.isEmpty) return const [];
    final end = (widget.candles.length - _rightOffset).clamp(
      0,
      widget.candles.length,
    );
    final start = math.max(0, end - _visibleCount);
    return widget.candles.sublist(start, end);
  }

  int get _visibleStartIndex {
    if (widget.candles.isEmpty) return 0;
    final end = (widget.candles.length - _rightOffset).clamp(
      0,
      widget.candles.length,
    );
    return math.max(0, end - _visibleCount);
  }

  void _handleDrag(DragUpdateDetails details) {
    if (_maxOffset == 0) return;
    final delta = (details.primaryDelta ?? 0) / 7;
    final nextOffset = (_rightOffset + delta.round()).clamp(0, _maxOffset);
    if (nextOffset != _rightOffset) {
      setState(() => _rightOffset = nextOffset);
    }
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
    final maValues = _maValuesAt(
      widget.candles,
      selectedGlobalIndex ?? widget.candles.length - 1,
    );
    final selectedCandle =
        _selectedVisibleIndex == null ||
            _selectedVisibleIndex! >= visibleCandles.length
        ? null
        : visibleCandles[_selectedVisibleIndex!];
    final changeColor = _profitColor(widget.position.dailyProfit);

    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = selectedCandle == null ? 92.0 : 148.0;
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
                                  '${formatHkd(widget.position.currentPrice - widget.position.previousClose)}  ${widget.position.change}',
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
                                  valueColor: _quoteColor(
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
                                  valueColor: _quoteColor(
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
                                  valueColor: _quoteColor(
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            widget.period.label,
                            style: TextStyle(
                              color: primaryTextColor(context),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 18),
                          _MaLabel(
                            text: 'MA5:${_formatMa(maValues[5])}',
                            color: const Color(0xFFE0A84C),
                          ),
                          const SizedBox(width: 10),
                          _MaLabel(
                            text: 'MA10:${_formatMa(maValues[10])}',
                            color: const Color(0xFF5BA7D7),
                          ),
                          const SizedBox(width: 10),
                          _MaLabel(
                            text: 'MA20:${_formatMa(maValues[20])}',
                            color: const Color(0xFFC65BB8),
                          ),
                          const SizedBox(width: 10),
                          _MaLabel(
                            text: 'MA60:${_formatMa(maValues[60])}',
                            color: const Color(0xFF5CC9C7),
                          ),
                        ],
                      ),
                      if (selectedCandle != null) ...[
                        const SizedBox(height: 6),
                        _SelectedCandleInfoPanel(
                          candle: selectedCandle,
                          previousClose: _previousCloseForSelected(
                            visibleCandles,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: headerHeight + 12,
                  bottom: 10,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _selectCandle(
                          details.localPosition,
                          constraints.maxWidth,
                        ),
                        onHorizontalDragDown: (details) => _selectCandle(
                          details.localPosition,
                          constraints.maxWidth,
                        ),
                        onHorizontalDragUpdate: (details) {
                          _handleDrag(details);
                          _selectCandle(
                            details.localPosition,
                            constraints.maxWidth,
                          );
                        },
                        child: ClipRect(
                          child: CustomPaint(
                            painter: _InteractiveKLinePainter(
                              candles: visibleCandles,
                              allCandles: widget.candles,
                              startIndex: _visibleStartIndex,
                              selectedIndex: _selectedVisibleIndex,
                              gridColor: borderColor(context),
                              extremeLabelBackgroundColor: isDarkMode(context)
                                  ? const Color(
                                      0xFF0A141F,
                                    ).withValues(alpha: 0.78)
                                  : const Color(
                                      0xFFFFFFFF,
                                    ).withValues(alpha: 0.88),
                              extremeLabelBorderColor: isDarkMode(context)
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
                              axisLabelColor: secondaryTextColor(context),
                            ),
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

Map<int, double?> _maValuesAt(List<Candle> candles, int index) {
  if (candles.isEmpty) {
    return {5: null, 10: null, 20: null, 60: null};
  }
  final effectiveIndex = index.clamp(0, candles.length - 1).toInt();
  return {
    5: _movingAverageAt(candles, effectiveIndex, 5),
    10: _movingAverageAt(candles, effectiveIndex, 10),
    20: _movingAverageAt(candles, effectiveIndex, 20),
    60: _movingAverageAt(candles, effectiveIndex, 60),
  };
}

double? _movingAverageAt(List<Candle> candles, int index, int period) {
  if (index < period - 1 || index >= candles.length) return null;
  var sum = 0.0;
  for (var i = index - period + 1; i <= index; i++) {
    sum += candles[i].close;
  }
  return sum / period;
}

String _formatMa(double? value) {
  if (value == null) return '--';
  return value.toStringAsFixed(2);
}

String _formatPrice(double value) {
  return value.toStringAsFixed(2);
}

String _formatCandleDate(DateTime? value) {
  if (value == null) return '--';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}

String _formatAxisDate(DateTime? value) {
  if (value == null) return '--';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}

String _formatLargeNumber(double value) {
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (absValue >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return value.toStringAsFixed(0);
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF3B45);
}

Color? _quoteColor(double value, double previousClose, BuildContext context) {
  if (value == 0 || previousClose == 0 || value == previousClose) return null;
  return _profitColor(value - previousClose);
}
