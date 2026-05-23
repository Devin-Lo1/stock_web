import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/capital_flow.dart';
import '../../utils/theme_helpers.dart';

const _inflowColors = [Color(0xFF059669), Color(0xFF10B981), Color(0xFF5BD6AC)];
const _outflowColors = [
  Color(0xFFDC2626),
  Color(0xFFFF3B45),
  Color(0xFFFF8A93),
];

class CapitalFlowPanel extends StatelessWidget {
  const CapitalFlowPanel({
    super.key,
    required this.snapshot,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final CapitalFlowSnapshot? snapshot;
  final bool isLoading;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
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
          _CapitalFlowHeader(
            snapshot: data,
            isLoading: isLoading,
            onRetry: onRetry,
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (error != null)
            _CapitalFlowNotice(
              icon: Icons.error_outline_rounded,
              title: '资金流加载失败',
              subtitle: '请确认 FutuOpenD、行情权限或稍后刷新。',
              onRetry: onRetry,
            )
          else if (data == null || !data.hasData)
            _CapitalFlowNotice(
              icon: Icons.waterfall_chart_rounded,
              title: '暂无资金流数据',
              subtitle: '当前标的暂未返回资金分布或日内资金曲线。',
              onRetry: onRetry,
            )
          else
            _CapitalFlowContent(snapshot: data),
        ],
      ),
    );
  }
}

class _CapitalFlowHeader extends StatelessWidget {
  const _CapitalFlowHeader({
    required this.snapshot,
    required this.isLoading,
    required this.onRetry,
  });

  final CapitalFlowSnapshot? snapshot;
  final bool isLoading;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final updateTime = snapshot?.updateTime;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                '今日资金流向',
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: secondaryTextColor(context),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              updateTime == null ? '更新时间 --' : '更新时间:${_dateLabel(updateTime)}',
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '(万元 | ${snapshot?.currency ?? '--'})',
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          tooltip: '刷新资金流',
          visualDensity: VisualDensity.compact,
          onPressed: isLoading ? null : onRetry,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
        ),
      ],
    );
  }
}

class _CapitalFlowContent extends StatelessWidget {
  const _CapitalFlowContent({required this.snapshot});

