import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../models/backend_connection_state.dart';
import '../models/strategy_settings.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/page_title.dart';
import 'display_settings_screen.dart';
import 'factor_guide_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.displayMode,
    required this.backendState,
    required this.apiBaseUrl,
    required this.notificationRepository,
    required this.notificationService,
    required this.onRefresh,
    required this.onSettingsChanged,
    required this.onDisplayModeChanged,
  });

  final StrategySettings settings;
  final DisplayMode displayMode;
  final BackendConnectionState backendState;
  final String apiBaseUrl;
  final NotificationRepository notificationRepository;
  final NotificationService notificationService;
  final Future<void> Function() onRefresh;
  final ValueChanged<StrategySettings> onSettingsChanged;
  final ValueChanged<DisplayMode> onDisplayModeChanged;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        children: [
          const PageTitle(title: '设置', subtitle: '开发阶段配置与连接状态'),
          const SizedBox(height: 12),
          StrategySettingsPanel(
            settings: settings,
            onSettingsChanged: onSettingsChanged,
          ),
          const SizedBox(height: 12),
          _SettingTile(
            icon: Icons.palette_outlined,
            title: '显示设置',
            subtitle: displayMode == DisplayMode.dark ? '夜间模式' : '日间模式',
            status: '可切换',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => DisplaySettingsScreen(
                  displayMode: displayMode,
                  onDisplayModeChanged: onDisplayModeChanged,
                  onRefresh: onRefresh,
                ),
              ),
            ),
          ),
          _SettingTile(
            icon: Icons.cloud_done_outlined,
            title: '后端 API',
            subtitle: apiBaseUrl,
            status: backendState.statusLabel,
          ),
          _SettingTile(
            icon: Icons.notifications_active_outlined,
            title: '手机推送',
            subtitle: '设备注册与测试通知',
            status: '可配置',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => NotificationSettingsScreen(
                  repository: notificationRepository,
                  notificationService: notificationService,
                  onRefresh: onRefresh,
                ),
              ),
            ),
          ),
          _SettingTile(
            icon: Icons.menu_book_outlined,
            title: '因子说明',
            subtitle: '策略因子、组合因子与使用注意',
            status: '说明',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const FactorGuideScreen(),
              ),
            ),
          ),
          const _SettingTile(
            icon: Icons.show_chart_rounded,
            title: '富途行情',
            subtitle: 'FutuOpenD + futu-api',
            status: '下一步',
          ),
          const _SettingTile(
            icon: Icons.info_outline_rounded,
            title: '版本',
            subtitle: 'Android MVP 0.1.0',
            status: '开发中',
          ),
        ],
      ),
    );
  }
}

class StrategySettingsPanel extends StatefulWidget {
  const StrategySettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final StrategySettings settings;
  final ValueChanged<StrategySettings> onSettingsChanged;

  @override
  State<StrategySettingsPanel> createState() => _StrategySettingsPanelState();
}

class _StrategySettingsPanelState extends State<StrategySettingsPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _takeProfitController;
  late final TextEditingController _stopLossController;
  late final TextEditingController _dailySurgeController;
  late final TextEditingController _dailyDropController;

  @override
  void initState() {
    super.initState();
    _takeProfitController = TextEditingController(
      text: _settingText(widget.settings.takeProfitPercent),
    );
    _stopLossController = TextEditingController(
      text: _settingText(widget.settings.stopLossPercent),
    );
    _dailySurgeController = TextEditingController(
      text: _settingText(widget.settings.dailySurgePercent),
    );
    _dailyDropController = TextEditingController(
      text: _settingText(widget.settings.dailyDropPercent),
    );
  }

  @override
  void dispose() {
    _takeProfitController.dispose();
    _stopLossController.dispose();
    _dailySurgeController.dispose();
    _dailyDropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '策略阈值',
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '留空会使用默认值：止盈 5%，止损 -5%，当日异动 ±5%。',
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StrategyInput(
                    controller: _takeProfitController,
                    label: '止盈观察 %',
                    hint: '5',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StrategyInput(
                    controller: _stopLossController,
                    label: '止损观察 %',
                    hint: '-5',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StrategyInput(
                    controller: _dailySurgeController,
                    label: '上涨异动 %',
                    hint: '5',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StrategyInput(
                    controller: _dailyDropController,
                    label: '下跌异动 %',
                    hint: '-5',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('默认值'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    _takeProfitController.text = '5';
    _stopLossController.text = '-5';
    _dailySurgeController.text = '5';
    _dailyDropController.text = '-5';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSettingsChanged(
      StrategySettings(
        takeProfitPercent: _readSetting(
          _takeProfitController,
          StrategySettings.defaults.takeProfitPercent,
        ),
        stopLossPercent: _readSetting(
          _stopLossController,
          StrategySettings.defaults.stopLossPercent,
        ),
        dailySurgePercent: _readSetting(
          _dailySurgeController,
          StrategySettings.defaults.dailySurgePercent,
        ),
        dailyDropPercent: _readSetting(
          _dailyDropController,
          StrategySettings.defaults.dailyDropPercent,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: appAccentColor(context)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: AppTag(text: status),
      ),
    );
  }
}

class _StrategyInput extends StatelessWidget {
  const _StrategyInput({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: softCardColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        if (double.tryParse(text) == null) return '请输入数字';
        return null;
      },
    );
  }
}

String _settingText(double value) => _formatNumberInput(value);

double _readSetting(TextEditingController controller, double fallback) {
  final text = controller.text.trim();
  if (text.isEmpty) return fallback;
  return double.tryParse(text) ?? fallback;
}

String _formatNumberInput(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
