import 'package:flutter/material.dart';

import '../../utils/theme_helpers.dart';

class PositionDetailMetric extends StatelessWidget {
  const PositionDetailMetric({
    super.key,
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
  });

  final String label;
  final String value;
  final String subValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: secondaryTextColor(context))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subValue,
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