  final CapitalFlowSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final groups = _bucketGroups(snapshot);
    final total = snapshot.totalInflow + snapshot.totalOutflow;
    final inflowRatio = total == 0 ? 0.0 : snapshot.totalInflow / total * 100;
    final outflowRatio = total == 0 ? 0.0 : snapshot.totalOutflow / total * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 184,
          child: Center(
            child: CustomPaint(
              size: const Size(176, 176),
              painter: _CapitalFlowDonutPainter(
                groups: groups,
                netInflow: snapshot.netInflow,
                totalInflow: snapshot.totalInflow,
                totalOutflow: snapshot.totalOutflow,
                primaryTextColor: primaryTextColor(context),
                secondaryTextColor: secondaryTextColor(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FlowLegendColumn(
                title: '流入',
                amount: snapshot.totalInflow,
                ratio: inflowRatio,
                groups: groups,
                inbound: true,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _FlowLegendColumn(
                title: '流出',
                amount: snapshot.totalOutflow,
                ratio: outflowRatio,
                groups: groups,
                inbound: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 142,
          child: CustomPaint(
            painter: _CapitalFlowBarPainter(
              groups: groups,
              labelColor: secondaryTextColor(context),
              gridColor: borderColor(context),
              textColor: primaryTextColor(context),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '资金流向趋势',
          style: TextStyle(
            color: primaryTextColor(context),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: snapshot.points.length < 2
              ? Center(
                  child: Text(
                    '日内趋势不足',
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : CustomPaint(
                  painter: _CapitalFlowTrendPainter(
                    points: snapshot.points,
                    lineColor: _moneyColor(snapshot.netInflow),
                    gridColor: borderColor(context),
                    labelColor: secondaryTextColor(context),
                  ),
                  child: const SizedBox.expand(),
                ),
        ),
      ],
    );
  }
}

class _FlowLegendColumn extends StatelessWidget {
  const _FlowLegendColumn({
    required this.title,
    required this.amount,
    required this.ratio,
    required this.groups,
    required this.inbound,
  });

  final String title;
  final double amount;
  final double ratio;
  final List<_CapitalFlowGroup> groups;
  final bool inbound;

  @override
  Widget build(BuildContext context) {
    final total = inbound
        ? groups.fold<double>(0, (sum, group) => sum + group.inflow)
        : groups.fold<double>(0, (sum, group) => sum + group.outflow);
    final colors = inbound ? _inflowColors : _outflowColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _formatWan(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: inbound ? _inflowColors[1] : _outflowColors[1],
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${ratio.toStringAsFixed(0)}%',
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < groups.length; index++) ...[
          _LegendItem(
            color: colors[index],
            label: groups[index].label,
            ratio: total == 0
                ? 0
                : (inbound ? groups[index].inflow : groups[index].outflow) /
                      total *
                      100,
          ),
          if (index != groups.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.ratio,
  });

  final Color color;
  final String label;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.rectangle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '${ratio.toStringAsFixed(0)}%',
          style: TextStyle(
            color: primaryTextColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CapitalFlowNotice extends StatelessWidget {
  const _CapitalFlowNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: secondaryTextColor(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _CapitalFlowDonutPainter extends CustomPainter {
  const _CapitalFlowDonutPainter({
    required this.groups,
    required this.netInflow,
    required this.totalInflow,
    required this.totalOutflow,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  final List<_CapitalFlowGroup> groups;
  final double netInflow;
  final double totalInflow;
  final double totalOutflow;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 17;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = totalInflow + totalOutflow;
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 31
      ..strokeCap = StrokeCap.butt;

    final segments = <_FlowSegment>[
      for (var index = 0; index < groups.length; index++)
        _FlowSegment(groups[index].inflow, _inflowColors[index]),
      for (var index = 0; index < groups.length; index++)
        _FlowSegment(groups[index].outflow, _outflowColors[index]),
    ];

    if (total <= 0) {
      paint.color = secondaryTextColor.withValues(alpha: 0.16);
      canvas.drawCircle(center, radius, paint);
    } else {
      for (final segment in segments) {
        if (segment.value <= 0) continue;
        final sweep = segment.value / total * math.pi * 2;
        paint.color = segment.color;
        canvas.drawArc(rect, start, sweep, false, paint);
        start += sweep;
      }
    }

    _drawCenterText(
      canvas,
      center,
      _formatWan(netInflow, showSign: true),
      netInflow >= 0 ? '净流入' : '净流出',
      _moneyColor(netInflow),
      secondaryTextColor,
    );
  }

  void _drawCenterText(
    Canvas canvas,
    Offset center,
    String value,
    String label,
    Color valueColor,
    Color labelColor,
  ) {
    final valuePainter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: valueColor,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 120);
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: labelColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 120);
    valuePainter.paint(
      canvas,
      center - Offset(valuePainter.width / 2, valuePainter.height + 1),
    );
    labelPainter.paint(canvas, center + Offset(-labelPainter.width / 2, 3));
  }

  @override
  bool shouldRepaint(covariant _CapitalFlowDonutPainter oldDelegate) {
    return oldDelegate.groups != groups ||
        oldDelegate.netInflow != netInflow ||
        oldDelegate.totalInflow != totalInflow ||
        oldDelegate.totalOutflow != totalOutflow ||
        oldDelegate.primaryTextColor != primaryTextColor ||
        oldDelegate.secondaryTextColor != secondaryTextColor;
  }
}

class _CapitalFlowBarPainter extends CustomPainter {
  const _CapitalFlowBarPainter({
    required this.groups,
    required this.labelColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<_CapitalFlowGroup> groups;
  final Color labelColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxAbs = groups
        .map((group) => group.net.abs())
        .fold<double>(1, math.max);
    final baseline = size.height * 0.66;
    final chartTop = 18.0;
    final chartBottom = size.height - 24;
    final positiveHeight = baseline - chartTop;
    final negativeHeight = chartBottom - baseline;
    final slotWidth = size.width / groups.length;
    final barWidth = math.min(52.0, slotWidth * 0.48);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      gridPaint,
    );

    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      final centerX = slotWidth * index + slotWidth / 2;
      final ratio = group.net.abs() / maxAbs;
      final height = math.max(
        4.0,
        ratio * (group.net >= 0 ? positiveHeight : negativeHeight),
      );
      final rect = group.net >= 0
          ? Rect.fromLTWH(
              centerX - barWidth / 2,
              baseline - height,
              barWidth,
              height,
            )
          : Rect.fromLTWH(centerX - barWidth / 2, baseline, barWidth, height);
      final color = _moneyColor(group.net);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = color,
      );
      _drawText(
        canvas,
        _formatWan(group.net, showSign: false),
        Offset(centerX, group.net >= 0 ? rect.top - 21 : rect.bottom + 4),
        color,
        12,
        FontWeight.w900,
      );
      _drawText(
        canvas,
        '净${group.label}',
        Offset(centerX, size.height - 18),
        textColor,
        12,
        FontWeight.w800,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color,
    double fontSize,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 96);
    painter.paint(canvas, Offset(anchor.dx - painter.width / 2, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _CapitalFlowBarPainter oldDelegate) {
    return oldDelegate.groups != groups ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}

class _CapitalFlowTrendPainter extends CustomPainter {
  const _CapitalFlowTrendPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<CapitalFlowPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((point) => point.netInflow).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : maxValue - minValue;
    final chart = Rect.fromLTWH(0, 8, size.width, size.height - 30);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 2; index++) {
      final y = chart.top + chart.height / 2 * index;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = chart.left + chart.width * index / (values.length - 1);
      final y =
          chart.bottom - (values[index] - minValue) / range * chart.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _drawLabel(canvas, _formatWan(maxValue, showSign: true), Offset(0, 0));
    _drawLabel(
      canvas,
      _formatWan(minValue, showSign: true),
      Offset(0, size.height - 18),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CapitalFlowTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class _CapitalFlowGroup {
  const _CapitalFlowGroup({
    required this.label,
    required this.inflow,
    required this.outflow,
  });

  final String label;
  final double inflow;
  final double outflow;

  double get net => inflow - outflow;
}

class _FlowSegment {
  const _FlowSegment(this.value, this.color);

  final double value;
  final Color color;
}

List<_CapitalFlowGroup> _bucketGroups(CapitalFlowSnapshot snapshot) {
  final byKey = {for (final bucket in snapshot.buckets) bucket.bucket: bucket};
  final superBucket = byKey['super'];
  final bigBucket = byKey['big'];
  final midBucket = byKey['mid'];
  final smallBucket = byKey['small'];

  return [
    _CapitalFlowGroup(
      label: '大单',
      inflow: (superBucket?.inflow ?? 0) + (bigBucket?.inflow ?? 0),
      outflow: (superBucket?.outflow ?? 0) + (bigBucket?.outflow ?? 0),
    ),
    _CapitalFlowGroup(
      label: '中单',
      inflow: midBucket?.inflow ?? 0,
      outflow: midBucket?.outflow ?? 0,
    ),
    _CapitalFlowGroup(
      label: '小单',
      inflow: smallBucket?.inflow ?? 0,
      outflow: smallBucket?.outflow ?? 0,
    ),
  ];
}

Color _moneyColor(double value) {
  return value >= 0 ? const Color(0xFF10B981) : const Color(0xFFFF3B45);
}

String _formatWan(double value, {bool showSign = false}) {
  final sign = showSign
      ? value > 0
            ? '+'
            : value < 0
            ? '-'
            : ''
      : '';
  final scaled = value.abs() / 10000;
  final text = scaled >= 1000
      ? _withComma(scaled.toStringAsFixed(1))
      : scaled.toStringAsFixed(1);
  return '$sign$text';
}

String _withComma(String value) {
  final parts = value.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) buffer.write(',');
    buffer.write(whole[index]);
  }
  if (parts.length > 1) buffer.write('.${parts[1]}');
  return buffer.toString();
}

String _dateLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
