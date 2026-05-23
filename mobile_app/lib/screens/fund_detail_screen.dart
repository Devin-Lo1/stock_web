import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/fund_models.dart';
import '../repositories/fund_repository.dart';
import '../utils/theme_helpers.dart';

class FundDetailScreen extends StatefulWidget {
  const FundDetailScreen({
    super.key,
    required this.summary,
    required this.repository,
    required this.onBuy,
    required this.onSell,
    required this.onEditAlert,
    required this.onDelete,
  });

  final FundPositionSummary summary;
  final FundRepository repository;
  final VoidCallback onBuy;
  final VoidCallback onSell;
  final VoidCallback onEditAlert;
  final VoidCallback onDelete;

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  List<FundNavPoint> _navs = const [];
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
        limit: 50,
        refresh: refresh,
      );
      final tradesFuture = widget.repository.loadTrades(
        widget.summary.position.id,
        limit: 200,
      );
      final navs = await navsFuture;
      final trades = await tradesFuture;
      if (mounted) {
        setState(() {
          _navs = navs;
          _trades = trades;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingNavs = false);
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
                    Tab(text: '净值走势'),
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
                      navs: _navs,
                      trades: _trades,
                    ),
                    _ProfitTab(summary: summary),
                    _AlertTab(
                      summary: summary,
                      onBuy: widget.onBuy,
                      onSell: widget.onSell,
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

class _TrendTab extends StatelessWidget {
  const _TrendTab({
    required this.isLoading,
    required this.navs,
    required this.trades,
  });

  final bool isLoading;
  final List<FundNavPoint> navs;
  final List<FundTrade> trades;

  @override
  Widget build(BuildContext context) {
    final sorted = List<FundNavPoint>.of(navs)
      ..sort((a, b) => a.navDate.compareTo(b.navDate));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Container(
          height: 310,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor(context)),
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : sorted.length < 2
              ? Center(
                  child: Text(
                    '净值数据不足',
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : _FundNavCurve(points: sorted, trades: trades),
        ),
        const SizedBox(height: 12),
        ...sorted.reversed.map((point) => _NavRow(point: point)),
      ],
    );
  }
}

class _ProfitTab extends StatelessWidget {
  const _ProfitTab({required this.summary});

  final FundPositionSummary summary;

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
    required this.onBuy,
    required this.onSell,
    required this.onEditAlert,
    required this.onDelete,
  });

  final FundPositionSummary summary;
  final VoidCallback onBuy;
  final VoidCallback onSell;
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
            _MetricItem('下跌加仓', _money(position.alertBuyAmount)),
            _MetricItem('上涨减仓', _ratioLabel(position.alertSellRatio)),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onEditAlert,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('设置提醒规则'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onBuy,
                icon: const Icon(Icons.add_rounded),
                label: const Text('记录买入'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSell,
                icon: const Icon(Icons.remove_rounded),
                label: const Text('记录卖出'),
              ),
            ),
          ],
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

class _FundNavCurve extends StatefulWidget {
  const _FundNavCurve({required this.points, required this.trades});

  final List<FundNavPoint> points;
  final List<FundTrade> trades;

  @override
  State<_FundNavCurve> createState() => _FundNavCurveState();
}

class _FundNavCurveState extends State<_FundNavCurve> {
  int? _selectedIndex;

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
              trades: widget.trades,
              selectedIndex: _selectedIndex,
              lineColor: const Color(0xFFFF4D67),
              gridColor: borderColor(context),
              labelColor: secondaryTextColor(context),
            ),
            child: const SizedBox.expand(),
          ),
          if (selected != null)
            Positioned(
              left: 12,
              top: 10,
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
                    '${_fullDate(selected.navDate)}  ${selected.unitNav.toStringAsFixed(4)}  ${_percent(selected.dailyGrowthRate)}',
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
    if (widget.points.length < 2) return;
    final ratio = (dx / context.size!.width).clamp(0.0, 1.0);
    setState(
      () => _selectedIndex = (ratio * (widget.points.length - 1)).round(),
    );
  }
}

class _FundNavCurvePainter extends CustomPainter {
  const _FundNavCurvePainter({
    required this.points,
    required this.trades,
    required this.selectedIndex,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<FundNavPoint> points;
  final List<FundTrade> trades;
  final int? selectedIndex;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(8, 22, size.width - 16, size.height - 58);
    final values = points.map((point) => point.unitNav).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(0.0001, maxValue - minValue);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = chart.top + chart.height / 2 * i;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * i / (values.length - 1);
      final y = chart.bottom - (values[i] - minValue) / range * chart.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = lineColor.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    _drawTradeMarkers(canvas, chart, values, minValue, range);
    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < points.length) {
      final x = chart.left + chart.width * selected / (points.length - 1);
      final y =
          chart.bottom - (values[selected] - minValue) / range * chart.height;
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        Paint()
          ..color = lineColor.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = lineColor);
    }
    _drawText(canvas, maxValue.toStringAsFixed(4), Offset(0, chart.top - 18));
    _drawText(canvas, minValue.toStringAsFixed(4), Offset(0, chart.bottom + 4));
    _drawText(
      canvas,
      _shortDate(points.first.navDate),
      Offset(chart.left, chart.bottom + 26),
    );
    _drawText(
      canvas,
      _shortDate(points.last.navDate),
      Offset(chart.right - 44, chart.bottom + 26),
    );
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
    )..layout(maxWidth: 80);
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
      final x = chart.left + chart.width * index / (points.length - 1);
      final y =
          chart.bottom - (values[index] - minValue) / range * chart.height;
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

  @override
  bool shouldRepaint(covariant _FundNavCurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.trades != trades ||
        oldDelegate.selectedIndex != selectedIndex;
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
            recommendation.actionLabel,
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
            recommendation.isBuy
                ? '${_money(recommendation.recommendedAmount)} · 约 ${recommendation.recommendedShares.toStringAsFixed(2)} 份'
                : '约 ${recommendation.recommendedShares.toStringAsFixed(2)} 份 · ${_money(recommendation.recommendedAmount)}',
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

String _ratioLabel(double value) {
  if ((value - 0.25).abs() < 0.001) return '1/4';
  if ((value - 0.5).abs() < 0.001) return '1/2';
  return '${(value * 100).toStringAsFixed(0)}%';
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
