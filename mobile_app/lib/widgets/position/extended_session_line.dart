import 'package:flutter/material.dart';

import '../../models/stock_position.dart';
import '../../utils/formatters.dart';

class ExtendedSessionLine extends StatelessWidget {
  const ExtendedSessionLine({
    super.key,
    required this.position,
    this.fontSize = 10,
    this.fontWeight = FontWeight.w800,
    this.textAlign = TextAlign.left,
  });

  final StockPosition position;
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (!position.hasExtendedSession) return const SizedBox.shrink();

    return Text(
      _extendedText(position),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        color: _profitColor(position.extendedChange).withValues(alpha: 0.9),
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}

String _extendedText(StockPosition position) {
  final price = position.extendedPrice.toStringAsFixed(2);
  final change = position.extendedChange;
  final changeSign = change > 0
      ? '+'
      : change < 0
      ? '-'
      : '';
  final changeText = '$changeSign${change.abs().toStringAsFixed(2)}';
  return '${_sessionLabel(position.extendedSession)} $price $changeText (${formatPercent(position.extendedChangeRate)})';
}

String _sessionLabel(String session) {
  switch (session) {
    case 'pre':
      return '盘前';
    case 'after':
      return '盘后';
    case 'overnight':
      return '夜盘';
    default:
      return '';
  }
}

Color _profitColor(double value) {
  if (value == 0) return const Color(0xFF94A3B8);
  return value > 0 ? const Color(0xFF12B886) : const Color(0xFFFF4D67);
}
