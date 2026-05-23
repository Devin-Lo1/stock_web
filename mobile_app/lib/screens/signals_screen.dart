import 'dart:async';

import 'package:flutter/material.dart';

import '../models/signal_scan_config.dart';
import '../models/stock_position.dart';
import '../models/strategy_definition.dart';
import '../models/trade_signal.dart';
import '../repositories/backtest_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/strategy_monitor_repository.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_title.dart';
import '../widgets/signal/signal_presentation.dart';
import '../widgets/signal/signal_tile.dart';
import '../utils/theme_helpers.dart';
import 'push_records_screen.dart';
import 'strategy_monitor_screen.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({
    super.key,
    required this.signals,
    required this.isLoading,
    required this.isScanning,
    required this.usingBackendSignals,
    required this.positions,
    required this.onRefresh,
    required this.onScan,
    required this.backtestRepository,
    required this.strategyMonitorRepository,
    required this.notificationRepository,
    this.onLoadCategory,
    this.onIgnoreSignal,
    this.onLoadConfigs,
    this.onUpdateConfig,
  });

  final List<TradeSignal> signals;
  final bool isLoading;
  final bool isScanning;
  final bool usingBackendSignals;
  final List<StockPosition> positions;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onScan;
  final BacktestRepository backtestRepository;
  final StrategyMonitorRepository strategyMonitorRepository;
  final NotificationRepository notificationRepository;
  final Future<List<TradeSignal>> Function(SignalCategory category)?
  onLoadCategory;
  final Future<void> Function(TradeSignal signal)? onIgnoreSignal;
  final Future<List<SignalScanConfig>> Function()? onLoadConfigs;
  final Future<SignalScanConfig> Function(
    String configId, {
    bool? enabled,
    bool? pushCandidate,
  })?
  onUpdateConfig;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        children: [
          PageTitle(
            title: '信号',
            subtitle: usingBackendSignals
                ? '${signals.length} 条后端策略信号 · 已落库'
                : '${signals.length} 条本地风控信号 · 待扫描',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isScanning ? null : onScan,
                  icon: isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar_rounded, size: 18),
                  label: Text(isScanning ? '扫描中' : '扫描信号'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: '刷新',
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton.outlined(
                tooltip: '信号设置',
                onPressed: onLoadConfigs == null || onUpdateConfig == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => SignalConfigScreen(
                              onLoadConfigs: onLoadConfigs!,
                              onUpdateConfig: onUpdateConfig!,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: '策略监控',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => StrategyMonitorScreen(
                        positions: positions,
                        backtestRepository: backtestRepository,
                        monitorRepository: strategyMonitorRepository,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.rule_rounded),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: '推送记录',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => PushRecordsScreen(
                        notificationRepository: notificationRepository,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.fact_check_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (signals.isEmpty)
            const ReadOnlyEmptyState(
              icon: Icons.notifications_none_rounded,
              title: '暂无信号',
              subtitle: '扫描后，触发条件的策略信号会显示在这里。',
            )
          else
            ...SignalCategory.values.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SignalCategoryTile(
                  category: category,
                  signals: _signalsForCategory(category),
                  onLoadCategory: onLoadCategory,
                  onIgnoreSignal: onIgnoreSignal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<TradeSignal> _signalsForCategory(SignalCategory category) {
    if (category == SignalCategory.important) {
      return signals
          .where(
            (signal) => signal.readStatus != 'ignored' && signal.level == '高',
          )
          .toList();
    }
    if (category == SignalCategory.ignored) {
      return signals.where((signal) => signal.readStatus == 'ignored').toList();
    }
    return signals.where((signal) => signal.category == category).toList();
  }
}

class _SignalCategoryTile extends StatelessWidget {
  const _SignalCategoryTile({
    required this.category,
    required this.signals,
    required this.onLoadCategory,
    required this.onIgnoreSignal,
  });

  final SignalCategory category;
  final List<TradeSignal> signals;
  final Future<List<TradeSignal>> Function(SignalCategory category)?
  onLoadCategory;
  final Future<void> Function(TradeSignal signal)? onIgnoreSignal;

  @override
  Widget build(BuildContext context) {
    final latest = signals.isEmpty ? null : signals.first;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: signals.isEmpty && onLoadCategory == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => SignalCategoryScreen(
                    category: category,
                    signals: signals,
                    onLoadSignals: onLoadCategory,
                    onIgnoreSignal: onIgnoreSignal,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.title,
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${signals.length}',
                        style: TextStyle(
                          color: category.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latest == null
                        ? category.subtitle
                        : '${latest.stock} · ${latest.conditionLabel.isEmpty ? latest.type : latest.conditionLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: signals.isEmpty ? mutedIconColor(context) : category.color,
            ),
          ],
        ),
      ),
    );
  }
}

class SignalCategoryScreen extends StatelessWidget {
  const SignalCategoryScreen({
    super.key,
    required this.category,
    required this.signals,
    this.onLoadSignals,
    this.onIgnoreSignal,
  });

  final SignalCategory category;
  final List<TradeSignal> signals;
  final Future<List<TradeSignal>> Function(SignalCategory category)?
  onLoadSignals;
  final Future<void> Function(TradeSignal signal)? onIgnoreSignal;

  @override
  Widget build(BuildContext context) {
    return _SignalCategoryScaffold(
      category: category,
      initialSignals: signals,
      onLoadSignals: onLoadSignals,
      onIgnoreSignal: onIgnoreSignal,
    );
  }
}

class _SignalCategoryScaffold extends StatefulWidget {
  const _SignalCategoryScaffold({
    required this.category,
    required this.initialSignals,
    required this.onLoadSignals,
    required this.onIgnoreSignal,
  });

  final SignalCategory category;
  final List<TradeSignal> initialSignals;
  final Future<List<TradeSignal>> Function(SignalCategory category)?
  onLoadSignals;
  final Future<void> Function(TradeSignal signal)? onIgnoreSignal;

  @override
  State<_SignalCategoryScaffold> createState() =>
      _SignalCategoryScaffoldState();
}

class _SignalCategoryScaffoldState extends State<_SignalCategoryScaffold> {
  late List<TradeSignal> _signals = widget.initialSignals;
  String _selectedCode = '';
  String _selectedStrategyCode = '';
  String _selectedSignalType = '';
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.onLoadSignals != null) {
      unawaited(_loadSignals());
    }
  }

  Future<void> _loadSignals() async {
    final loader = widget.onLoadSignals;
    if (loader == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final signals = await loader(widget.category);
      if (!mounted) return;
      setState(() {
        _signals = widget.category == SignalCategory.ignored
            ? signals
            : signals
                  .where((signal) => signal.readStatus != 'ignored')
                  .toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TradeSignal> get _visibleSignals {
    return _signals.where((signal) {
      if (_selectedCode.isNotEmpty && signal.code != _selectedCode) {
        return false;
      }
      if (_selectedStrategyCode.isNotEmpty &&
          signal.strategyCode != _selectedStrategyCode) {
        return false;
      }
      if (_selectedSignalType.isNotEmpty &&
          signal.signalType != _selectedSignalType) {
        return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedCode = '';
      _selectedStrategyCode = '';
      _selectedSignalType = '';
    });
  }

  Future<void> _ignoreSignal(TradeSignal signal) async {
    final ignore = widget.onIgnoreSignal;
    if (ignore == null || signal.id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('忽略历史信号'),
        content: const Text('这条信号会移到“已忽略”，不再出现在当前分类列表。确认忽略吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('忽略'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ignore(signal);
      if (!mounted) return;
      setState(() {
        _signals = _signals.where((item) => item.id != signal.id).toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('信号已忽略')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('信号忽略失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleSignals = _visibleSignals;
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: ListView(
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
                Expanded(
                  child: PageTitle(
                    title: widget.category.title,
                    subtitle:
                        '${_signals.length} 条信号 · ${widget.category.subtitle}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!_isLoading && _error == null && _signals.isNotEmpty) ...[
              _SignalFilterBar(
                signals: _signals,
                selectedCode: _selectedCode,
                selectedStrategyCode: _selectedStrategyCode,
                selectedSignalType: _selectedSignalType,
                onCodeChanged: (value) => setState(() => _selectedCode = value),
                onStrategyChanged: (value) =>
                    setState(() => _selectedStrategyCode = value),
                onSignalTypeChanged: (value) =>
                    setState(() => _selectedSignalType = value),
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
            ],
            if (_isLoading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (_error != null)
              EmptyState(
                icon: Icons.error_outline_rounded,
                title: '加载失败',
                subtitle: '请刷新后重试。',
                actionLabel: '重试',
                onAction: _loadSignals,
              )
            else if (_signals.isEmpty)
              const ReadOnlyEmptyState(
                icon: Icons.notifications_none_rounded,
                title: '暂无信号',
                subtitle: '该分类下暂时没有触发记录。',
              )
            else if (visibleSignals.isEmpty)
              EmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: '没有匹配信号',
                subtitle: '当前筛选条件下没有信号记录。',
                actionLabel: '清空筛选',
                onAction: _clearFilters,
              )
            else
              ...visibleSignals.map(
                (signal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SignalTile(
                    signal: signal,
                    onIgnore: widget.category == SignalCategory.ignored
                        ? null
                        : _ignoreSignal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignalFilterBar extends StatelessWidget {
  const _SignalFilterBar({
    required this.signals,
    required this.selectedCode,
    required this.selectedStrategyCode,
    required this.selectedSignalType,
    required this.onCodeChanged,
    required this.onStrategyChanged,
    required this.onSignalTypeChanged,
    required this.onClear,
  });

  final List<TradeSignal> signals;
  final String selectedCode;
  final String selectedStrategyCode;
  final String selectedSignalType;
  final ValueChanged<String> onCodeChanged;
  final ValueChanged<String> onStrategyChanged;
  final ValueChanged<String> onSignalTypeChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final stockOptions = _stockOptions(signals);
    final strategyOptions = _strategyOptions(signals);
    final signalTypeOptions = _signalTypeOptions(signals);
    final hasFilter =
        selectedCode.isNotEmpty ||
        selectedStrategyCode.isNotEmpty ||
        selectedSignalType.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        children: [
          _FilterDropdown(
            label: '股票',
            value: _validValue(selectedCode, stockOptions),
            options: stockOptions,
            onChanged: onCodeChanged,
          ),
          const SizedBox(height: 10),
          _FilterDropdown(
            label: '策略',
            value: _validValue(selectedStrategyCode, strategyOptions),
            options: strategyOptions,
            onChanged: onStrategyChanged,
          ),
          const SizedBox(height: 10),
          _FilterDropdown(
            label: '信号',
            value: _validValue(selectedSignalType, signalTypeOptions),
            options: signalTypeOptions,
            onChanged: onSignalTypeChanged,
          ),
          if (hasFilter) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('清空筛选'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<_FilterOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('全部')),
        ...options.map(
          (option) => DropdownMenuItem(
            value: option.value,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (value) => onChanged(value ?? ''),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String value;
  final String label;
}

String _validValue(String value, List<_FilterOption> options) {
  if (value.isEmpty) return '';
  return options.any((option) => option.value == value) ? value : '';
}

List<_FilterOption> _stockOptions(List<TradeSignal> signals) {
  final labels = <String, String>{};
  for (final signal in signals) {
    final value = signal.code.isNotEmpty ? signal.code : signal.stock;
    if (value.isEmpty) continue;
    labels.putIfAbsent(
      value,
      () => signal.stock.isEmpty ? value : signal.stock,
    );
  }
  return _sortedOptions(labels);
}

List<_FilterOption> _strategyOptions(List<TradeSignal> signals) {
  final labels = <String, String>{};
  for (final signal in signals) {
    if (signal.strategyCode.isEmpty) continue;
    labels.putIfAbsent(
      signal.strategyCode,
      () => signal.strategyName.isEmpty
          ? strategyDisplayNameForCode(signal.strategyCode)
          : strategyDisplayNameForCode(
              signal.strategyCode,
              fallbackName: signal.strategyName,
            ),
    );
  }
  return _sortedOptions(labels);
}

List<_FilterOption> _signalTypeOptions(List<TradeSignal> signals) {
  final labels = <String, String>{};
  for (final signal in signals) {
    if (signal.signalType.isEmpty) continue;
    labels.putIfAbsent(
      signal.signalType,
      () => signal.type.isEmpty ? signal.signalType : signal.type,
    );
  }
  return _sortedOptions(labels);
}

List<_FilterOption> _sortedOptions(Map<String, String> labels) {
  final options = labels.entries
      .map((entry) => _FilterOption(entry.key, entry.value))
      .toList();
  options.sort((left, right) => left.label.compareTo(right.label));
  return options;
}

class SignalConfigScreen extends StatefulWidget {
  const SignalConfigScreen({
    super.key,
    required this.onLoadConfigs,
    required this.onUpdateConfig,
  });

  final Future<List<SignalScanConfig>> Function() onLoadConfigs;
  final Future<SignalScanConfig> Function(
    String configId, {
    bool? enabled,
    bool? pushCandidate,
  })
  onUpdateConfig;

  @override
  State<SignalConfigScreen> createState() => _SignalConfigScreenState();
}

class _SignalConfigScreenState extends State<SignalConfigScreen> {
  List<SignalScanConfig> _configs = const [];
  final Set<String> _updatingIds = <String>{};
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfigs());
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final configs = await widget.onLoadConfigs();
      if (!mounted) return;
      setState(() => _configs = configs);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateConfig(
    SignalScanConfig config, {
    bool? enabled,
    bool? pushCandidate,
  }) async {
    setState(() => _updatingIds.add(config.id));
    try {
      final updated = await widget.onUpdateConfig(
        config.id,
        enabled: enabled,
        pushCandidate: pushCandidate,
      );
      if (!mounted) return;
      setState(() {
        final index = _configs.indexWhere((item) => item.id == updated.id);
        if (index == -1) return;
        _configs = [
          ..._configs.take(index),
          updated,
          ..._configs.skip(index + 1),
        ];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _updatingIds.remove(config.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: ListView(
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
                  child: PageTitle(title: '信号设置', subtitle: '选择扫描策略和推送候选'),
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
                onAction: _loadConfigs,
              )
            else if (_configs.isEmpty)
              const ReadOnlyEmptyState(
                icon: Icons.tune_rounded,
                title: '暂无配置',
                subtitle: '后端还没有返回信号扫描配置。',
              )
            else
              ..._configs.map(
                (config) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SignalConfigTile(
                    config: config,
                    isUpdating: _updatingIds.contains(config.id),
                    onEnabledChanged: (value) =>
                        _updateConfig(config, enabled: value),
                    onPushChanged: config.enabled
                        ? (value) => _updateConfig(config, pushCandidate: value)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignalConfigTile extends StatelessWidget {
  const _SignalConfigTile({
    required this.config,
    required this.isUpdating,
    required this.onEnabledChanged,
    required this.onPushChanged,
  });

  final SignalScanConfig config;
  final bool isUpdating;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool>? onPushChanged;

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
                  strategyDisplayNameForCode(
                    config.strategyCode,
                    fallbackName: config.strategyName,
                  ),
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
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${config.strategyCode} · ${config.parameterLabel}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用'),
                  value: config.enabled,
                  onChanged: isUpdating ? null : onEnabledChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('推送'),
                  value: config.pushCandidate,
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
