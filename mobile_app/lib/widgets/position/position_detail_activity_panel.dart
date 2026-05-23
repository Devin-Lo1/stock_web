import 'package:flutter/material.dart';

import '../../models/notification_models.dart';
import '../../models/strategy_definition.dart';
import '../../models/strategy_monitor.dart';
import '../../models/trade_signal.dart';
import '../../utils/theme_helpers.dart';
import '../signal/signal_presentation.dart';

class PositionDetailActivityPanel extends StatelessWidget {
  const PositionDetailActivityPanel({
    super.key,
    required this.monitors,
    required this.signals,
    required this.pushRecords,
    required this.isLoading,
    required this.error,
    required this.updatingMonitorIds,
    required this.onRetry,
    required this.onMonitorEnabledChanged,
    required this.onMonitorPushChanged,
    required this.onDeleteMonitor,
    required this.onIgnoreSignal,
    required this.onOpenStrategyMonitor,
  });

  final List<StrategyMonitor> monitors;
  final List<TradeSignal> signals;
  final List<PushRecord> pushRecords;
  final bool isLoading;
  final Object? error;
  final Set<String> updatingMonitorIds;
  final VoidCallback onRetry;
  final void Function(StrategyMonitor monitor, bool enabled)
  onMonitorEnabledChanged;
  final void Function(StrategyMonitor monitor, bool pushCandidate)
  onMonitorPushChanged;
  final ValueChanged<StrategyMonitor> onDeleteMonitor;
  final ValueChanged<TradeSignal> onIgnoreSignal;
  final VoidCallback onOpenStrategyMonitor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '单股监控与信号',
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: '刷新',
                onPressed: isLoading ? null : onRetry,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoading) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 10),
            Text(
              '正在加载单股监控数据',
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
              ),
            ),
          ] else if (error != null) ...[
            _InlineNotice(
              icon: Icons.error_outline_rounded,
              title: '加载失败',
              subtitle: '请刷新后重试。',
              actionLabel: '重试',
              onAction: onRetry,
            ),
          ] else ...[
            _PanelSection(
              title: '策略监控',
              trailing: TextButton.icon(
                onPressed: onOpenStrategyMonitor,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('创建监控'),
              ),
              empty: const _InlineNotice(
                icon: Icons.rule_rounded,
                title: '暂无策略监控',
                subtitle: '创建后会按策略扫描这只股票。',
              ),
              children: monitors
                  .map(
                    (monitor) => _MonitorRow(
                      monitor: monitor,
                      isUpdating: updatingMonitorIds.contains(monitor.id),
                      onEnabledChanged: (enabled) =>
                          onMonitorEnabledChanged(monitor, enabled),
                      onPushChanged: (pushCandidate) =>
                          onMonitorPushChanged(monitor, pushCandidate),
                      onDelete: () => onDeleteMonitor(monitor),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            _PanelSection(
              title: '历史信号',
              empty: const _InlineNotice(
                icon: Icons.notifications_none_rounded,
                title: '暂无历史信号',
                subtitle: '风控或策略触发后会显示在这里。',
              ),
              children: signals
                  .take(3)
                  .map(
                    (signal) => _SignalRow(
                      signal: signal,
                      onIgnore: signal.id.isEmpty
                          ? null
                          : () => onIgnoreSignal(signal),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            _PanelSection(
              title: '推送记录',
              empty: const _InlineNotice(
                icon: Icons.phone_android_rounded,
                title: '暂无推送记录',
                subtitle: '有推送尝试后会显示发送状态。',
              ),
              children: pushRecords
                  .take(3)
                  .map((record) => _PushRecordRow(record: record))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.title,
    required this.empty,
    required this.children,
    this.trailing,
  });

  final String title;
  final Widget empty;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          empty
        else
          ..._separated(children, const SizedBox(height: 8)),
      ],
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.monitor,
    required this.isUpdating,
    required this.onEnabledChanged,
    required this.onPushChanged,
    required this.onDelete,
  });

  final StrategyMonitor monitor;
  final bool isUpdating;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onPushChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = monitor.enabled
        ? const Color(0xFF20C997)
        : secondaryTextColor(context);
    return _ActivityRow(
      leading: Icons.radar_rounded,
      color: statusColor,
      title: strategyDisplayNameForCode(
        monitor.strategyCode,
        fallbackName: monitor.strategyName,
      ),
      subtitle: '${_periodLabel(monitor.period)} · ${monitor.parameterLabel}',
      meta:
          '扫描 ${_timeLabel(monitor.lastScannedAt)} · 触发 ${_timeLabel(monitor.lastTriggeredAt)}',
      badge: monitor.enabled ? '启用' : '停用',
      trailing: _MonitorActions(
        monitor: monitor,
        isUpdating: isUpdating,
        onEnabledChanged: onEnabledChanged,
        onPushChanged: onPushChanged,
        onDelete: onDelete,
      ),
    );
  }
}

class _MonitorActions extends StatelessWidget {
  const _MonitorActions({
    required this.monitor,
    required this.isUpdating,
    required this.onEnabledChanged,
    required this.onPushChanged,
    required this.onDelete,
  });

  final StrategyMonitor monitor;
  final bool isUpdating;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onPushChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (isUpdating) {
      return const SizedBox(
        width: 144,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return SizedBox(
      width: 144,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: monitor.enabled ? '停用监控' : '启用监控',
            onPressed: () => onEnabledChanged(!monitor.enabled),
            icon: Icon(
              Icons.power_settings_new_rounded,
              color: monitor.enabled
                  ? const Color(0xFF20C997)
                  : secondaryTextColor(context),
            ),
          ),
          IconButton(
            tooltip: monitor.pushCandidate ? '关闭推送' : '开启推送',
            onPressed: monitor.enabled
                ? () => onPushChanged(!monitor.pushCandidate)
                : null,
            icon: Icon(
              monitor.pushCandidate
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
            ),
          ),
          IconButton(
            tooltip: '删除监控',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal, required this.onIgnore});

  final TradeSignal signal;
  final VoidCallback? onIgnore;

  @override
  Widget build(BuildContext context) {
    final detail = signal.conditionLabel.isNotEmpty
        ? signal.conditionLabel
        : signal.message;
    return _ActivityRow(
      leading: Icons.notifications_active_outlined,
      color: signalColor(signal),
      title: signal.type,
      subtitle: detail.isEmpty ? signal.stock : detail,
      meta: '${signal.time} · ${signal.level}',
      badge: signal.pushCandidate ? '推送' : null,
      trailing: onIgnore == null
          ? null
          : IconButton(
              tooltip: '忽略信号',
              onPressed: onIgnore,
              icon: const Icon(Icons.visibility_off_outlined, size: 18),
            ),
    );
  }
}

class _PushRecordRow extends StatelessWidget {
  const _PushRecordRow({required this.record});

  final PushRecord record;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(record.status, context);
    return _ActivityRow(
      leading: Icons.send_to_mobile_rounded,
      color: color,
      title: record.signalEventId == null
          ? '测试推送'
          : '信号 ${_shortId(record.signalEventId!)}',
      subtitle: '${record.provider.toUpperCase()} · 尝试 ${record.attemptCount}',
      meta: _timeLabel(record.sentAt ?? record.createdAt),
      badge: _statusLabel(record.status),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.leading,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.badge,
    this.trailing,
  });

  final IconData leading;
  final Color color;
  final String title;
  final String subtitle;
  final String meta;
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(leading, color: color, size: 18),
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryTextColor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      _Badge(label: badge!, color: color),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor(context).withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: mutedIconColor(context), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

List<Widget> _separated(List<Widget> children, Widget separator) {
  if (children.length < 2) return children;
  final result = <Widget>[];
  for (final child in children) {
    if (result.isNotEmpty) result.add(separator);
    result.add(child);
  }
  return result;
}

Color _statusColor(String status, BuildContext context) {
  return switch (status) {
    'sent' => const Color(0xFF20C997),
    'failed' => const Color(0xFFFF4D67),
    'skipped' => secondaryTextColor(context),
    _ => const Color(0xFF4DB7FF),
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'sent' => '已发送',
    'failed' => '失败',
    'skipped' => '跳过',
    'queued' => '队列中',
    _ => status.isEmpty ? '未知' : status,
  };
}

String _periodLabel(String period) {
  return switch (period) {
    '1m' => '1分钟',
    '60m' => '60分钟',
    _ => '日K',
  };
}

String _shortId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}

String _timeLabel(DateTime? value) {
  if (value == null) return '未执行';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
