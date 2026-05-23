import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/capital_flow.dart';
import '../../utils/theme_helpers.dart';

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
          Row(
            children: [
              Expanded(
                child: Text(
                  '资金流向',
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (data?.updateTime != null)
                Text(
                  _timeLabel(data!.updateTime!),
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
          ),
          const SizedBox(height: 10),
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
          else ...[
            _CapitalFlowSummary(snapshot: data),
            const SizedBox(height: 12),
            _CapitalFlowBuckets(snapshot: data),
            const SizedBox(height: 12),
            SizedBox(
              height: 126,
              child: data.points.length < 2
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
                        points: data.points,
                        currency: data.currency,
                        lineColor: _moneyColor(data.netInflow),
                        gridColor: borderColor(context),
                        labelColor: secondaryTextColor(context),
                      ),
                      child: const SizedBox.expand(),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CapitalFlowSummary extends StatelessWidget {
  const _CapitalFlowSummary({required this.snapshot});

  final CapitalFlowSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.totalInflow + snapshot.totalOutflow;
    final inflowRatio = total == 0 ? 0.0 : snapshot.totalInflow / total * 100;
    final outflowRatio = total == 0 ? 0.0 : snapshot.totalOutflow / total * 100;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当日净流入',
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMoney(snapshot.netInflow, snapshot.currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _moneyColor(snapshot.netInflow),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _FlowRatioChip(
          label: '流入',
          value: _formatMoney(snapshot.totalInflow, snapshot.currency),
          ratio: inflowRatio,
          color: const Color(0xFF12B886),
        ),
        const SizedBox(width: 8),
        _FlowRatioChip(
          label: '流出',
          value: _formatMoney(-snapshot.totalOutflow, snapshot.currency),
          ratio: outflowRatio,
          color: const Color(0xFFFF3B45),
        ),
      ],
    );
  }
}

class _FlowRatioChip extends StatelessWidget {
  const _FlowRatioChip({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final String label;
  final String value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ${ratio.toStringAsFixed(0)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapitalFlowBuckets extends StatelessWidget {
  const _CapitalFlowBuckets({required this.snapshot});

  final CapitalFlowSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final maxAbs = snapshot.buckets
        .map((bucket) => bucket.netInflow.abs())
        .fold<double>(1, math.max);
    return Column(
      children: [
        for (final bucket in snapshot.buckets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BucketRow(
              bucket: bucket,
              currency: snapshot.currency,
              maxAbs: maxAbs,
            ),
          ),
      ],
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({
    required this.bucket,
    required this.currency,
    required this.maxAbs,
  });

  final CapitalFlowBucket bucket;
  final String currency;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final color = _moneyColor(bucket.netInflow);
    final ratio = (bucket.netInflow.abs() / maxAbs).clamp(0.04, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            _bucketLabel(bucket.bucket),
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 9,
                decoration: BoxDecoration(
                  color: borderColor(context).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: Text(
            _formatMoney(bucket.netInflow, currency),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
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

class _CapitalFlowTrendPainter extends CustomPainter {
  const _CapitalFlowTrendPainter({
    required this.points,
    required this.currency,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<CapitalFlowPoint> points;
  final String currency;
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

    _drawLabel(canvas, _formatMoney(maxValue, currency), Offset(0, 0));
    _drawLabel(
      canvas,
      _formatMoney(minValue, currency),
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
        oldDelegate.currency != currency ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

Color _moneyColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF3B45);
}

String _bucketLabel(String bucket) {
  return switch (bucket) {
    'super' => '超大单',
    'big' => '大单',
    'mid' => '中单',
    'small' => '小单',
    _ => bucket,
  };
}

String _formatMoney(double value, String currency) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  final prefix = switch (currency.toUpperCase()) {
    'USD' => 'US\$',
    'CNY' => '¥',
    _ => 'HK\$',
  };
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '$sign$prefix${(absValue / 100000000).toStringAsFixed(2)}亿';
  }
  if (absValue >= 10000) {
    return '$sign$prefix${(absValue / 10000).toStringAsFixed(1)}万';
  }
  return '$sign$prefix${absValue.toStringAsFixed(0)}';
}

String _timeLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
