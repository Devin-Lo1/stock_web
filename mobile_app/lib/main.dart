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
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF111827),
          brightness: isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: isDark ? const Color(0xFF38BDF8) : const Color(0xFF111827),
          onPrimary: Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF1C3445)
              : const Color(0xFFF3F4F6),
          onPrimaryContainer: isDark
              ? const Color(0xFFEAF2F8)
              : const Color(0xFF111827),
          secondary: isDark ? const Color(0xFF5CC9C7) : const Color(0xFF4B5563),
          secondaryContainer: isDark
              ? const Color(0xFF1A3A3A)
              : const Color(0xFFF3F4F6),
          onSecondaryContainer: isDark
              ? const Color(0xFFEAF2F8)
              : const Color(0xFF111827),
          tertiary: isDark ? const Color(0xFFE6B450) : const Color(0xFF4B5563),
          tertiaryContainer: isDark
              ? const Color(0xFF3A2E17)
              : const Color(0xFFF3F4F6),
          onTertiaryContainer: isDark
              ? const Color(0xFFFFF2CC)
              : const Color(0xFF111827),
          surface: isDark ? const Color(0xFF071018) : Colors.white,
          surfaceTint: Colors.transparent,
          onSurface: isDark ? const Color(0xFFEAF2F8) : const Color(0xFF111827),
          outline: isDark ? const Color(0xFF243242) : const Color(0xFFE5E7EB),
          outlineVariant: isDark
              ? const Color(0xFF162230)
              : const Color(0xFFE5E7EB),
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '智能量化助手',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: isDark
            ? const Color(0xFF071018)
            : Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: isDark ? const Color(0xFF071018) : Colors.white,
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
