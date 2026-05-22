import 'dart:async';

import 'package:flutter/material.dart';

import '../models/stock_position.dart';
import '../models/strategy_definition.dart';
import '../models/strategy_monitor.dart';
import '../models/strategy_parameter_config.dart';
import '../repositories/backtest_repository.dart';
import '../repositories/strategy_monitor_repository.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_title.dart';

const _scanLogLimit = 10;

class StrategyMonitorScreen extends StatefulWidget {
  const StrategyMonitorScreen({
    super.key,
    required this.positions,
    required this.backtestRepository,
    required this.monitorRepository,
    this.initialCode,
  });

  final List<StockPosition> positions;
  final BacktestRepository backtestRepository;
  final StrategyMonitorRepository monitorRepository;
  final String? initialCode;

  @override
  State<StrategyMonitorScreen> createState() => _StrategyMonitorScreenState();
}

class _StrategyMonitorScreenState extends State<StrategyMonitorScreen> {
  final _listController = ScrollController();
  final _intervalController = TextEditingController(text: '15');
  final _cooldownController = TextEditingController(text: '120');
  final _schedulerIntervalController = TextEditingController(text: '60');
  final Set<String> _updatingIds = <String>{};
  final Set<String> _deletingLogIds = <String>{};
  final Map<String, String> _parameterValues = <String, String>{};

