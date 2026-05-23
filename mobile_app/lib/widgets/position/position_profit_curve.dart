import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/position_snapshot.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';

const _curveLeftPadding = 66.0;
const _curveRightPadding = 8.0;
const _curveTopPadding = 30.0;
const _curveBottomPadding = 38.0;
const _selectedBubbleWidth = 154.0;

class PositionProfitCurve extends StatefulWidget {
  const PositionProfitCurve({super.key, required this.snapshots});

  final List<PositionSnapshot> snapshots;

  @override
  State<PositionProfitCurve> createState() => _PositionProfitCurveState();
}

class _PositionProfitCurveState extends State<PositionProfitCurve> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final points = List<PositionSnapshot>.of(widget.snapshots)
      ..sort((a, b) {
        final left = a.snapshotTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.snapshotTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });
    final selectedIndex =
        _selectedIndex != null && _selectedIndex! < points.length
        ? _selectedIndex
        : null;

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
            Expanded(
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final chart = _curveChartRect(size);
                  final selectedSnapshot = selectedIndex == null
                      ? null
                      : points[selectedIndex];
                  final selectedX = selectedIndex == null
                      ? null
                      : chart.left +
                            chart.width * selectedIndex / (points.length - 1);
                  final bubbleLeft = selectedX == null
                      ? 0.0
                      : (selectedX - _selectedBubbleWidth / 2)
                            .clamp(
                              0.0,
                              math.max(0, size.width - _selectedBubbleWidth),
                            )
                            .toDouble();

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _selectSnapshot(
                      details.localPosition.dx,
                      size.width,
                      points.length,
                    ),
                    onHorizontalDragUpdate: (details) => _selectSnapshot(
                      details.localPosition.dx,
                      size.width,
                      points.length,
                    ),
                    child: Stack(
                      children: [
                        CustomPaint(
                          painter: _PositionProfitCurvePainter(
                            snapshots: points,
                            selectedIndex: selectedIndex,
                            lineColor: Theme.of(context).colorScheme.primary,
                            gridColor: borderColor(context),
                            labelColor: secondaryTextColor(context),
                          ),
                          child: const SizedBox.expand(),
                        ),
                        if (selectedSnapshot != null)
                          Positioned(
                            left: bubbleLeft,
                            top: 0,
                            width: _selectedBubbleWidth,
                            child: _SelectedSnapshotBubble(
                              snapshot: selectedSnapshot,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _selectSnapshot(double localX, double width, int count) {
    if (count < 2 || width <= 0) return;
    final chart = _curveChartRect(Size(width, 100));
    final ratio = ((localX - chart.left) / chart.width).clamp(0.0, 1.0);
    final index = (ratio * (count - 1)).round();
    setState(() => _selectedIndex = index);
  }
}

class _PositionProfitCurvePainter extends CustomPainter {
  const _PositionProfitCurvePainter({
    required this.snapshots,
    required this.selectedIndex,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<PositionSnapshot> snapshots;
  final int? selectedIndex;
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
    final chart = _curveChartRect(size);

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

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < values.length) {
      final x = chart.left + chart.width * selected / (values.length - 1);
      final y =
          chart.bottom - (values[selected] - minValue) / range * chart.height;
      final markerPaint = Paint()
        ..color = lineColor
        ..strokeWidth = 1.4;
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        markerPaint,
      );
      canvas.drawCircle(
        Offset(x, y),
        7,
        Paint()
          ..color = lineColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = lineColor);
    }

    _drawLabel(
      canvas,
      formatHkd(maxValue, decimals: 0),
      Offset(0, chart.top - 7),
    );
    _drawLabel(
      canvas,
      formatHkd(minValue, decimals: 0),
      Offset(0, chart.bottom - 9),
    );
    _drawDateLabel(
      canvas,
      _axisDateLabel(snapshots.first.snapshotTime),
      Offset(chart.left, chart.bottom + 12),
      TextAlign.left,
    );
    _drawDateLabel(
      canvas,
      _axisDateLabel(snapshots[snapshots.length ~/ 2].snapshotTime),
      Offset(chart.center.dx, chart.bottom + 12),
      TextAlign.center,
    );
    _drawDateLabel(
      canvas,
      _axisDateLabel(snapshots.last.snapshotTime),
      Offset(chart.right, chart.bottom + 12),
      TextAlign.right,
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

  void _drawDateLabel(
    Canvas canvas,
    String text,
    Offset anchor,
    TextAlign align,
  ) {
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
      textAlign: align,
    )..layout(maxWidth: 70);
    final dx = switch (align) {
      TextAlign.center => anchor.dx - painter.width / 2,
      TextAlign.right => anchor.dx - painter.width,
      _ => anchor.dx,
    };
    painter.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _PositionProfitCurvePainter oldDelegate) {
    return oldDelegate.snapshots != snapshots ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class _SelectedSnapshotBubble extends StatelessWidget {
  const _SelectedSnapshotBubble({required this.snapshot});

  final PositionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fullDateLabel(snapshot.snapshotTime),
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatHkd(snapshot.totalProfit, decimals: 2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: snapshot.totalProfit >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFFF3B45),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Rect _curveChartRect(Size size) {
  final width = math.max(
    1.0,
    size.width - _curveLeftPadding - _curveRightPadding,
  );
  final height = math.max(
    1.0,
    size.height - _curveTopPadding - _curveBottomPadding,
  );
  return Rect.fromLTWH(_curveLeftPadding, _curveTopPadding, width, height);
}

String _axisDateLabel(DateTime? value) {
  if (value == null) return '--';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month/$day';
}

String _fullDateLabel(DateTime? value) {
  if (value == null) return '--';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}
