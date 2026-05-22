import 'package:flutter/material.dart';

import '../../utils/theme_helpers.dart';

class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = appAccentColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: appAccentContainerColor(context),
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
