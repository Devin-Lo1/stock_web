import 'package:flutter/material.dart';

bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color pageBackgroundColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF071018)
      : const Color(0xFFF7FAFC);
}

Color cardColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF101A24)
      : const Color(0xFFEAF6FF);
}

Color softCardColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF162230)
      : const Color(0xFFDCEFFF);
}

Color borderColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF243242)
      : const Color(0xFFBBDCF2);
}

Color primaryTextColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFFEAF2F8)
      : const Color(0xFF111827);
}

Color secondaryTextColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF8EA0B5)
      : const Color(0xFF5F6F82);
}

Color mutedIconColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF66768A)
      : const Color(0xFF7890A8);
}
