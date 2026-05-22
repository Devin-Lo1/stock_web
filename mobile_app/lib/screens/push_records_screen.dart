import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_models.dart';
import '../repositories/notification_repository.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_title.dart';

class PushRecordsScreen extends StatefulWidget {
  const PushRecordsScreen({super.key, required this.notificationRepository});

  final NotificationRepository notificationRepository;

  @override
  State<PushRecordsScreen> createState() => _PushRecordsScreenState();
}

class _PushRecordsScreenState extends State<PushRecordsScreen> {
  static const _statusOptions = <String, String>{
    'all': '全部',
    'sent': '已发送',
    'failed': '失败',
    'skipped': '跳过',
    'queued': '队列中',
  };

  final _codeController = TextEditingController();
  List<PushRecord> _records = const [];
  bool _isLoading = true;
  String _statusFilter = 'all';
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecords());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final records = await widget.notificationRepository.loadPushRecords(
        code: _codeController.text,
        status: _statusFilter == 'all' ? null : _statusFilter,
        limit: 100,
      );
      if (!mounted) return;
      setState(() => _records = records);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _retryRecord(PushRecord record) async {
    try {
      await widget.notificationRepository.retryPushRecord(record.id);
      if (!mounted) return;
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已重新发起推送')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重试失败：$error')));
    }
  }

  Future<void> _deleteRecord(PushRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除推送记录'),
        content: const Text('删除后列表和单股详情页都不会再显示这条记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.notificationRepository.deletePushRecord(record.id);
      if (!mounted) return;
      setState(() {
        _records = _records.where((item) => item.id != record.id).toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('推送记录已删除')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecords,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: PageTitle(title: '推送记录', subtitle: '查看信号发送状态'),
                  ),
                  IconButton.outlined(
                    tooltip: '刷新',
                    onPressed: _isLoading ? null : _loadRecords,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PushRecordFilters(
                codeController: _codeController,
                statusOptions: _statusOptions,
                selectedStatus: _statusFilter,
                isLoading: _isLoading,
                onSubmitted: _loadRecords,
                onStatusChanged: (status) {
                  setState(() => _statusFilter = status);
                  unawaited(_loadRecords());
                },
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (_error != null)
                EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: '加载失败',
                  subtitle: '请刷新后重试。',
                  actionLabel: '重试',
                  onAction: _loadRecords,
                )
              else if (_records.isEmpty)
                const ReadOnlyEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: '暂无推送记录',
                  subtitle: '后端产生推送尝试后会显示在这里。',
                )
              else
                ..._records.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PushRecordTile(
                      record: record,
                      onRetry: record.signalEventId == null
                          ? null
                          : () => _retryRecord(record),
                      onDelete: () => _deleteRecord(record),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PushRecordFilters extends StatelessWidget {
  const _PushRecordFilters({
    required this.codeController,
    required this.statusOptions,
    required this.selectedStatus,
    required this.isLoading,
    required this.onSubmitted,
    required this.onStatusChanged,
  });

  final TextEditingController codeController;
  final Map<String, String> statusOptions;
  final String selectedStatus;
  final bool isLoading;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        children: [
          TextField(
            controller: codeController,
            enabled: !isLoading,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: '股票代码',
              hintText: '例如 HK.02318',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: '查询',
                onPressed: isLoading ? null : onSubmitted,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in statusOptions.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: selectedStatus == entry.key,
                    onSelected: isLoading
                        ? null
                        : (_) => onStatusChanged(entry.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PushRecordTile extends StatelessWidget {
  const _PushRecordTile({
    required this.record,
    required this.onRetry,
    required this.onDelete,
  });

  final PushRecord record;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(record.status, context);
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
                  record.signalEventId == null
                      ? '测试推送'
                      : '信号 ${_shortId(record.signalEventId!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(label: _statusLabel(record.status), color: color),
              const SizedBox(width: 4),
              PopupMenuButton<_PushRecordAction>(
                tooltip: '更多操作',
                onSelected: (action) {
                  switch (action) {
                    case _PushRecordAction.retry:
                      onRetry?.call();
                      break;
                    case _PushRecordAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _PushRecordAction.retry,
                    enabled: onRetry != null,
                    child: const Text('重试'),
                  ),
                  const PopupMenuItem(
                    value: _PushRecordAction.delete,
                    child: Text('删除'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.hub_rounded,
                label: record.provider.toUpperCase(),
              ),
              _InfoChip(
                icon: Icons.smartphone_rounded,
                label: _shortId(record.deviceId),
              ),
              _InfoChip(
                icon: Icons.repeat_rounded,
                label: '尝试 ${record.attemptCount}',
              ),
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: _timeLabel(record.sentAt ?? record.createdAt),
              ),
            ],
          ),
          if (record.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record.errorMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFF4D67),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _PushRecordAction { retry, delete }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = secondaryTextColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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

String _shortId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
