import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../models/strategy_definition.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';
import 'quant_common_widgets.dart';

class QuantHistoryPanel extends StatelessWidget {
  const QuantHistoryPanel({
    super.key,
    required this.runs,
    required this.strategies,
    required this.stockCodeController,
    required this.strategyFilter,
    required this.statusFilter,
    required this.isLoading,
    required this.onReload,
    required this.onApplyFilters,
    required this.onClearFilters,
    required this.onStrategyFilterChanged,
    required this.onStatusFilterChanged,
    required this.onSelected,
    required this.onDelete,
    required this.onRename,
    required this.onDeleteAll,
  });

  final List<BacktestRun> runs;
  final List<StrategyDefinition> strategies;
  final TextEditingController stockCodeController;
  final String? strategyFilter;
  final String? statusFilter;
  final bool isLoading;
  final VoidCallback onReload;
  final VoidCallback onApplyFilters;
  final VoidCallback onClearFilters;
  final ValueChanged<String?> onStrategyFilterChanged;
  final ValueChanged<String?> onStatusFilterChanged;
  final ValueChanged<BacktestRun> onSelected;
  final ValueChanged<BacktestRun> onDelete;
  final ValueChanged<BacktestRun> onRename;
  final VoidCallback onDeleteAll;

  @override
  Widget build(BuildContext context) {
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuantPanelHeader(
            title: '历史回测',
            icon: Icons.history_rounded,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: isLoading || runs.isEmpty ? null : onDeleteAll,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: '删除全部历史回测',
                ),
                IconButton(
                  onPressed: isLoading ? null : onReload,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: '刷新历史回测',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _HistoryFilters(
            strategies: strategies,
            stockCodeController: stockCodeController,
            strategyFilter: strategyFilter,
            statusFilter: statusFilter,
            isLoading: isLoading,
            onApplyFilters: onApplyFilters,
            onClearFilters: onClearFilters,
            onStrategyFilterChanged: onStrategyFilterChanged,
            onStatusFilterChanged: onStatusFilterChanged,
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const LinearProgressIndicator()
          else if (runs.isEmpty)
            Text('暂无历史回测', style: TextStyle(color: secondaryTextColor(context)))
          else
            Column(
              children: [
                for (final run in runs)
                  _BacktestHistoryTile(
                    run: run,
                    strategyName: _strategyName(strategies, run.strategyCode),
                    onTap: () => onSelected(run),
                    onDelete: () => onDelete(run),
                    onRename: () => onRename(run),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.strategies,
    required this.stockCodeController,
    required this.strategyFilter,
    required this.statusFilter,
    required this.isLoading,
    required this.onApplyFilters,
    required this.onClearFilters,
    required this.onStrategyFilterChanged,
    required this.onStatusFilterChanged,
  });

  final List<StrategyDefinition> strategies;
  final TextEditingController stockCodeController;
  final String? strategyFilter;
  final String? statusFilter;
  final bool isLoading;
  final VoidCallback onApplyFilters;
  final VoidCallback onClearFilters;
  final ValueChanged<String?> onStrategyFilterChanged;
  final ValueChanged<String?> onStatusFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: stockCodeController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: '筛选股票',
            suffixIcon: IconButton(
              onPressed: isLoading ? null : onApplyFilters,
              icon: const Icon(Icons.search_rounded),
              tooltip: '应用筛选',
            ),
          ),
          onSubmitted: (_) => onApplyFilters(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: strategyFilter,
                decoration: const InputDecoration(labelText: '策略'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部策略')),
                  for (final strategy in strategies)
                    DropdownMenuItem(
                      value: strategy.code,
                      child: Text(strategy.name),
                    ),
                ],
                onChanged: isLoading ? null : onStrategyFilterChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: statusFilter,
                decoration: const InputDecoration(labelText: '状态'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部状态')),
                  DropdownMenuItem(value: 'completed', child: Text('完成')),
                  DropdownMenuItem(value: 'failed', child: Text('失败')),
                  DropdownMenuItem(value: 'running', child: Text('运行')),
                  DropdownMenuItem(value: 'created', child: Text('创建')),
                ],
                onChanged: isLoading ? null : onStatusFilterChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('清空筛选'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: isLoading ? null : onApplyFilters,
                icon: const Icon(Icons.filter_alt_rounded),
                label: const Text('应用筛选'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BacktestHistoryTile extends StatelessWidget {
  const _BacktestHistoryTile({
    required this.run,
    required this.strategyName,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  final BacktestRun run;
  final String strategyName;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final totalReturn = run.summaryDouble('total_return') * 100;
    final hasReturn = run.summary.containsKey('total_return');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 54,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor(run.status).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _statusText(run.status),
                style: TextStyle(
                  color: _statusColor(run.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    run.name.isEmpty ? run.stockCode : run.name,
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${run.stockCode}  $strategyName  ${quantDateText(run.startDate)} - ${quantDateText(run.endDate)}',
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              hasReturn ? formatPercent(totalReturn) : '--',
              style: TextStyle(
                color: hasReturn
                    ? quantProfitColor(totalReturn)
                    : secondaryTextColor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onRename,
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: '编辑历史名称',
              color: secondaryTextColor(context),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '删除历史回测',
              color: secondaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'completed' => const Color(0xFF12B886),
    'failed' => const Color(0xFFFF3B45),
    'running' => const Color(0xFF38BDF8),
    _ => const Color(0xFFE6B450),
  };
}

String _statusText(String status) {
  return switch (status) {
    'completed' => '完成',
    'failed' => '失败',
    'running' => '运行',
    _ => '创建',
  };
}

String _strategyName(List<StrategyDefinition> strategies, String code) {
  for (final strategy in strategies) {
    if (strategy.code == code) return strategy.name;
  }
  return code;
}
