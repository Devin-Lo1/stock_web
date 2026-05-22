import 'package:flutter/material.dart';

import '../../utils/theme_helpers.dart';

class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = appAccentColor(context);
    final backgroundColor = isDarkMode(context)
        ? const Color(0xFF38BDF8).withValues(alpha: 0.13)
        : appAccentContainerColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
