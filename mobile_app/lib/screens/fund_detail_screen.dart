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

enum _ProfitRange {
  oneMonth('近1月', 31),
  threeMonths('近3月', 93),
  sixMonths('近6月', 186),
  all('全部', 0);

  const _ProfitRange(this.label, this.calendarDays);

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
  final Future<void> Function(FundPositionSummary summary) onAdjust;
  final Future<void> Function(FundPositionSummary summary) onEditAlert;
  final Future<void> Function(FundPositionSummary summary) onDelete;

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  late FundPositionSummary _summary;
  List<FundNavPoint> _navs = const [];
  List<FundBenchmarkPoint> _benchmarks = const [];
  List<FundTrade> _trades = const [];
  List<FundTradeRecord> _records = const [];
  bool _isLoadingNavs = true;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
    unawaited(_loadNavs(refresh: true));
  }

  Future<void> _loadNavs({bool refresh = false}) async {
    setState(() => _isLoadingNavs = true);
    try {
      final navsFuture = widget.repository.loadNavs(
        _summary.position.fundCode,
        limit: _fundTrendNavLimit,
        refresh: refresh,
      );
      final benchmarksFuture = _loadBenchmarks();
      final tradesFuture = widget.repository.loadTrades(
        _summary.position.id,
        limit: 200,
      );
      final recordsFuture = widget.repository.loadTradeRecords(
        _summary.position.id,
        limit: 200,
      );
      final navs = await navsFuture;
      final benchmarks = await benchmarksFuture;
      final trades = await tradesFuture;
      final records = await recordsFuture;
      if (mounted) {
        setState(() {
          _navs = navs;
          _benchmarks = benchmarks;
          _trades = trades;
          _records = records;
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

  Future<void> _reloadSummary({bool refresh = false}) async {
    final summaries = await widget.repository.loadSummaries(refresh: refresh);
    for (final summary in summaries) {
      if (summary.position.id == _summary.position.id) {
        if (mounted) setState(() => _summary = summary);
        return;
      }
    }
  }

  Future<void> _reloadRecords() async {
    final records = await widget.repository.loadTradeRecords(
      _summary.position.id,
      limit: 200,
    );
    if (mounted) setState(() => _records = records);
  }

  Future<void> _handleAdjust() async {
    await widget.onAdjust(_summary);
    await _reloadSummary();
    await _loadNavs();
  }

  Future<void> _handleEditAlert() async {
    await widget.onEditAlert(_summary);
    await _reloadSummary();
  }

  Future<void> _handleDelete() async {
    await widget.onDelete(_summary);
  }

  Future<void> _handleAddRecord() async {
    final draft = await showModalBottomSheet<FundTradeRecordDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _FundTradeRecordSheet(summary: _summary),
    );
    if (draft == null) return;
    try {
      await widget.repository.createTradeRecord(_summary.position.id, draft);
      await _reloadRecords();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('交易记录已添加')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('交易记录添加失败：$error')));
      }
    }
  }

  Future<void> _handleDeleteRecord(FundTradeRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除交易记录'),
        content: const Text('只删除这条展示记录和图上买卖点，不会重算持仓、收益或策略参考。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteTradeRecord(
        _summary.position.id,
        record.id,
      );
      await _reloadRecords();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('交易记录已删除')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('交易记录删除失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
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
                      records: _records,
                    ),
                    _ProfitTab(
                      summary: summary,
                      navs: _navs,
                      trades: _trades,
                      isLoading: _isLoadingNavs,
                      onAdjust: () => unawaited(_handleAdjust()),
                    ),
                    _AlertTab(
                      summary: summary,
                      records: _records,
                      onAdjust: () => unawaited(_handleAdjust()),
                      onEditAlert: () => unawaited(_handleEditAlert()),
                      onAddRecord: () => unawaited(_handleAddRecord()),
                      onDeleteRecord: (record) =>
                          unawaited(_handleDeleteRecord(record)),
                      onDelete: () => unawaited(_handleDelete()),
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
    required this.records,
  });

  final bool isLoading;
  final FundPositionSummary summary;
  final List<FundNavPoint> navs;
  final List<FundBenchmarkPoint> benchmarks;
  final List<FundTrade> trades;
  final List<FundTradeRecord> records;

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
                    records: widget.records,
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

class _ProfitTab extends StatefulWidget {
  const _ProfitTab({
    required this.summary,
    required this.navs,
    required this.trades,
    required this.isLoading,
    required this.onAdjust,
  });

  final FundPositionSummary summary;
  final List<FundNavPoint> navs;
  final List<FundTrade> trades;
  final bool isLoading;
  final VoidCallback onAdjust;

  @override
  State<_ProfitTab> createState() => _ProfitTabState();
}

class _ProfitTabState extends State<_ProfitTab> {
  _ProfitRange _selectedRange = _ProfitRange.threeMonths;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final position = summary.position;
    final points = _filterProfitPoints(
      _buildProfitCurvePoints(
        summary: summary,
        navs: widget.navs,
        trades: widget.trades,
      ),
      _selectedRange,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _ProfitMetricStrip(
          items: [
            _ProfitMetricItem('份额', position.shares.toStringAsFixed(2)),
            _ProfitMetricItem('成本净值', position.avgCostNav.toStringAsFixed(4)),
            _ProfitMetricItem(
              summary.isEstimated ? '估算净值' : '正式净值',
              summary.displayNav.toStringAsFixed(4),
            ),
            _ProfitMetricItem('当日收益', _money(summary.dayProfit)),
            _ProfitMetricItem('持有收益', _money(summary.holdingProfit)),
            _ProfitMetricItem('收益率', _percent(summary.holdingProfitRate)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ProfitLegend(
              value: points.isEmpty ? summary.totalProfit : points.last.value,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onAdjust,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('修改持仓'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ProfitCurveCard(points: points, isLoading: widget.isLoading),
        const SizedBox(height: 12),
        _ProfitRangeSelector(
          selectedRange: _selectedRange,
          onChanged: (range) => setState(() => _selectedRange = range),
        ),
      ],
    );
  }
}

class _ProfitMetricStrip extends StatelessWidget {
  const _ProfitMetricStrip({required this.items});

  final List<_ProfitMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 2.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          for (final item in items)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.value,
                    maxLines: 1,
                    style: TextStyle(
                      color: _profitValueColor(context, item.value),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProfitMetricItem {
  const _ProfitMetricItem(this.label, this.value);

  final String label;
  final String value;
}

class _ProfitLegend extends StatelessWidget {
  const _ProfitLegend({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4D7CFE);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '累计收益',
          style: TextStyle(
            color: secondaryTextColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          _money(value),
          style: TextStyle(
            color: _profitColor(value),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProfitCurveCard extends StatelessWidget {
  const _ProfitCurveCard({required this.points, required this.isLoading});

  final List<_ProfitCurvePoint> points;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : points.length < 2
          ? Center(
              child: Text(
                '收益曲线需要至少两个确认日',
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : CustomPaint(
              painter: _ProfitCurvePainter(
                points: points,
                gridColor: borderColor(context).withValues(alpha: 0.55),
                labelColor: secondaryTextColor(context),
              ),
              child: const SizedBox.expand(),
            ),
    );
  }
}

class _ProfitCurvePainter extends CustomPainter {
  const _ProfitCurvePainter({
    required this.points,
    required this.gridColor,
    required this.labelColor,
  });

  static const _lineColor = Color(0xFF4D7CFE);

  final List<_ProfitCurvePoint> points;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(8, 24, size.width - 16, size.height - 58);
    final values = points.map((point) => point.value).toList();
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    if ((maxValue - minValue).abs() < 0.01) {
      maxValue += 10;
      minValue -= 10;
    }
    final padding = math.max(10.0, (maxValue - minValue).abs() * 0.12);
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
    if (minValue < 0 && maxValue > 0) {
      _drawDashedLine(canvas, chart, _yFor(0, chart, minValue, range));
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = _offsetFor(i, chart, minValue, range);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = _lineColor.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _lineColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final lastOffset = _offsetFor(points.length - 1, chart, minValue, range);
    canvas.drawCircle(lastOffset, 3.4, Paint()..color = _lineColor);

    _drawText(canvas, _compactMoney(maxValue), Offset(0, chart.top - 22));
    _drawText(canvas, _compactMoney(minValue), Offset(0, chart.bottom + 4));
    _drawText(
      canvas,
      _shortDate(points.first.date),
      Offset(chart.left, chart.bottom + 28),
    );
    _drawText(
      canvas,
      _shortDate(points[points.length ~/ 2].date),
      Offset(chart.center.dx - 22, chart.bottom + 28),
    );
    _drawText(
      canvas,
      _shortDate(points.last.date),
      Offset(chart.right - 44, chart.bottom + 28),
    );
  }

  Offset _offsetFor(int index, Rect chart, double minValue, double range) {
    final x = points.length == 1
        ? chart.left
        : chart.left + chart.width * index / (points.length - 1);
    final y = _yFor(points[index].value, chart, minValue, range);
    return Offset(x, y);
  }

  double _yFor(double value, Rect chart, double minValue, double range) {
    return chart.bottom - (value - minValue) / range * chart.height;
  }

  void _drawDashedLine(Canvas canvas, Rect chart, double y) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.85)
      ..strokeWidth = 1;
    var x = chart.left;
    while (x < chart.right) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 8, chart.right), y),
        paint,
      );
      x += 13;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 90);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ProfitCurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class _ProfitRangeSelector extends StatelessWidget {
  const _ProfitRangeSelector({
    required this.selectedRange,
    required this.onChanged,
  });

  final _ProfitRange selectedRange;
  final ValueChanged<_ProfitRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final range in _ProfitRange.values)
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

class _AlertTab extends StatelessWidget {
  const _AlertTab({
    required this.summary,
    required this.records,
    required this.onAdjust,
    required this.onEditAlert,
    required this.onAddRecord,
    required this.onDeleteRecord,
    required this.onDelete,
  });

  final FundPositionSummary summary;
  final List<FundTradeRecord> records;
  final VoidCallback onAdjust;
  final VoidCallback onEditAlert;
  final VoidCallback onAddRecord;
  final ValueChanged<FundTradeRecord> onDeleteRecord;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final position = summary.position;
    final recommendation = summary.gridRecommendation;
    final reference = summary.strategyReference;
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
            _MetricItem(
              '参考净值',
              reference == null ? '--' : reference.nav.toStringAsFixed(4),
            ),
            _MetricItem(
              '参考日期',
              reference?.tradeDate == null
                  ? '成本均值'
                  : _fullDate(reference!.tradeDate!),
            ),
            _MetricItem(
              '偏离幅度',
              reference == null ? '--' : _percent(reference.changeRate),
            ),
            const _MetricItem('操作数量', '自行决定'),
          ],
        ),
        const SizedBox(height: 12),
        _FundTradeRecordsPanel(
          records: records,
          onAddRecord: onAddRecord,
          onDeleteRecord: onDeleteRecord,
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

class _FundTradeRecordsPanel extends StatelessWidget {
  const _FundTradeRecordsPanel({
    required this.records,
    required this.onAddRecord,
    required this.onDeleteRecord,
  });

  final List<FundTradeRecord> records;
  final VoidCallback onAddRecord;
  final ValueChanged<FundTradeRecord> onDeleteRecord;

  @override
  Widget build(BuildContext context) {
    final visibleRecords = records.take(30).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '交易记录',
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAddRecord,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          Text(
            '用于展示历史操作和图上买卖点，不参与持仓、收益或策略参考计算。',
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (visibleRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '暂无交易记录',
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            for (var i = 0; i < visibleRecords.length; i++) ...[
              if (i > 0) Divider(color: borderColor(context), height: 1),
              _FundTradeRecordRow(
                record: visibleRecords[i],
                onDelete: () => onDeleteRecord(visibleRecords[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _FundTradeRecordRow extends StatelessWidget {
  const _FundTradeRecordRow({required this.record, required this.onDelete});

  final FundTradeRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = record.isSell
        ? const Color(0xFF20C997)
        : const Color(0xFFFF4D67);
    final amount = record.amount > 0
        ? _money(record.amount, signed: false)
        : '${record.shares.toStringAsFixed(2)}份';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_recordActionLabel(record)} · ${_fullDate(record.tradeDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '净值 ${record.nav.toStringAsFixed(4)} · 份额 ${record.shares.toStringAsFixed(2)} · $amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (record.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '删除记录',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: mutedIconColor(context),
          ),
        ],
      ),
    );
  }
}

class _FundTradeRecordSheet extends StatefulWidget {
  const _FundTradeRecordSheet({required this.summary});

  final FundPositionSummary summary;

  @override
  State<_FundTradeRecordSheet> createState() => _FundTradeRecordSheetState();
}

class _FundTradeRecordSheetState extends State<_FundTradeRecordSheet> {
  late final TextEditingController _navController;
  late final TextEditingController _sharesController;
  late final TextEditingController _amountController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;
  late DateTime _tradeDate;
  String _action = 'buy';

  @override
  void initState() {
    super.initState();
    final summary = widget.summary;
    _tradeDate = summary.latestNav?.navDate ?? DateTime.now();
    _navController = TextEditingController(
      text: summary.displayNav > 0 ? summary.displayNav.toStringAsFixed(4) : '',
    );
    _sharesController = TextEditingController();
    _amountController = TextEditingController();
    _feeController = TextEditingController(text: '0');
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _navController.dispose();
    _sharesController.dispose();
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _nav => double.tryParse(_navController.text.trim()) ?? 0;
  double get _shares => double.tryParse(_sharesController.text.trim()) ?? 0;
  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;
  double get _fee => double.tryParse(_feeController.text.trim()) ?? 0;

  bool get _canSubmit => _nav > 0 && (_shares > 0 || _amount > 0);

  Future<void> _pickDate() async {
    final next = await showDatePicker(
      context: context,
      initialDate: _tradeDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (next != null && mounted) {
      setState(() => _tradeDate = next);
    }
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      FundTradeRecordDraft(
        action: _action,
        shares: _shares,
        nav: _nav,
        amount: _amount,
        fee: _fee,
        tradeDate: _tradeDate,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '添加交易记录',
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '仅用于展示历史操作和图上买卖点，不会修改持仓、收益或策略参考。',
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                _RecordActionChip(
                  label: '加仓',
                  selected: _action == 'buy',
                  onSelected: () => setState(() => _action = 'buy'),
                ),
                _RecordActionChip(
                  label: '减仓',
                  selected: _action == 'sell',
                  onSelected: () => setState(() => _action = 'sell'),
                ),
                _RecordActionChip(
                  label: '修正',
                  selected: _action == 'correct',
                  onSelected: () => setState(() => _action = 'correct'),
                ),
                _RecordActionChip(
                  label: '定投',
                  selected: _action == 'recurring',
                  onSelected: () => setState(() => _action = 'recurring'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded),
              label: Text(_fullDate(_tradeDate)),
            ),
            const SizedBox(height: 12),
            _RecordNumberField(
              controller: _navController,
              label: '确认净值',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            _RecordNumberField(
              controller: _sharesController,
              label: '份额',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            _RecordNumberField(
              controller: _amountController,
              label: '金额（可选，空则按份额记录）',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            _RecordNumberField(
              controller: _feeController,
              label: '手续费',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: const Icon(Icons.check_rounded),
                label: const Text('保存记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordActionChip extends StatelessWidget {
  const _RecordActionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected ? appAccentColor(context) : secondaryTextColor(context),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _RecordNumberField extends StatelessWidget {
  const _RecordNumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
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
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            _LegendItem(
              color: const Color(0xFF4D7CFE),
              label: '本基金',
              value: fundReturn == null ? '--' : _percent(fundReturn),
            ),
            const SizedBox(width: 10),
            _LegendItem(
              color: const Color(0xFFEA8A35),
              label: '沪深300',
              value: benchmarkReturn == null ? '--' : _percent(benchmarkReturn),
            ),
            const SizedBox(width: 10),
            _LegendItem(
              color: secondaryTextColor(context),
              label: '成本价',
              value: costNav > 0 ? costNav.toStringAsFixed(4) : '--',
              dashed: true,
            ),
          ],
        ),
      ),
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
          size: const Size(14, 6),
          painter: _LegendLinePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: secondaryTextColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: value.startsWith('--') ? secondaryTextColor(context) : color,
            fontSize: 12,
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
      ..strokeWidth = 1.5
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
    required this.records,
    required this.axisStart,
    required this.axisEnd,
    required this.costNav,
  });

  final List<FundNavPoint> points;
  final List<FundBenchmarkPoint> benchmarks;
  final List<FundTradeRecord> records;
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
              records: widget.records,
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
    required this.records,
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
  final List<FundTradeRecord> records;
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
      final costY = _yFor(costValue, chart, minValue, range);
      final costVisible = costY >= chart.top && costY <= chart.bottom;
      if (costVisible) {
        _drawDashedLine(
          canvas,
          chart,
          costY,
          _costColor.withValues(alpha: 0.72),
        );
      }
    }

    final benchmarkPath = _benchmarkPath(chart, minValue, range);
    if (benchmarkPath != null) {
      canvas.drawPath(
        benchmarkPath,
        Paint()
          ..color = _benchmarkColor
          ..strokeWidth = 1.4
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
        ..strokeWidth = 1.8
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
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = _fundColor);
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
    if (records.isEmpty || points.length < 2) return;
    final markerPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    for (final record in records) {
      final index = _exactPointIndex(record.tradeDate);
      if (index == null) continue;
      final x = _xForDate(chart, points[index].navDate);
      final y = _yFor(values[index], chart, minValue, range);
      final color = record.isBuy
          ? const Color(0xFFFF4D67)
          : const Color(0xFF20C997);
      markerPaint.color = color;
      canvas.drawCircle(Offset(x, y), 3.8, markerPaint);
      canvas.drawCircle(Offset(x, y), 3.8, borderPaint);
    }
  }

  int? _exactPointIndex(DateTime tradeDate) {
    if (points.isEmpty) return null;
    final markerDate = DateTime(tradeDate.year, tradeDate.month, tradeDate.day);
    for (var i = 0; i < points.length; i++) {
      final pointDate = points[i].navDate;
      if (pointDate.year == markerDate.year &&
          pointDate.month == markerDate.month &&
          pointDate.day == markerDate.day) {
        return i;
      }
    }
    return null;
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
        oldDelegate.records != records ||
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

String _recordActionLabel(FundTradeRecord record) {
  switch (record.action) {
    case 'buy':
      return '加仓';
    case 'sell':
      return '减仓';
    case 'correct':
      return '修正';
    case 'recurring':
      return '定投';
    case 'convert':
      return '转换';
  }
  return '记录';
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
  final tradeCostNav = _costNavFromTrades(
    trades,
    upTo: points.last.navDate,
    minNav: minNav,
    maxNav: maxNav,
  );
  if (_isChartCostPlausible(tradeCostNav, minNav: minNav, maxNav: maxNav)) {
    return tradeCostNav;
  }
  return 0;
}

double _costNavFromTrades(
  List<FundTrade> trades, {
  required DateTime upTo,
  required double minNav,
  required double maxNav,
}) {
  final sorted =
      trades.where((trade) => !trade.tradeDate.isAfter(upTo)).toList()
        ..sort((a, b) => a.tradeDate.compareTo(b.tradeDate));
  var shares = 0.0;
  var investedAmount = 0.0;
  var avgCostNav = 0.0;
  for (final trade in sorted) {
    if (trade.shares <= 0 || trade.nav <= 0) continue;
    if (!_isChartCostPlausible(trade.nav, minNav: minNav, maxNav: maxNav)) {
      continue;
    }
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

class _ProfitCurvePoint {
  const _ProfitCurvePoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

List<_ProfitCurvePoint> _buildProfitCurvePoints({
  required FundPositionSummary summary,
  required List<FundNavPoint> navs,
  required List<FundTrade> trades,
}) {
  final sortedNavs = navs.where((point) => point.unitNav > 0).toList()
    ..sort((a, b) => a.navDate.compareTo(b.navDate));
  if (sortedNavs.isEmpty) {
    return summary.displayNav > 0
        ? [
            _ProfitCurvePoint(
              date: summary.latestNav?.navDate ?? DateTime.now(),
              value: summary.totalProfit,
            ),
          ]
        : const [];
  }

  final sortedTrades = _sortedProfitTrades(trades);
  if (sortedTrades.isEmpty) {
    return _positionCostCurve(summary, sortedNavs);
  }

  final points = <_ProfitCurvePoint>[];
  var shares = 0.0;
  var investedAmount = 0.0;
  var realizedProfit = 0.0;
  var avgCostNav = 0.0;
  var tradeIndex = 0;

  for (final nav in sortedNavs) {
    while (tradeIndex < sortedTrades.length &&
        !sortedTrades[tradeIndex].tradeDate.isAfter(nav.navDate)) {
      final state = _applyProfitTrade(
        trade: sortedTrades[tradeIndex],
        shares: shares,
        investedAmount: investedAmount,
        realizedProfit: realizedProfit,
        avgCostNav: avgCostNav,
      );
      shares = state.shares;
      investedAmount = state.investedAmount;
      realizedProfit = state.realizedProfit;
      avgCostNav = state.avgCostNav;
      tradeIndex += 1;
    }
    if (shares <= 0 && realizedProfit == 0) continue;
    points.add(
      _ProfitCurvePoint(
        date: nav.navDate,
        value: shares * nav.unitNav - investedAmount + realizedProfit,
      ),
    );
  }

  _mergeSummaryProfitPoint(points, summary);
  return points;
}

List<FundTrade> _sortedProfitTrades(List<FundTrade> trades) {
  final indexed = trades
      .asMap()
      .entries
      .where((entry) => entry.value.shares > 0 && entry.value.nav > 0)
      .toList();
  indexed.sort((a, b) {
    final dateCompare = a.value.tradeDate.compareTo(b.value.tradeDate);
    if (dateCompare != 0) return dateCompare;
    return b.key.compareTo(a.key);
  });
  return [for (final entry in indexed) entry.value];
}

List<_ProfitCurvePoint> _positionCostCurve(
  FundPositionSummary summary,
  List<FundNavPoint> sortedNavs,
) {
  final position = summary.position;
  if (position.shares <= 0 || position.investedAmount <= 0) {
    return const [];
  }
  final points = [
    for (final nav in sortedNavs)
      _ProfitCurvePoint(
        date: nav.navDate,
        value:
            position.shares * nav.unitNav -
            position.investedAmount +
            position.realizedProfit,
      ),
  ];
  _mergeSummaryProfitPoint(points, summary);
  return points;
}

void _mergeSummaryProfitPoint(
  List<_ProfitCurvePoint> points,
  FundPositionSummary summary,
) {
  if (summary.displayNav <= 0) return;
  final date = summary.displayTime == null
      ? summary.latestNav?.navDate
      : DateTime(
          summary.displayTime!.year,
          summary.displayTime!.month,
          summary.displayTime!.day,
        );
  if (date == null) return;
  final point = _ProfitCurvePoint(date: date, value: summary.totalProfit);
  if (points.isEmpty) {
    points.add(point);
    return;
  }
  final last = points.last;
  final sameDate =
      last.date.year == date.year &&
      last.date.month == date.month &&
      last.date.day == date.day;
  if (sameDate) {
    points[points.length - 1] = point;
  } else if (date.isAfter(last.date)) {
    points.add(point);
  }
}

_ProfitReplayState _applyProfitTrade({
  required FundTrade trade,
  required double shares,
  required double investedAmount,
  required double realizedProfit,
  required double avgCostNav,
}) {
  if (trade.isBuy) {
    final nextInvested = investedAmount + trade.shares * trade.nav + trade.fee;
    final nextShares = shares + trade.shares;
    return _ProfitReplayState(
      shares: nextShares,
      investedAmount: nextInvested,
      realizedProfit: realizedProfit,
      avgCostNav: nextShares > 0 ? nextInvested / nextShares : 0,
    );
  }
  final soldShares = math.min(trade.shares, shares);
  final costBasis = avgCostNav * soldShares;
  final proceeds = soldShares * trade.nav - trade.fee;
  final nextShares = math.max(0.0, shares - soldShares);
  final nextInvested = math.max(0.0, investedAmount - costBasis);
  return _ProfitReplayState(
    shares: nextShares,
    investedAmount: nextInvested,
    realizedProfit: realizedProfit + proceeds - costBasis,
    avgCostNav: nextShares > 0 ? nextInvested / nextShares : 0,
  );
}

class _ProfitReplayState {
  const _ProfitReplayState({
    required this.shares,
    required this.investedAmount,
    required this.realizedProfit,
    required this.avgCostNav,
  });

  final double shares;
  final double investedAmount;
  final double realizedProfit;
  final double avgCostNav;
}

List<_ProfitCurvePoint> _filterProfitPoints(
  List<_ProfitCurvePoint> points,
  _ProfitRange range,
) {
  if (points.length < 2 || range == _ProfitRange.all) return points;
  final latest = points.last.date;
  final start = latest.subtract(Duration(days: range.calendarDays));
  final filtered = points
      .where((point) => !point.date.isBefore(start))
      .toList();
  if (filtered.length >= 2) return filtered;
  return points.sublist(math.max(0, points.length - 2));
}

Color _profitValueColor(BuildContext context, String value) {
  if (value.startsWith('-')) return const Color(0xFF20C997);
  if (value.startsWith('+')) return const Color(0xFFFF4D67);
  return primaryTextColor(context);
}

String _compactMoney(double value) {
  final sign = value < 0 ? '-' : '';
  final absValue = value.abs();
  if (absValue >= 10000) {
    return '$sign${(absValue / 10000).toStringAsFixed(2)}万';
  }
  return '$sign${absValue.toStringAsFixed(2)}';
}