  List<StrategyDefinition> _strategies = const [];
  List<StrategyMonitor> _monitors = const [];
  List<StrategyMonitorScanLog> _scanLogs = const [];
  StrategyMonitorSchedulerStatus? _schedulerStatus;
  StrategyMonitor? _editingMonitor;
  StockPosition? _selectedPosition;
  StrategyDefinition? _selectedStrategy;
  String _period = 'day';
  bool _enabled = true;
  bool _pushCandidate = true;
  bool _schedulerRefresh = false;
  bool _isLoading = true;
  bool _isCreating = false;
  bool _isScanningNow = false;
  bool _isSchedulerUpdating = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _selectedPosition = _selectInitialPosition(
      widget.positions,
      widget.initialCode,
    );
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant StrategyMonitorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.positions.isEmpty) {
      _selectedPosition = null;
      return;
    }
    if (oldWidget.initialCode != widget.initialCode &&
        widget.initialCode != null) {
      _selectedPosition = _selectInitialPosition(
        widget.positions,
        widget.initialCode,
      );
      return;
    }
    if (_selectedPosition == null ||
        !widget.positions.any((item) => item.code == _selectedPosition!.code)) {
      _selectedPosition = _selectInitialPosition(
        widget.positions,
        widget.initialCode,
      );
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    _intervalController.dispose();
    _cooldownController.dispose();
    _schedulerIntervalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        widget.backtestRepository.loadStrategies(),
        widget.monitorRepository.loadMonitors(limit: 200),
        widget.monitorRepository.loadSchedulerStatus(),
        widget.monitorRepository.loadScanLogs(limit: _scanLogLimit),
      ]);
      if (!mounted) return;
      final strategies = result[0] as List<StrategyDefinition>;
      final schedulerStatus = result[2] as StrategyMonitorSchedulerStatus;
      setState(() {
        _strategies = strategies;
        _monitors = result[1] as List<StrategyMonitor>;
        _schedulerStatus = schedulerStatus;
        _scanLogs = result[3] as List<StrategyMonitorScanLog>;
        _schedulerRefresh = schedulerStatus.refresh;
        _schedulerIntervalController.text =
            '${schedulerStatus.pollIntervalSeconds}';
        _selectedStrategy = strategies.isEmpty ? null : strategies.first;
        _seedParameterValues();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seedParameterValues() {
    final strategy = _selectedStrategy;
    if (strategy == null) return;
    for (final spec in strategyParameterSpecsFor(strategy.code)) {
      _parameterValues[spec.key] = strategyParameterDefaultText(strategy, spec);
    }
  }

  void _selectStrategy(String code) {
    final strategy = _strategies.firstWhere(
      (item) => item.code == code,
      orElse: () => _strategies.first,
    );
    setState(() {
      _selectedStrategy = strategy;
      _parameterValues.clear();
      _seedParameterValues();
    });
  }

  Future<void> _submitMonitorForm() async {
    if (_editingMonitor != null) {
      await _saveEditedMonitor();
      return;
    }
    await _createMonitor();
  }

  Future<void> _createMonitor() async {
    final position = _selectedPosition;
    final strategy = _selectedStrategy;
    if (position == null || strategy == null || _isCreating) return;

    final interval = _positiveInt(_intervalController.text);
    final cooldown = _nonNegativeInt(_cooldownController.text);
    final parameters = _readParameters(strategy);
    if (interval == null || cooldown == null || parameters == null) {
      _showSnack('请检查扫描间隔、冷却时间和策略参数。');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final monitor = await widget.monitorRepository.createMonitor(
        StrategyMonitorCreateRequest(
          positionId: position.id,
          market: _marketFromCode(position.code),
          code: position.code,
          name: position.name,
          strategyCode: strategy.code,
          strategyName: strategy.name,
          parameters: parameters,
          period: _period,
          scanIntervalMinutes: interval,
          cooldownMinutes: cooldown,
          enabled: _enabled,
          pushCandidate: _pushCandidate,
        ),
      );
      if (!mounted) return;
      setState(() => _monitors = [monitor, ..._monitors]);
      if (monitor.enabled) {
        await _scanOnce(showSnack: false);
        if (!mounted) return;
        if (_schedulerStatus?.running != true) {
          await _startScheduler(showSnack: false);
          if (!mounted) return;
        }
        _showSnack('策略监控已创建，已执行一次扫描并启动调度器。');
      } else {
        _showSnack('策略监控已创建。');
      }
    } catch (error) {
      if (!mounted) return;
      _showSnack('创建失败：$error');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _saveEditedMonitor() async {
    final monitor = _editingMonitor;
    final position = _selectedPosition;
    final strategy = _selectedStrategy;
    if (monitor == null ||
        position == null ||
        strategy == null ||
        _isCreating) {
      return;
    }

    final interval = _positiveInt(_intervalController.text);
    final cooldown = _nonNegativeInt(_cooldownController.text);
    final parameters = _readParameters(strategy);
    if (interval == null || cooldown == null || parameters == null) {
      _showSnack('请检查扫描间隔、冷却时间和策略参数。');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final updated = await widget.monitorRepository.updateMonitor(
        monitor.id,
        positionId: position.id,
        market: _marketFromCode(position.code),
        code: position.code,
        name: position.name,
        strategyCode: strategy.code,
        strategyName: strategy.name,
        parameters: parameters,
        period: _period,
        scanIntervalMinutes: interval,
        cooldownMinutes: cooldown,
        enabled: _enabled,
        pushCandidate: _pushCandidate,
      );
      if (!mounted) return;
      setState(() {
        _replaceMonitor(updated);
        _editingMonitor = null;
      });
      _showSnack('策略监控已保存。');
    } catch (error) {
      if (!mounted) return;
      _showSnack('保存失败：$error');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _startEditMonitor(StrategyMonitor monitor) {
    final position = widget.positions.where(
      (item) => item.code == monitor.code,
    );
    final strategy = _strategies.where(
      (item) => item.code == monitor.strategyCode,
    );
    setState(() {
      _editingMonitor = monitor;
      _selectedPosition = position.isEmpty ? _selectedPosition : position.first;
      _selectedStrategy = strategy.isEmpty ? _selectedStrategy : strategy.first;
      _period = monitor.period;
      _enabled = monitor.enabled;
      _pushCandidate = monitor.pushCandidate;
      _intervalController.text = '${monitor.scanIntervalMinutes}';
      _cooldownController.text = '${monitor.cooldownMinutes}';
      _parameterValues
        ..clear()
        ..addAll(_parameterTextValues(monitor));
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        if (!_listController.hasClients) return;
        _listController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }),
    );
  }

  void _cancelEditMonitor() {
    setState(() {
      _editingMonitor = null;
      _intervalController.text = '15';
      _cooldownController.text = '120';
      _period = 'day';
      _enabled = true;
      _pushCandidate = true;
      _selectedPosition = _selectInitialPosition(
        widget.positions,
        widget.initialCode,
      );
      _selectedStrategy = _strategies.isEmpty ? null : _strategies.first;
      _parameterValues.clear();
      _seedParameterValues();
    });
  }

  Future<void> _updateMonitor(
    StrategyMonitor monitor, {
    bool? enabled,
    bool? pushCandidate,
  }) async {
    setState(() => _updatingIds.add(monitor.id));
    try {
      final updated = await widget.monitorRepository.updateMonitor(
        monitor.id,
        enabled: enabled,
        pushCandidate: pushCandidate,
      );
      if (!mounted) return;
      setState(() => _replaceMonitor(updated));
    } catch (error) {
      if (!mounted) return;
      _showSnack('保存失败：$error');
    } finally {
      if (mounted) setState(() => _updatingIds.remove(monitor.id));
    }
  }

  Future<void> _deleteMonitor(StrategyMonitor monitor) async {
    setState(() => _updatingIds.add(monitor.id));
    try {
      await widget.monitorRepository.deleteMonitor(monitor.id);
      if (!mounted) return;
      setState(() {
        _monitors = _monitors.where((item) => item.id != monitor.id).toList();
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('删除失败：$error');
    } finally {
      if (mounted) setState(() => _updatingIds.remove(monitor.id));
    }
  }

  Future<void> _deleteScanLog(StrategyMonitorScanLog log) async {
    if (_deletingLogIds.contains(log.id)) return;
    setState(() => _deletingLogIds.add(log.id));
    try {
      await widget.monitorRepository.deleteScanLog(log.id);
      if (!mounted) return;
      setState(() {
        _scanLogs = _scanLogs.where((item) => item.id != log.id).toList();
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('日志删除失败：$error');
    } finally {
      if (mounted) setState(() => _deletingLogIds.remove(log.id));
    }
  }

  Future<void> _scanOnce({bool showSnack = true}) async {
    if (_isScanningNow) return;
    final interval = _schedulerIntervalSeconds();
    if (interval == null) {
      _showSnack('调度间隔需要在 10 到 3600 秒之间。');
      return;
    }
    setState(() => _isScanningNow = true);
    try {
      final status = await widget.monitorRepository.runSchedulerOnce(
        pollIntervalSeconds: interval,
        refresh: _schedulerRefresh,
        force: true,
      );
      if (!mounted) return;
      _applySchedulerStatus(status);
      await _reloadMonitorState();
      if (!mounted) return;
      if (showSnack) _showSnack('已完成一次策略扫描。');
    } catch (error) {
      if (!mounted) return;
      if (showSnack) _showSnack('立即扫描失败：$error');
    } finally {
      if (mounted) setState(() => _isScanningNow = false);
    }
  }

  Future<void> _reloadMonitorState() async {
    final result = await Future.wait<Object>([
      widget.monitorRepository.loadMonitors(limit: 200),
      widget.monitorRepository.loadScanLogs(limit: _scanLogLimit),
    ]);
    if (!mounted) return;
    setState(() {
      _monitors = result[0] as List<StrategyMonitor>;
      _scanLogs = result[1] as List<StrategyMonitorScanLog>;
    });
  }

  Future<void> _startScheduler({bool showSnack = true}) async {
    if (_isSchedulerUpdating) return;
    final interval = _schedulerIntervalSeconds();
    if (interval == null) {
      _showSnack('调度间隔需要在 10 到 3600 秒之间。');
      return;
    }
    setState(() => _isSchedulerUpdating = true);
    try {
      final status = await widget.monitorRepository.startScheduler(
        pollIntervalSeconds: interval,
        refresh: _schedulerRefresh,
      );
      if (!mounted) return;
      _applySchedulerStatus(status);
      if (showSnack) _showSnack(status.running ? '调度器已启动。' : '调度器配置已应用。');
    } catch (error) {
      if (!mounted) return;
      if (showSnack) _showSnack('调度器启动失败：$error');
    } finally {
      if (mounted) setState(() => _isSchedulerUpdating = false);
    }
  }

  Future<void> _stopScheduler() async {
    if (_isSchedulerUpdating) return;
    setState(() => _isSchedulerUpdating = true);
    try {
      final status = await widget.monitorRepository.stopScheduler();
      if (!mounted) return;
      _applySchedulerStatus(status);
    } catch (error) {
      if (!mounted) return;
      _showSnack('调度器停止失败：$error');
    } finally {
      if (mounted) setState(() => _isSchedulerUpdating = false);
    }
  }

  int? _schedulerIntervalSeconds() {
    final value = int.tryParse(_schedulerIntervalController.text.trim());
    if (value == null || value < 10 || value > 3600) return null;
    return value;
  }

  void _applySchedulerStatus(StrategyMonitorSchedulerStatus status) {
    setState(() {
      _schedulerStatus = status;
      _schedulerRefresh = status.refresh;
      _schedulerIntervalController.text = '${status.pollIntervalSeconds}';
    });
  }

  void _replaceMonitor(StrategyMonitor updated) {
    final index = _monitors.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    _monitors = [
      ..._monitors.take(index),
      updated,
      ..._monitors.skip(index + 1),
    ];
  }

  Map<String, Object?>? _readParameters(StrategyDefinition strategy) {
    final parameters = <String, Object?>{};
    for (final spec in strategyParameterSpecsFor(strategy.code)) {
      final raw = (_parameterValues[spec.key] ?? spec.fallback).trim();
      switch (spec.valueType) {
        case StrategyParameterValueType.positiveInt:
          final value = _positiveInt(raw);
          if (value == null) return null;
          parameters[spec.key] = value;
        case StrategyParameterValueType.boundedDouble:
          final value = double.tryParse(raw);
          if (value == null || !value.isFinite) return null;
          parameters[spec.key] = value;
        case StrategyParameterValueType.option:
          if (raw.isEmpty) return null;
          parameters[spec.key] = raw;
        case StrategyParameterValueType.multiOption:
          final values = _readMultiOption(raw, spec);
          if (values == null || values.length < 2) return null;
          parameters[spec.key] = values;
      }
    }
    return parameters;
  }

  List<String>? _readMultiOption(String raw, StrategyParameterSpec spec) {
    final allowed = {for (final option in spec.options) option.value};
    final values = raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (values.any((value) => !allowed.contains(value))) return null;
    return values;
  }

  int? _positiveInt(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 1) return null;
    return value;
  }

  int? _nonNegativeInt(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 0) return null;
    return value;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            controller: _listController,
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
                    child: PageTitle(title: '策略监控', subtitle: '选择股票、策略和推送候选'),
                  ),
                  IconButton.outlined(
                    tooltip: '刷新',
                    onPressed: _isLoading ? null : _load,
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
              if (_isLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (_error != null)
                EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: '加载失败',
                  subtitle: '请刷新后重试。',
                  actionLabel: '重试',
                  onAction: _load,
                )
              else ...[
                _SchedulerStatusPanel(
                  status: _schedulerStatus,
                  intervalController: _schedulerIntervalController,
                  refresh: _schedulerRefresh,
                  isUpdating: _isSchedulerUpdating,
                  isScanningNow: _isScanningNow,
                  onRefreshChanged: (value) =>
                      setState(() => _schedulerRefresh = value),
                  onStart: _startScheduler,
                  onStop: _stopScheduler,
                  onScanNow: _scanOnce,
                ),
                const SizedBox(height: 16),
                _ScanLogPanel(
                  logs: _scanLogs,
                  deletingIds: _deletingLogIds,
                  onDelete: _deleteScanLog,
                ),
                const SizedBox(height: 16),
                _MonitorCreatePanel(
                  positions: widget.positions,
                  strategies: _strategies,
                  selectedPosition: _selectedPosition,
                  selectedStrategy: _selectedStrategy,
                  period: _period,
                  enabled: _enabled,
                  pushCandidate: _pushCandidate,
                  editingMonitor: _editingMonitor,
                  intervalController: _intervalController,
                  cooldownController: _cooldownController,
                  parameterValues: _parameterValues,
                  isCreating: _isCreating,
                  onPositionChanged: (code) {
                    setState(() {
                      _selectedPosition = widget.positions.firstWhere(
                        (item) => item.code == code,
                      );
                    });
                  },
                  onStrategyChanged: _selectStrategy,
                  onPeriodChanged: (value) => setState(() => _period = value),
                  onEnabledChanged: (value) => setState(() => _enabled = value),
                  onPushChanged: (value) =>
                      setState(() => _pushCandidate = value),
                  onParameterChanged: (key, value) {
                    setState(() => _parameterValues[key] = value);
                  },
                  onCancelEdit: _cancelEditMonitor,
                  onSubmit: _submitMonitorForm,
                ),
                const SizedBox(height: 16),
                if (_monitors.isEmpty)
                  const ReadOnlyEmptyState(
                    icon: Icons.rule_rounded,
                    title: '暂无策略监控',
                    subtitle: '创建后，后端会按监控配置扫描并生成信号。',
                  )
                else
                  ..._monitors.map(
                    (monitor) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MonitorTile(
                        monitor: monitor,
                        isUpdating: _updatingIds.contains(monitor.id),
                        onEnabledChanged: (value) =>
                            _updateMonitor(monitor, enabled: value),
                        onPushChanged: monitor.enabled
                            ? (value) =>
                                  _updateMonitor(monitor, pushCandidate: value)
                            : null,
                        onEdit: () => _startEditMonitor(monitor),
                        onDelete: () => _deleteMonitor(monitor),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedulerStatusPanel extends StatelessWidget {
  const _SchedulerStatusPanel({
    required this.status,
    required this.intervalController,
    required this.refresh,
    required this.isUpdating,
    required this.isScanningNow,
    required this.onRefreshChanged,
    required this.onStart,
    required this.onStop,
    required this.onScanNow,
  });

  final StrategyMonitorSchedulerStatus? status;
  final TextEditingController intervalController;
  final bool refresh;
  final bool isUpdating;
  final bool isScanningNow;
  final ValueChanged<bool> onRefreshChanged;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onScanNow;

  @override
  Widget build(BuildContext context) {
    final current = status;
    final running = current?.running ?? false;
    final scanning = current?.scanning ?? false;
    final statusColor = running
        ? const Color(0xFF20C997)
        : secondaryTextColor(context);
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
                  '调度器状态',
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isUpdating)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (isScanningNow)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: running ? '运行中' : '已停止',
                icon: Icons.power_settings_new_rounded,
                color: statusColor,
              ),
              _InfoChip(
                label: scanning ? '扫描中' : '空闲',
                icon: Icons.radar_rounded,
              ),
              _InfoChip(
                label: current?.enabledByEnv == true ? '环境自启' : '手动控制',
                icon: Icons.settings_power_rounded,
              ),
              _InfoChip(
                label: refresh ? '刷新行情' : '使用缓存',
                icon: Icons.sync_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: intervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '轮询间隔(秒)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('刷新行情'),
                  value: refresh,
                  onChanged: isUpdating ? null : onRefreshChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '上次运行：${_timeLabel(current?.lastRunAt)} · ${_schedulerResultLabel(current)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
          ),
          if (current?.lastError != null) ...[
            const SizedBox(height: 6),
            Text(
              '错误：${current!.lastError}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFF4D67),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isUpdating ? null : onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(running ? '应用配置' : '启动'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: '停止',
                onPressed: isUpdating || !running ? null : onStop,
                icon: const Icon(Icons.stop_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isScanningNow ? null : onScanNow,
              icon: isScanningNow
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar_rounded, size: 18),
              label: const Text('扫描一次'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanLogPanel extends StatelessWidget {
  const _ScanLogPanel({
    required this.logs,
    required this.deletingIds,
    required this.onDelete,
  });

  final List<StrategyMonitorScanLog> logs;
  final Set<String> deletingIds;
  final ValueChanged<StrategyMonitorScanLog> onDelete;

  @override
  Widget build(BuildContext context) {
    final visibleLogs = logs.take(_scanLogLimit).toList();
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
                  '扫描日志',
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _InfoChip(
                label: visibleLogs.isEmpty ? '暂无' : '最新 ${visibleLogs.length}',
                icon: Icons.receipt_long_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleLogs.isEmpty)
            Text(
              '调度器执行后会记录触发、未触发、行情异常和冷却原因。',
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
              ),
            )
          else
            _ScanLogList(
              logs: visibleLogs,
              deletingIds: deletingIds,
              onDelete: onDelete,
            ),
        ],
      ),
    );
  }
}

class _ScanLogList extends StatelessWidget {
  const _ScanLogList({
    required this.logs,
    required this.deletingIds,
    required this.onDelete,
  });

  final List<StrategyMonitorScanLog> logs;
  final Set<String> deletingIds;
  final ValueChanged<StrategyMonitorScanLog> onDelete;

  @override
  Widget build(BuildContext context) {
    if (logs.length <= 3) {
      return Column(
        children: [
          for (var index = 0; index < logs.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _ScanLogTile(
              log: logs[index],
              isDeleting: deletingIds.contains(logs[index].id),
              onDelete: () => onDelete(logs[index]),
            ),
          ],
        ],
      );
    }

    return SizedBox(
      height: 324,
      child: ListView.separated(
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: logs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final log = logs[index];
          return _ScanLogTile(
            log: log,
            isDeleting: deletingIds.contains(log.id),
            onDelete: () => onDelete(log),
          );
        },
      ),
    );
  }
}

class _ScanLogTile extends StatelessWidget {
  const _ScanLogTile({
    required this.log,
    required this.isDeleting,
    required this.onDelete,
  });

  final StrategyMonitorScanLog log;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _scanLogStatusColor(context, log.status);
    final detailLabel = _scanLogDetailLabel(log);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_scanLogStatusIcon(log.status), color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_scanLogStatusLabel(log.status)} · ${log.code}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_strategyCodeLabel(log.strategyCode)} · ${_scanLogStageLabel(log.stage)} · ${_timeLabel(log.scannedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (log.message.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    log.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (detailLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detailLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '删除日志',
            onPressed: isDeleting ? null : onDelete,
            icon: isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _MonitorCreatePanel extends StatelessWidget {
  const _MonitorCreatePanel({
    required this.positions,
    required this.strategies,
    required this.selectedPosition,
    required this.selectedStrategy,
    required this.period,
    required this.enabled,
    required this.pushCandidate,
    required this.editingMonitor,
    required this.intervalController,
    required this.cooldownController,
    required this.parameterValues,
    required this.isCreating,
    required this.onPositionChanged,
    required this.onStrategyChanged,
    required this.onPeriodChanged,
    required this.onEnabledChanged,
    required this.onPushChanged,
    required this.onParameterChanged,
    required this.onCancelEdit,
    required this.onSubmit,
  });

  final List<StockPosition> positions;
  final List<StrategyDefinition> strategies;
  final StockPosition? selectedPosition;
  final StrategyDefinition? selectedStrategy;
  final String period;
  final bool enabled;
  final bool pushCandidate;
  final StrategyMonitor? editingMonitor;
  final TextEditingController intervalController;
  final TextEditingController cooldownController;
  final Map<String, String> parameterValues;
  final bool isCreating;
  final ValueChanged<String> onPositionChanged;
  final ValueChanged<String> onStrategyChanged;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onPushChanged;
  final void Function(String key, String value) onParameterChanged;
  final VoidCallback onCancelEdit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final strategy = selectedStrategy;
    final specs = strategy == null
        ? const <StrategyParameterSpec>[]
        : strategyParameterSpecsFor(strategy.code);
    final canCreate =
        selectedPosition != null && strategy != null && !isCreating;
    final isEditing = editingMonitor != null;

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
                  isEditing ? '修改监控' : '新增监控',
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isEditing)
                TextButton.icon(
                  onPressed: isCreating ? null : onCancelEdit,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('取消'),
                ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 4),
            Text(
              '${editingMonitor!.name} · ${editingMonitor!.code}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedPosition?.code,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '股票',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: positions
                .map(
                  (position) => DropdownMenuItem(
                    value: position.code,
                    child: Text(
                      '${position.name} · ${position.code}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: positions.isEmpty
                ? null
                : (value) {
                    if (value != null) onPositionChanged(value);
                  },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedStrategy?.code,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '策略',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: strategies
                .map(
                  (strategy) => DropdownMenuItem(
                    value: strategy.code,
                    child: Text(strategy.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: strategies.isEmpty
                ? null
                : (value) {
                    if (value != null) onStrategyChanged(value);
                  },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: period,
                  decoration: const InputDecoration(
                    labelText: '周期',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'day', child: Text('日K')),
                    DropdownMenuItem(value: '60m', child: Text('60分钟')),
                    DropdownMenuItem(value: '1m', child: Text('1分钟')),
                  ],
                  onChanged: (value) {
                    if (value != null) onPeriodChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: intervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '间隔(分钟)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cooldownController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '冷却(分钟)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (specs.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...specs.map(
              (spec) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ParameterField(
                  key: ValueKey('${strategy!.code}:${spec.key}'),
                  spec: spec,
                  value: parameterValues[spec.key] ?? spec.fallback,
                  onChanged: (value) => onParameterChanged(spec.key, value),
                ),
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用'),
                  value: enabled,
                  onChanged: onEnabledChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('推送'),
                  value: pushCandidate,
                  onChanged: enabled ? onPushChanged : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canCreate ? onSubmit : null,
              icon: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isEditing ? Icons.save_rounded : Icons.add_task_rounded,
                      size: 18,
                    ),
              label: Text(isEditing ? '保存监控' : '创建监控'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParameterField extends StatelessWidget {
  const _ParameterField({
    super.key,
    required this.spec,
    required this.value,
    required this.onChanged,
  });

  final StrategyParameterSpec spec;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (spec.valueType == StrategyParameterValueType.multiOption) {
      final selected = value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      return InputDecorator(
        decoration: InputDecoration(
          labelText: spec.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in spec.options)
              FilterChip(
                label: Text(option.label),
                selected: selected.contains(option.value),
                onSelected: (checked) {
                  final next = {...selected};
                  if (checked) {
                    next.add(option.value);
                  } else {
                    next.remove(option.value);
                  }
                  onChanged(next.join(','));
                },
              ),
          ],
        ),
      );
    }
    if (spec.valueType == StrategyParameterValueType.option) {
      return DropdownButtonFormField<String>(
        initialValue: spec.options.any((option) => option.value == value)
            ? value
            : spec.fallback,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: spec.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: spec.options
            .map(
              (option) => DropdownMenuItem(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      );
    }
    return TextFormField(
      initialValue: value,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: spec.label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _MonitorTile extends StatelessWidget {
  const _MonitorTile({
    required this.monitor,
    required this.isUpdating,
    required this.onEnabledChanged,
    required this.onPushChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final StrategyMonitor monitor;
  final bool isUpdating;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool>? onPushChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = monitor.enabled
        ? const Color(0xFF20C997)
        : secondaryTextColor(context);
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
                  monitor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isUpdating)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                IconButton(
                  tooltip: '编辑',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${monitor.code} · ${monitor.strategyName} · ${monitor.parameterLabel}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: _periodLabel(monitor.period),
                icon: Icons.timeline_rounded,
              ),
              _InfoChip(
                label: '${monitor.scanIntervalMinutes}分钟',
                icon: Icons.schedule_rounded,
              ),
              _InfoChip(
                label: monitor.pushCandidate ? '推送候选' : '不推送',
                icon: Icons.notifications_rounded,
              ),
              _InfoChip(
                label: monitor.enabled ? '启用中' : '已停用',
                icon: Icons.circle,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '上次扫描：${_timeLabel(monitor.lastScannedAt)} · 上次触发：${_timeLabel(monitor.lastTriggeredAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用'),
                  value: monitor.enabled,
                  onChanged: isUpdating ? null : onEnabledChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('推送'),
                  value: monitor.pushCandidate,
                  onChanged: isUpdating ? null : onPushChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? secondaryTextColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _marketFromCode(String code) {
  final upper = code.toUpperCase();
  if (upper.startsWith('US.')) return 'US';
  if (upper.startsWith('SH.')) return 'SH';
  if (upper.startsWith('SZ.')) return 'SZ';
  return 'HK';
}

StockPosition? _selectInitialPosition(
  List<StockPosition> positions,
  String? initialCode,
) {
  if (positions.isEmpty) return null;
  final normalized = initialCode?.trim().toUpperCase() ?? '';
  if (normalized.isNotEmpty) {
    for (final position in positions) {
      if (position.code.toUpperCase() == normalized) return position;
    }
  }
  return positions.first;
}

Map<String, String> _parameterTextValues(StrategyMonitor monitor) {
  final values = <String, String>{};
  for (final entry in monitor.parameters.entries) {
    final value = entry.value;
    if (value != null) values[entry.key] = '$value';
  }
  for (final spec in strategyParameterSpecsFor(monitor.strategyCode)) {
    values.putIfAbsent(spec.key, () => spec.fallback);
  }
  return values;
}

String _periodLabel(String period) {
  return switch (period) {
    '1m' => '1分钟',
    '60m' => '60分钟',
    _ => '日K',
  };
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

String _scanLogStatusLabel(String status) {
  return switch (status) {
    'triggered' => '已触发',
    'not_triggered' => '未触发',
    'cooldown' => '冷却中',
    'insufficient_klines' => 'K线不足',
    'market_error' => '行情异常',
    'strategy_error' => '策略异常',
    'duplicate_signal' => '已去重',
    _ => '记录',
  };
}

String _scanLogStageLabel(String stage) {
  return switch (stage) {
    'load_candles' => '行情',
    'strategy_lookup' => '策略',
    'minimum_candles' => '样本',
    'evaluate' => '评估',
    'dedupe' => '去重',
    'dispatch' => '分发',
    'cooldown' => '冷却',
    _ => stage,
  };
}

String _strategyCodeLabel(String strategyCode) {
  return switch (strategyCode) {
    'atr_trailing_stop' => 'ATR止损',
    'composite_factor' => '组合因子',
    'ma_breakdown_stop' => '均线止损',
    'ma_cross' => '均线交叉',
    'price_break_ma' => '突破均线',
    'rsi_oversold_rebound' => 'RSI反弹',
    'rsi_reversal' => 'RSI反转',
    'trend_score' => '趋势评分',
    'volume_breakout' => '放量突破',
    _ => strategyCode,
  };
}

IconData _scanLogStatusIcon(String status) {
  return switch (status) {
    'triggered' => Icons.flash_on_rounded,
    'not_triggered' => Icons.remove_done_rounded,
    'cooldown' => Icons.hourglass_bottom_rounded,
    'insufficient_klines' => Icons.timeline_rounded,
    'market_error' => Icons.cloud_off_rounded,
    'strategy_error' => Icons.error_outline_rounded,
    'duplicate_signal' => Icons.filter_alt_off_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

Color _scanLogStatusColor(BuildContext context, String status) {
  return switch (status) {
    'triggered' => const Color(0xFF20C997),
    'market_error' || 'strategy_error' => const Color(0xFFFF4D67),
    'cooldown' => const Color(0xFF4DB6FF),
    'duplicate_signal' => const Color(0xFFE6A93A),
    _ => secondaryTextColor(context),
  };
}

String _scanLogDetailLabel(StrategyMonitorScanLog log) {
  final parts = <String>[];
  final latestClose = log.detail['latest_close'];
  if (latestClose is num) {
    parts.add('最新价 ${latestClose.toStringAsFixed(2)}');
  }
  final candles = log.detail['candles'];
  final minimumCandles = log.detail['minimum_candles'];
  if (candles is num && minimumCandles is num) {
    parts.add('样本 ${candles.toInt()}/${minimumCandles.toInt()}');
  }
  final signalType = log.detail['signal_type'];
  if (signalType is String && signalType.isNotEmpty) {
    parts.add(signalType);
  }
  final loadError = log.detail['load_error'];
  if (loadError is String && loadError.isNotEmpty) {
    parts.add('行情：$loadError');
  }
  final pushError = log.detail['push_error'];
  if (pushError is String && pushError.isNotEmpty) {
    parts.add('推送：$pushError');
  }
  return parts.join(' · ');
}

String _schedulerResultLabel(StrategyMonitorSchedulerStatus? status) {
  final result = status?.lastResult ?? const <String, Object?>{};
  if (result.isEmpty) return '暂无扫描结果';
  final scanned = result['scanned_count'] ?? 0;
  final created = result['created_count'] ?? 0;
  final skipped = result['skipped_count'] ?? 0;
  final errors = result['error_count'] ?? 0;
  return '扫描 $scanned · 新增 $created · 跳过 $skipped · 错误 $errors';
}
