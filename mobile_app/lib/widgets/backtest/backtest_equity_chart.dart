import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';

class BacktestEquityChart extends StatelessWidget {
  const BacktestEquityChart({super.key, required this.points});

  final List<BacktestEquityPoint> points;

  @override
  Widget build(BuildContext context) {
    final accent = appAccentColor(context);
    final fillAlpha = isDarkMode(context) ? 0.12 : 0.08;
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: CustomPaint(
        painter: _EquityChartPainter(
          points: points,
          gridColor: borderColor(context).withValues(alpha: 0.62),
          textColor: secondaryTextColor(context),
          lineColor: accent,
          fillColor: accent.withValues(alpha: fillAlpha),
          axisColor: mutedIconColor(context).withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _EquityChartPainter extends CustomPainter {
  const _EquityChartPainter({
    required this.points,
    required this.gridColor,
    required this.textColor,
    required this.lineColor,
    required this.fillColor,
    required this.axisColor,
  });

  final List<BacktestEquityPoint> points;
  final Color gridColor;
  final Color textColor;
  final Color lineColor;
  final Color fillColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paintArea = Rect.fromLTWH(0, 12, size.width, size.height - 34);
    _drawGrid(canvas, paintArea);
    if (points.length < 2) {
      _drawEmpty(canvas, size);
      return;
    }

    final minEquity = points.map((point) => point.equity).reduce(math.min);
    final maxEquity = points.map((point) => point.equity).reduce(math.max);
    final range = (maxEquity - minEquity).abs() < 0.0001
        ? 1.0
        : maxEquity - minEquity;
    final path = Path();
    final fillPath = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = paintArea.left + paintArea.width * index / (points.length - 1);
      final y =
          paintArea.bottom -
          (point.equity - minEquity) / range * paintArea.height;
      if (index == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, paintArea.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      if (index == points.length - 1) {
        fillPath.lineTo(x, paintArea.bottom);
        fillPath.close();
      }
    }

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.4,
    );

    _drawLabels(canvas, paintArea, minEquity, maxEquity);
  }

  void _drawGrid(Canvas canvas, Rect area) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), gridPaint);
    }
    for (var i = 0; i <= 3; i++) {
      final x = area.left + area.width * i / 3;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), gridPaint);
    }
    canvas.drawLine(
      Offset(area.left, area.bottom),
      Offset(area.right, area.bottom),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1.2,
    );
  }

  void _drawLabels(
    Canvas canvas,
    Rect area,
    double minEquity,
    double maxEquity,
  ) {
    _drawText(
      canvas,
      formatCompactHkd(maxEquity),
      Offset(area.left + 2, area.top - 2),
      align: TextAlign.left,
    );
    _drawText(
      canvas,
      formatCompactHkd(minEquity),
      Offset(area.left + 2, area.bottom - 18),
      align: TextAlign.left,
    );
    final firstDate = _dateText(points.first.time);
    final lastDate = _dateText(points.last.time);
    _drawText(
      canvas,
      firstDate,
      Offset(area.left + 2, area.bottom + 8),
      align: TextAlign.left,
    );
    _drawText(
      canvas,
      lastDate,
      Offset(area.right - 2, area.bottom + 8),
      align: TextAlign.right,
    );
  }

  void _drawEmpty(Canvas canvas, Size size) {
    _drawText(
      canvas,
      '暂无净值曲线',
      Offset(size.width / 2, size.height / 2 - 8),
      align: TextAlign.center,
      fontSize: 13,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    TextAlign align = TextAlign.left,
    double fontSize = 11,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    final dx = switch (align) {
      TextAlign.center => offset.dx - painter.width / 2,
      TextAlign.right => offset.dx - painter.width,
      _ => offset.dx,
    };
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _EquityChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.axisColor != axisColor;
  }
}

String _dateText(DateTime? value) {
  if (value == null) return '--';
  return '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}
