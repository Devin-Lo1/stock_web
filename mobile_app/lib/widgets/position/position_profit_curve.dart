import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/position_snapshot.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';

class PositionProfitCurve extends StatelessWidget {
  const PositionProfitCurve({super.key, required this.snapshots});

  final List<PositionSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final points = List<PositionSnapshot>.of(snapshots)
      ..sort((a, b) {
        final left = a.snapshotTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.snapshotTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });
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
            '单股收益曲线',
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (points.length < 2)
            SizedBox(
              height: 96,
              child: Center(
                child: Text(
                  '收益快照不足',
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 128,
              child: CustomPaint(
                painter: _PositionProfitCurvePainter(
                  snapshots: points,
                  lineColor: Theme.of(context).colorScheme.primary,
                  gridColor: borderColor(context),
                  labelColor: secondaryTextColor(context),
                ),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

class _PositionProfitCurvePainter extends CustomPainter {
  const _PositionProfitCurvePainter({
    required this.snapshots,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<PositionSnapshot> snapshots;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final values = snapshots.map((snapshot) => snapshot.totalProfit).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : maxValue - minValue;
    final chart = Rect.fromLTWH(0, 4, size.width, size.height - 28);

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

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    _drawLabel(canvas, formatHkd(maxValue, decimals: 0), Offset(0, 0));
    _drawLabel(
      canvas,
      formatHkd(minValue, decimals: 0),
      Offset(0, size.height - 20),
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
  bool shouldRepaint(covariant _PositionProfitCurvePainter oldDelegate) {
    return oldDelegate.snapshots != snapshots ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}
