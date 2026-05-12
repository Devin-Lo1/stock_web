import 'package:flutter/material.dart';

import 'models/app_enums.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const StockSignalApp());
}

class StockSignalApp extends StatefulWidget {
  const StockSignalApp({super.key});

  @override
  State<StockSignalApp> createState() => _StockSignalAppState();
}

class _StockSignalAppState extends State<StockSignalApp> {
  DisplayMode _displayMode = DisplayMode.dark;

  @override
  Widget build(BuildContext context) {
    final isDark = _displayMode == DisplayMode.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '智能量化助手',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: isDark
            ? const Color(0xFF071018)
            : const Color(0xFFF7FAFC),
      ),
      home: AppShell(
        displayMode: _displayMode,
        onDisplayModeChanged: (mode) => setState(() => _displayMode = mode),
      ),
    );
  }
}
