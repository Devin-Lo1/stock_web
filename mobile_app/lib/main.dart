import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'models/app_enums.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
    final colorScheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: const Color(0xFF38BDF8),
            brightness: Brightness.dark,
          )
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFF111827),
            brightness: Brightness.light,
          ).copyWith(
            primary: const Color(0xFF111827),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFF3F4F6),
            onPrimaryContainer: const Color(0xFF111827),
            secondary: const Color(0xFF4B5563),
            secondaryContainer: const Color(0xFFF3F4F6),
            onSecondaryContainer: const Color(0xFF111827),
            tertiary: const Color(0xFF4B5563),
            tertiaryContainer: const Color(0xFFF3F4F6),
            onTertiaryContainer: const Color(0xFF111827),
            surface: Colors.white,
            surfaceTint: Colors.transparent,
            onSurface: const Color(0xFF111827),
            outline: const Color(0xFFE5E7EB),
            outlineVariant: const Color(0xFFE5E7EB),
          );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF071018) : Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '智能量化助手',
      theme: isDark
          ? theme
          : theme.copyWith(
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
            ),
      home: AppShell(
        displayMode: _displayMode,
        onDisplayModeChanged: (mode) => setState(() => _displayMode = mode),
      ),
    );
  }
}
