import 'package:flutter/material.dart';

bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color pageBackgroundColor(BuildContext context) {
  return isDarkMode(context) ? const Color(0xFF071018) : Colors.white;
}

Color cardColor(BuildContext context) {
  return isDarkMode(context) ? const Color(0xFF101A24) : Colors.white;
}

Color softCardColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF162230)
      : const Color(0xFFF5F6F8);
}

Color borderColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF243242)
      : const Color(0xFFD1D5DB);
}

Color primaryTextColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFFEAF2F8)
      : const Color(0xFF111827);
}

Color secondaryTextColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF8EA0B5)
      : const Color(0xFF4B5563);
}

Color mutedIconColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF66768A)
      : const Color(0xFF9CA3AF);
}

Color appAccentColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF38BDF8)
      : const Color(0xFF111827);
}

Color appAccentContainerColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF1C3445)
      : const Color(0xFFF3F4F6);
}
