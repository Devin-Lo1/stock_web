import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../utils/theme_helpers.dart';

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({
    super.key,
    required this.displayMode,
    required this.onDisplayModeChanged,
    this.onRefresh,
  });

  final DisplayMode displayMode;
  final ValueChanged<DisplayMode> onDisplayModeChanged;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: pageBackgroundColor(context),
        title: const Text('显示设置'),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _DisplayModeTile(
              icon: Icons.dark_mode_outlined,
              title: '夜间模式',
              subtitle: '深色背景，适合夜间和行情盯盘',
              selected: displayMode == DisplayMode.dark,
              onTap: () => onDisplayModeChanged(DisplayMode.dark),
            ),
            const SizedBox(height: 10),
            _DisplayModeTile(
              icon: Icons.light_mode_outlined,
              title: '日间模式',
              subtitle: '纯白背景、黑色文字、中性卡片',
              selected: displayMode == DisplayMode.light,
              onTap: () => onDisplayModeChanged(DisplayMode.light),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayModeTile extends StatelessWidget {
  const _DisplayModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: selected ? softCardColor(context) : cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? appAccentColor(context) : borderColor(context),
        ),
      ),
      leading: Icon(icon, color: selected ? appAccentColor(context) : null),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_rounded, color: appAccentColor(context))
          : null,
    );
  }
}
