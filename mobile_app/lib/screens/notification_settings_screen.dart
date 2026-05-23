import 'package:flutter/material.dart';

import '../models/notification_models.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/page_title.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.repository,
    required this.notificationService,
    required this.onRefresh,
  });

  final NotificationRepository repository;
  final NotificationService notificationService;
  final Future<void> Function() onRefresh;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _enabled = true;
  bool _importantEnabled = true;
  bool _isRegistering = false;
  bool _isTesting = false;
  bool _isLoadingProviders = false;
  String? _errorMessage;
  String? _providerStatusError;
  NotificationRegistrationResult? _registration;
  PushRecord? _lastTestRecord;
  List<PushProviderStatus> _providerStatuses = const [];

  @override
  void initState() {
    super.initState();
    _registerDevice();
    _loadProviderStatuses();
  }

  @override
  Widget build(BuildContext context) {
    final device = _registration?.device;
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: pageBackgroundColor(context),
        title: const Text('消息提醒设置'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.onRefresh();
          await Future.wait([_registerDevice(), _loadProviderStatuses()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            const PageTitle(title: '消息提醒', subtitle: '重要信号通知和设备注册'),
            const SizedBox(height: 12),
            _SettingsCard(
              children: [
                SwitchListTile(
                  value: _enabled,
                  onChanged: _isRegistering ? null : _updateEnabled,
                  title: const Text('手机提醒'),
                  subtitle: const Text('关闭后后端不会向本设备推送提醒'),
                ),
                SwitchListTile(
                  value: _importantEnabled,
                  onChanged: _enabled && !_isRegistering
                      ? _updateImportantEnabled
                      : null,
                  title: const Text('重要信号'),
                  subtitle: const Text('止盈、止损、异动和策略买卖观察'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DeviceCard(
              device: device,
              isRegistering: _isRegistering,
              latestSignalCount: _registration?.latestSignalCount,
              errorMessage: _errorMessage,
              onRegister: _registerDevice,
            ),
            const SizedBox(height: 12),
            _ProviderStatusCard(
              statuses: _providerStatuses,
              isLoading: _isLoadingProviders,
              errorMessage: _providerStatusError,
              onRefresh: _loadProviderStatuses,
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.notifications_active_outlined,
                    color: appAccentColor(context),
                  ),
                  title: const Text('测试通知'),
                  subtitle: Text(_testSubtitle),
                  trailing: FilledButton.tonalIcon(
                    onPressed: device == null || _isTesting
                        ? null
                        : _sendTestNotification,
                    icon: _isTesting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('测试'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _testSubtitle {
    final record = _lastTestRecord;
    if (record == null) return '先弹本地通知，并在后端写入测试推送记录';
    if (record.status == 'queued') return '后端测试记录已排队，等待真实推送通道';
    if (record.status == 'skipped') {
      return record.errorMessage.isEmpty
          ? '后端已记录测试请求，真实推送通道尚未配置'
          : '后端已记录：${record.errorMessage}';
    }
    return '后端测试记录状态：${record.status}';
  }

  Future<void> _updateEnabled(bool value) async {
    setState(() => _enabled = value);
    await _registerDevice();
  }

  Future<void> _updateImportantEnabled(bool value) async {
    setState(() => _importantEnabled = value);
    await _registerDevice();
  }

  Future<void> _registerDevice() async {
    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });
    try {
      final registration = await widget.repository.registerCurrentDevice(
        enabled: _enabled,
        importantEnabled: _importantEnabled,
      );
      if (!mounted) return;
      setState(() => _registration = registration);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _loadProviderStatuses() async {
    setState(() {
      _isLoadingProviders = true;
      _providerStatusError = null;
    });
    try {
      final statuses = await widget.repository.loadPushProviderStatuses();
      if (!mounted) return;
      setState(() => _providerStatuses = statuses);
    } catch (error) {
      if (!mounted) return;
      setState(() => _providerStatusError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingProviders = false);
    }
  }

  Future<void> _sendTestNotification() async {
    final device = _registration?.device;
    if (device == null) return;
    setState(() => _isTesting = true);
    await widget.notificationService.showTestNotification();
    try {
      final record = await widget.repository.sendTestNotification(device.id);
      if (!mounted) return;
      setState(() => _lastTestRecord = record);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }
}

class _ProviderStatusCard extends StatelessWidget {
  const _ProviderStatusCard({
    required this.statuses,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
  });

  final List<PushProviderStatus> statuses;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        Row(
          children: [
            Icon(Icons.cloud_sync_outlined, color: appAccentColor(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '真实推送通道',
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: '刷新通道状态',
              visualDensity: VisualDensity.compact,
              onPressed: isLoading ? null : onRefresh,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading && statuses.isEmpty)
          const LinearProgressIndicator(minHeight: 2)
        else if (errorMessage != null)
          Text(errorMessage!, style: const TextStyle(color: Color(0xFFEF4444)))
        else if (statuses.isEmpty)
          Text(
            '后端暂未返回推送通道状态。',
            style: TextStyle(color: secondaryTextColor(context)),
          )
        else
          Column(
            children: [
              for (final status in statuses)
                _ProviderStatusTile(status: status),
            ],
          ),
      ],
    );
  }
}

class _ProviderStatusTile extends StatelessWidget {
  const _ProviderStatusTile({required this.status});

  final PushProviderStatus status;

  @override
  Widget build(BuildContext context) {
    final configured = status.configured;
    final color = configured
        ? const Color(0xFF20C997)
        : const Color(0xFFE6A93A);
    final missing = status.missingEnv.join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                configured
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _providerName(status.provider),
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      AppTag(
                        text: configured
                            ? status.validateOnly
                                  ? '校验模式'
                                  : '可发送'
                            : '待配置',
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    status.message.isEmpty
                        ? (configured ? '服务端配置已就绪。' : '服务端配置未完成。')
                        : status.message,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                  if (!configured && missing.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '缺少：$missing',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.isRegistering,
    required this.latestSignalCount,
    required this.errorMessage,
    required this.onRegister,
  });

  final NotificationDevice? device;
  final bool isRegistering;
  final int? latestSignalCount;
  final String? errorMessage;
  final Future<void> Function() onRegister;

  @override
  Widget build(BuildContext context) {
    final device = this.device;
    return _SettingsCard(
      children: [
        Row(
          children: [
            Icon(Icons.phone_android_rounded, color: appAccentColor(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '当前设备',
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            AppTag(text: device == null ? '未注册' : '已注册'),
          ],
        ),
        const SizedBox(height: 10),
        if (isRegistering)
          const LinearProgressIndicator(minHeight: 2)
        else if (errorMessage != null)
          Text(errorMessage!, style: const TextStyle(color: Color(0xFFEF4444)))
        else if (device != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine(label: '平台', value: device.platform),
              _InfoLine(label: '推送通道', value: _providerText(device)),
              _InfoLine(label: '最近注册', value: _dateTimeText(device.lastSeenAt)),
              _InfoLine(label: '最新信号', value: '${latestSignalCount ?? 0} 条'),
            ],
          )
        else
          Text(
            '设备尚未注册到后端',
            style: TextStyle(color: secondaryTextColor(context)),
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: isRegistering ? null : onRegister,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('重新注册'),
          ),
        ),
      ],
    );
  }

  String _providerText(NotificationDevice device) {
    if (device.pushProvider == 'unknown') return '本机安装 token，等待真实推送通道';
    if (device.pushProvider == 'huawei') return 'Huawei Push Kit';
    if (device.pushProvider == 'fcm') return 'FCM';
    return device.pushProvider.toUpperCase();
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: secondaryTextColor(context)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: primaryTextColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateTimeText(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '-';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}/${two(value.month)}/${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _providerName(String provider) {
  return switch (provider) {
    'huawei' => 'Huawei Push Kit',
    'fcm' => 'Firebase Cloud Messaging',
    _ => provider.toUpperCase(),
  };
}
