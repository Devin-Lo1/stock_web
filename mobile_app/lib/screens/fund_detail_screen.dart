import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/fund_models.dart';
import '../repositories/fund_repository.dart';
import '../utils/theme_helpers.dart';

const _fundTrendNavLimit = 370;
const _initialNavRows = 30;
const _expandedNavRows = 50;

enum _FundTrendRange {
  oneMonth('近1月', 31),
  threeMonths('近3月', 93),
  sixMonths('近6月', 186),
  oneYear('近1年', 366);

  const _FundTrendRange(this.label, this.calendarDays);

  final String label;
  final int calendarDays;
}

class FundDetailScreen extends StatefulWidget {
  const FundDetailScreen({
    super.key,
    required this.summary,
    required this.repository,
    required this.onAdjust,
    required this.onEditAlert,
    required this.onDelete,
  });

  final FundPositionSummary summary;
  final FundRepository repository;
  final VoidCallback onAdjust;
  final VoidCallback onEditAlert;
  final VoidCallback onDelete;

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  List<FundNavPoint> _navs = const [];
  List<FundBenchmarkPoint> _benchmarks = const [];
  List<FundTrade> _trades = const [];
  bool _isLoadingNavs = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNavs());
  }

  Future<void> _loadNavs({bool refresh = false}) async {
    setState(() => _isLoadingNavs = true);
    try {
      final navsFuture = widget.repository.loadNavs(
        widget.summary.position.fundCode,
        limit: _fundTrendNavLimit,
        refresh: refresh,
      );
      final benchmarksFuture = _loadBenchmarks();
      final tradesFuture = widget.repository.loadTrades(
        widget.summary.position.id,
        limit: 200,
      );
      final navs = await navsFuture;
      final benchmarks = await benchmarksFuture;
      final trades = await tradesFuture;
      if (mounted) {
        setState(() {
          _navs = navs;
          _benchmarks = benchmarks;
          _trades = trades;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingNavs = false);
    }
  }

  Future<List<FundBenchmarkPoint>> _loadBenchmarks() async {
    try {
      return await widget.repository.loadHs300Benchmark(
        limit: _fundTrendNavLimit,
      );
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final position = summary.position;
    final profitColor = _profitColor(summary.displayChangeRate);
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: DefaultTabController(
        length: 3,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: pageBackgroundColor(context),
                  border: Border(
                    bottom: BorderSide(color: borderColor(context)),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: '返回',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                position.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: primaryTextColor(context),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                position.fundCode,
                                style: TextStyle(
                                  color: secondaryTextColor(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '刷新走势',
                          onPressed: _isLoadingNavs
                              ? null
                              : () => _loadNavs(refresh: true),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _HeaderMetric(
                            label: '${summary.isEstimated ? '估算' : '当日'}涨跌',
                            value: _percent(summary.displayChangeRate),
                            valueColor: profitColor,
                          ),
                        ),
                        Expanded(
                          child: _HeaderMetric(
                            label: '持有收益',
                            value: _money(summary.holdingProfit),
                            valueColor: _profitColor(summary.holdingProfit),
                          ),
                        ),
                        Expanded(
                          child: _HeaderMetric(
                            label: '基金市值',
                            value: _money(summary.marketValue, signed: false),
                            valueColor: primaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: cardColor(context),
                child: TabBar(
                  labelColor: appAccentColor(context),
                  unselectedLabelColor: secondaryTextColor(context),
                  indicatorColor: appAccentColor(context),
                  tabs: const [
                    Tab(text: '业绩走势'),
                    Tab(text: '我的收益'),
                    Tab(text: '提醒策略'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _TrendTab(
                      isLoading: _isLoadingNavs,
                      summary: summary,
                      navs: _navs,
                      benchmarks: _benchmarks,
                      trades: _trades,
                    ),
                    _ProfitTab(summary: summary, onAdjust: widget.onAdjust),
                    _AlertTab(
                      summary: summary,
                      onAdjust: widget.onAdjust,
                      onEditAlert: widget.onEditAlert,
                      onDelete: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendTab extends StatefulWidget {
  const _TrendTab({
    required this.isLoading,
    required this.summary,
    required this.navs,
    required this.benchmarks,
    required this.trades,
  });

  final bool isLoading;
  final FundPositionSummary summary;
  final List<FundNavPoint> navs;
  final List<FundBenchmarkPoint> benchmarks;
  final List<FundTrade> trades;

  @override
  State<_TrendTab> createState() => _TrendTabState();
}

class _TrendTabState extends State<_TrendTab> {
  _FundTrendRange _selectedRange = _FundTrendRange.oneMonth;
  bool _showMoreNavRows = false;

  @override
  Widget build(BuildContext context) {
    final sorted = List<FundNavPoint>.of(widget.navs)
      ..sort((a, b) => a.navDate.compareTo(b.navDate));
    final window = _buildWindow(sorted, _selectedRange);
    final visiblePoints = window.points;
    final benchmarkPoints = _filterBenchmarks(
      widget.benchmarks,
      window.axisStart,
      window.axisEnd,
    );
    final chartCostNav = _chartCostNav(
      points: visiblePoints,
      trades: widget.trades,
      fallbackCostNav: widget.summary.position.avgCostNav,
    );
    final rowCount = math.min(
      _showMoreNavRows ? _expandedNavRows : _initialNavRows,
      visiblePoints.length,
    );
    final rows = visiblePoints.reversed.take(rowCount).toList();
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (!_showMoreNavRows && notification.metrics.pixels > 80) {
          setState(() => _showMoreNavRows = true);
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _TrendLegend(
            points: visiblePoints,
            benchmarks: benchmarkPoints,
            costNav: chartCostNav,
          ),
          const SizedBox(height: 10),
          Container(
            height: 320,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor(context)),
            ),
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : visiblePoints.length < 2
                ? Center(
                    child: Text(
                      '净值数据不足',
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : _FundNavCurve(
                    points: visiblePoints,
                    benchmarks: benchmarkPoints,
                    trades: widget.trades,
                    axisStart: window.axisStart,
                    axisEnd: window.axisEnd,
                    costNav: chartCostNav,
                  ),
          ),
          const SizedBox(height: 12),
          _TrendRangeSelector(
            selectedRange: _selectedRange,
            onChanged: (range) => setState(() => _selectedRange = range),
          ),
          const SizedBox(height: 14),
          const _NavListHeader(),
          ...rows.map((point) => _NavRow(point: point)),
        ],
      ),
    );
  }

  _TrendWindow _buildWindow(List<FundNavPoint> points, _FundTrendRange range) {
    if (points.isEmpty) {
      final now = DateTime.now();
      return _TrendWindow(points: points, axisStart: now, axisEnd: now);
    }
    final latest = points.last.navDate;
    final requestedStart = latest.subtract(Duration(days: range.calendarDays));
    final first = points.first.navDate;
    final axisStart =
        first.isAfter(requestedStart) &&
            first.difference(requestedStart).inDays <= 3
        ? first
        : requestedStart;
    final filtered = points
        .where(
          (point) =>
              !point.navDate.isBefore(axisStart) &&
              !point.navDate.isAfter(latest),
        )
        .toList();
    return _TrendWindow(
      points: filtered.length >= 2 ? filtered : points,
      axisStart: filtered.length >= 2 ? axisStart : points.first.navDate,
      axisEnd: latest,
    );
  }

  List<FundBenchmarkPoint> _filterBenchmarks(
    List<FundBenchmarkPoint> benchmarks,
    DateTime start,
    DateTime end,
  ) {
    if (benchmarks.isEmpty) return const [];
    final sorted = List<FundBenchmarkPoint>.of(benchmarks)
      ..sort((a, b) => a.tradeDate.compareTo(b.tradeDate));
    return sorted
        .where(
          (point) =>
              !point.tradeDate.isBefore(start) && !point.tradeDate.isAfter(end),
        )
        .toList();
  }
}

class _TrendWindow {
  const _TrendWindow({
    required this.points,
    required this.axisStart,
    required this.axisEnd,
  });

  final List<FundNavPoint> points;
  final DateTime axisStart;
  final DateTime axisEnd;
}

class _ProfitTab extends StatelessWidget {
  const _ProfitTab({required this.summary, required this.onAdjust});

  final FundPositionSummary summary;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final position = summary.position;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _MetricGrid(
          items: [
            _MetricItem('份额', position.shares.toStringAsFixed(2)),
            _MetricItem('成本净值', position.avgCostNav.toStringAsFixed(4)),
            _MetricItem(
              summary.isEstimated ? '估算净值' : '正式净值',
              summary.displayNav.toStringAsFixed(4),
            ),
            _MetricItem('当日收益', _money(summary.dayProfit)),
            _MetricItem('持有收益', _money(summary.holdingProfit)),
            _MetricItem('持有收益率', _percent(summary.holdingProfitRate)),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onAdjust,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('修改持仓'),
        ),
        const SizedBox(height: 12),
        _InfoPanel(
          title: summary.isEstimated ? '当前按盘中估算计算' : '当前按正式净值计算',
          content: summary.isEstimated
              ? '收盘前估算用于辅助判断，正式净值更新后会自动切换。'
              : '正式净值通常在交易日晚间更新，刷新后会覆盖盘中估算口径。',
        ),
      ],
    );
  }
}

class _AlertTab extends StatelessWidget {
  const _AlertTab({
    required this.summary,
    required this.onAdjust,
    required this.onEditAlert,
    required this.onDelete,
  });

  final FundPositionSummary summary;
  final VoidCallback onAdjust;
  final VoidCallback onEditAlert;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final position = summary.position;
    final recommendation = summary.gridRecommendation;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        if (recommendation != null)
          _RecommendationPanel(recommendation: recommendation)
        else
          _InfoPanel(
            title: '暂无操作提醒',
            content:
                '当前净值未触发 ${position.alertThresholdPercent.toStringAsFixed(1)}% 阈值。',
          ),
        const SizedBox(height: 12),
        _MetricGrid(
          items: [
            _MetricItem('提醒状态', position.alertEnabled ? '已开启' : '已关闭'),
            _MetricItem(
              '触发阈值',
              '${position.alertThresholdPercent.toStringAsFixed(1)}%',
            ),
            const _MetricItem('提醒口径', '较上次操作'),
            const _MetricItem('操作数量', '自行决定'),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onEditAlert,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('设置提醒规则'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onAdjust,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('修改持仓'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('删除基金持仓'),
        ),
      ],
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({
    required this.points,
    required this.benchmarks,
    required this.costNav,
  });

  final List<FundNavPoint> points;
  final List<FundBenchmarkPoint> benchmarks;
  final double costNav;

  @override
  Widget build(BuildContext context) {
    final fundReturn = _fundReturn(points);
    final benchmarkReturn = _benchmarkReturn(benchmarks);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: const Color(0xFF4D7CFE),
          label: '本基金',
          value: fundReturn == null ? '--' : _percent(fundReturn),
        ),
        _LegendItem(
          color: const Color(0xFFEA8A35),
          label: '沪深300',
          value: benchmarkReturn == null ? '--' : _percent(benchmarkReturn),
        ),
        _LegendItem(
          color: secondaryTextColor(context),
          label: '成本价',
          value: costNav > 0 ? costNav.toStringAsFixed(4) : '--',
          dashed: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final String value;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 8),
          painter: _LegendLinePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: secondaryTextColor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: value.startsWith('--') ? secondaryTextColor(context) : color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 5, size.width), size.height / 2),
        paint,
      );
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dashed != dashed;
  }
}

class _TrendRangeSelector extends StatelessWidget {
  const _TrendRangeSelector({
    required this.selectedRange,
    required this.onChanged,
  });

  final _FundTrendRange selectedRange;
  final ValueChanged<_FundTrendRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final range in _FundTrendRange.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onChanged(range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: range == selectedRange
                        ? appAccentColor(context).withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    range.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: range == selectedRange
                          ? appAccentColor(context)
                          : secondaryTextColor(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FundNavCurve extends StatefulWidget {
  const _FundNavCurve({
    required this.points,
    required this.benchmarks,
    required this.trades,
    required this.axisStart,
    required this.axisEnd,
    required this.costNav,
  });

  final List<FundNavPoint> points;
  final List<FundBenchmarkPoint> benchmarks;
  final List<FundTrade> trades;
  final DateTime axisStart;
  final DateTime axisEnd;
  final double costNav;

  @override
  State<_FundNavCurve> createState() => _FundNavCurveState();
}

class _FundNavCurveState extends State<_FundNavCurve> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _FundNavCurve oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.points.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex == null
        ? null
        : widget.points[_selectedIndex!];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _select(details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _select(details.localPosition.dx),
      child: Stack(
        children: [
          CustomPaint(
            painter: _FundNavCurvePainter(
              points: widget.points,
              benchmarks: widget.benchmarks,
              trades: widget.trades,
              selectedIndex: _selectedIndex,
              axisStart: widget.axisStart,
              axisEnd: widget.axisEnd,
              costNav: widget.costNav,
              gridColor: borderColor(context),
              labelColor: secondaryTextColor(context),
            ),
            child: const SizedBox.expand(),
          ),
          if (selected != null)
            Positioned(
              left: 10,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cardColor(context).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Text(
                    '${_fullDate(selected.navDate)}  净值 ${selected.unitNav.toStringAsFixed(4)}  本基金 ${_percent(_returnFromFirst(widget.points, selected.unitNav))}',
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _select(double dx) {
    if (widget.points.length < 2 || context.size == null) return;
    final ratio = (dx / context.size!.width).clamp(0.0, 1.0);
    final totalDays = math.max(
      1,
      widget.axisEnd.difference(widget.axisStart).inDays,
    );
    final selectedDate = widget.axisStart.add(
      Duration(days: (ratio * totalDays).round()),
    );
    setState(() => _selectedIndex = _nearestFundPointIndex(selectedDate));
  }

  int _nearestFundPointIndex(DateTime date) {
    var bestIndex = 0;
    var bestDistance = 1 << 30;
    for (var i = 0; i < widget.points.length; i++) {
      final distance = widget.points[i].navDate.difference(date).inDays.abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}

class _FundNavCurvePainter extends CustomPainter {
  const _FundNavCurvePainter({
    required this.points,
    required this.benchmarks,
    required this.trades,
    required this.selectedIndex,
    required this.axisStart,
    required this.axisEnd,
    required this.costNav,
    required this.gridColor,
    required this.labelColor,
  });

  static const _fundColor = Color(0xFF4D7CFE);
  static const _benchmarkColor = Color(0xFFEA8A35);
  static const _costColor = Color(0xFF9CA3AF);

  final List<FundNavPoint> points;
  final List<FundBenchmarkPoint> benchmarks;
  final List<FundTrade> trades;
  final int? selectedIndex;
  final DateTime axisStart;
  final DateTime axisEnd;
  final double costNav;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(8, 28, size.width - 16, size.height - 66);
    final fundValues = _fundReturnValues(points);
    final benchmarkValues = _benchmarkReturnValues(benchmarks);
    final costValue = costNav > 0 && points.first.unitNav > 0
        ? (costNav / points.first.unitNav - 1) * 100
        : null;
    final allValues = <double>[...fundValues, ...benchmarkValues, 0];
    if (costValue != null) allValues.add(costValue);
    var minValue = allValues.reduce(math.min);
    var maxValue = allValues.reduce(math.max);
    if ((maxValue - minValue).abs() < 0.01) {
      maxValue += 1;
      minValue -= 1;
    }
    final padding = math.max(0.8, (maxValue - minValue) * 0.12);
    minValue -= padding;
    maxValue += padding;
    final range = maxValue - minValue;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = chart.top + chart.height / 2 * i;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    _drawDashedLine(canvas, chart, _yFor(0, chart, minValue, range), gridColor);
    if (costValue != null) {
      _drawDashedLine(
        canvas,
        chart,
        _yFor(costValue, chart, minValue, range),
        _costColor.withValues(alpha: 0.72),
      );
    }

    final benchmarkPath = _benchmarkPath(chart, minValue, range);
    if (benchmarkPath != null) {
      canvas.drawPath(
        benchmarkPath,
        Paint()
          ..color = _benchmarkColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final fundPath = _fundPath(chart, fundValues, minValue, range);
    final fillPath = Path.from(fundPath)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = _fundColor.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      fundPath,
      Paint()
        ..color = _fundColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _drawTradeMarkers(canvas, chart, fundValues, minValue, range);
    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < points.length) {
      final x = _xForDate(chart, points[selected].navDate);
      final y = _yFor(fundValues[selected], chart, minValue, range);
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        Paint()
          ..color = _fundColor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = _fundColor);
    }

    _drawText(canvas, _percent(maxValue), Offset(0, chart.top - 22));
    _drawText(canvas, _percent(minValue), Offset(0, chart.bottom + 4));
    _drawText(
      canvas,
      _shortDate(axisStart),
      Offset(chart.left, chart.bottom + 28),
    );
    final middleDate = axisStart.add(
      Duration(days: axisEnd.difference(axisStart).inDays ~/ 2),
    );
    _drawText(
      canvas,
      _shortDate(middleDate),
      Offset(chart.center.dx - 22, chart.bottom + 28),
    );
    _drawText(
      canvas,
      _shortDate(axisEnd),
      Offset(chart.right - 44, chart.bottom + 28),
    );
  }

  Path _fundPath(
    Rect chart,
    List<double> values,
    double minValue,
    double range,
  ) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = _xForDate(chart, points[i].navDate);
      final y = _yFor(values[i], chart, minValue, range);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  Path? _benchmarkPath(Rect chart, double minValue, double range) {
    if (benchmarks.length < 2) return null;
    final values = _benchmarkReturnValues(benchmarks);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = _xForDate(chart, benchmarks[i].tradeDate);
      final y = _yFor(values[i], chart, minValue, range);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  void _drawDashedLine(Canvas canvas, Rect chart, double y, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    var x = chart.left;
    while (x < chart.right) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 9, chart.right), y),
        paint,
      );
      x += 15;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, {Color? color}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 86);
    painter.paint(canvas, offset);
  }

  void _drawTradeMarkers(
    Canvas canvas,
    Rect chart,
    List<double> values,
    double minValue,
    double range,
  ) {
    if (trades.isEmpty || points.length < 2) return;
    final markerPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final trade in trades) {
      final index = _nearestPointIndex(trade.tradeDate);
      if (index == null) continue;
      final x = _xForDate(chart, points[index].navDate);
      final y = _yFor(values[index], chart, minValue, range);
      final color = trade.isBuy
          ? const Color(0xFFFF4D67)
          : const Color(0xFF20C997);
      markerPaint.color = color;
      canvas.drawCircle(Offset(x, y), 5.5, markerPaint);
      canvas.drawCircle(Offset(x, y), 5.5, borderPaint);
      _drawText(
        canvas,
        trade.isBuy ? '买' : '卖',
        Offset(x - 5, y - 22),
        color: color,
      );
    }
  }

  int? _nearestPointIndex(DateTime tradeDate) {
    if (points.isEmpty) return null;
    var bestIndex = 0;
    var bestDistance = 1 << 30;
    for (var i = 0; i < points.length; i++) {
      final distance = points[i].navDate
          .difference(DateTime(tradeDate.year, tradeDate.month, tradeDate.day))
          .inDays
          .abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestDistance <= 7 ? bestIndex : null;
  }

  double _xForDate(Rect chart, DateTime date) {
    final totalDays = math.max(1, axisEnd.difference(axisStart).inDays);
    final days = date.difference(axisStart).inDays.clamp(0, totalDays);
    return chart.left + chart.width * days / totalDays;
  }

  double _yFor(double value, Rect chart, double minValue, double range) {
    return chart.bottom - (value - minValue) / range * chart.height;
  }

  @override
  bool shouldRepaint(covariant _FundNavCurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.benchmarks != benchmarks ||
        oldDelegate.trades != trades ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.axisStart != axisStart ||
        oldDelegate.axisEnd != axisEnd ||
        oldDelegate.costNav != costNav;
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: secondaryTextColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map(
              (item) => SizedBox(
                width: (MediaQuery.sizeOf(context).width - 64) / 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.value.startsWith('-')
                            ? const Color(0xFF20C997)
                            : item.value.startsWith('+')
                            ? const Color(0xFFFF4D67)
                            : primaryTextColor(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value);

  final String label;
  final String value;
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({required this.recommendation});

  final FundGridRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final color = recommendation.isBuy
        ? const Color(0xFFFF4D67)
        : const Color(0xFF20C997);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _recommendationLabel(recommendation),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.reason,
            style: TextStyle(color: secondaryTextColor(context), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '触发阈值 ${recommendation.thresholdPercent.toStringAsFixed(2)}%',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavListHeader extends StatelessWidget {
  const _NavListHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: secondaryTextColor(context),
      fontWeight: FontWeight.w900,
      fontSize: 13,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text('日期', style: style)),
          Expanded(
            child: Text('净值', textAlign: TextAlign.center, style: style),
          ),
          Expanded(
            child: Text('日涨幅', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.point});

  final FundNavPoint point;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor(context))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_fullDate(point.navDate))),
          Expanded(
            child: Text(
              point.unitNav.toStringAsFixed(4),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              _percent(point.dailyGrowthRate),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _profitColor(point.dailyGrowthRate),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double value, {bool signed = true}) {
  final sign = signed
      ? value > 0
            ? '+'
            : value < 0
            ? '-'
            : ''
      : '';
  return '$sign¥${value.abs().toStringAsFixed(2)}';
}

String _percent(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  return '$sign${value.abs().toStringAsFixed(2)}%';
}

String _recommendationLabel(FundGridRecommendation recommendation) {
  return recommendation.isBuy ? '下跌提醒' : '上涨提醒';
}

String _shortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month-$day';
}

String _fullDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

Color _profitColor(double value) {
  if (value > 0) return const Color(0xFFFF4D67);
  if (value < 0) return const Color(0xFF20C997);
  return const Color(0xFF94A3B8);
}

double? _fundReturn(List<FundNavPoint> points) {
  if (points.length < 2 || points.first.unitNav <= 0) return null;
  return _returnFromFirst(points, points.last.unitNav);
}

double? _benchmarkReturn(List<FundBenchmarkPoint> points) {
  if (points.length < 2 || points.first.close <= 0) return null;
  return (points.last.close / points.first.close - 1) * 100;
}

double _returnFromFirst(List<FundNavPoint> points, double value) {
  if (points.isEmpty || points.first.unitNav <= 0) return 0;
  return (value / points.first.unitNav - 1) * 100;
}

List<double> _fundReturnValues(List<FundNavPoint> points) {
  if (points.isEmpty || points.first.unitNav <= 0) return const [];
  final first = points.first.unitNav;
  return [for (final point in points) (point.unitNav / first - 1) * 100];
}

List<double> _benchmarkReturnValues(List<FundBenchmarkPoint> points) {
  if (points.isEmpty || points.first.close <= 0) return const [];
  final first = points.first.close;
  return [for (final point in points) (point.close / first - 1) * 100];
}

double _chartCostNav({
  required List<FundNavPoint> points,
  required List<FundTrade> trades,
  required double fallbackCostNav,
}) {
  if (points.isEmpty) return fallbackCostNav > 0 ? fallbackCostNav : 0;
  final navValues = points
      .map((point) => point.unitNav)
      .where((value) => value > 0)
      .toList();
  if (navValues.isEmpty) return fallbackCostNav > 0 ? fallbackCostNav : 0;
  final minNav = navValues.reduce(math.min);
  final maxNav = navValues.reduce(math.max);
  if (_isChartCostPlausible(fallbackCostNav, minNav: minNav, maxNav: maxNav)) {
    return fallbackCostNav;
  }
  final tradeCostNav = _costNavFromTrades(trades, upTo: points.last.navDate);
  if (_isChartCostPlausible(tradeCostNav, minNav: minNav, maxNav: maxNav)) {
    return tradeCostNav;
  }
  return 0;
}

double _costNavFromTrades(List<FundTrade> trades, {required DateTime upTo}) {
  final sorted =
      trades.where((trade) => !trade.tradeDate.isAfter(upTo)).toList()
        ..sort((a, b) => a.tradeDate.compareTo(b.tradeDate));
  var shares = 0.0;
  var investedAmount = 0.0;
  var avgCostNav = 0.0;
  for (final trade in sorted) {
    if (trade.shares <= 0 || trade.nav <= 0) continue;
    if (trade.isBuy) {
      investedAmount += trade.shares * trade.nav + trade.fee;
      shares += trade.shares;
      avgCostNav = shares > 0 ? investedAmount / shares : 0;
      continue;
    }
    final soldShares = math.min(trade.shares, shares);
    investedAmount = math.max(0, investedAmount - avgCostNav * soldShares);
    shares = math.max(0, shares - soldShares);
    avgCostNav = shares > 0 ? investedAmount / shares : 0;
  }
  return avgCostNav;
}

bool _isChartCostPlausible(
  double costNav, {
  required double minNav,
  required double maxNav,
}) {
  if (costNav <= 0 || minNav <= 0 || maxNav <= 0) return false;
  return costNav >= minNav * 0.6 && costNav <= maxNav * 1.4;
}
