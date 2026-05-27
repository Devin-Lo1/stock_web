import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../models/stock_suggestion.dart';
import '../../models/strategy_definition.dart';
import '../../models/strategy_parameter_config.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';
import 'quant_common_widgets.dart';
import 'quant_stock_suggestion_list.dart';

class QuantBatchPanel extends StatelessWidget {
  const QuantBatchPanel({
    super.key,
    required this.stockCodesController,
    required this.stockSearchController,
    required this.parameterControllers,
    required this.selectedStrategy,
    required this.stockSuggestions,
    required this.isSearchingStocks,
    required this.isRunning,
    required this.result,
    required this.onFillPositions,
    required this.onStockSuggestionSelected,
    required this.onAddStockSearchText,
    required this.onRun,
    required this.onOpenRun,
  });

  final TextEditingController stockCodesController;
  final TextEditingController stockSearchController;
  final Map<String, TextEditingController> parameterControllers;
  final StrategyDefinition? selectedStrategy;
  final List<StockSuggestion> stockSuggestions;
  final bool isSearchingStocks;
  final bool isRunning;
  final BacktestBatchResult? result;
  final VoidCallback onFillPositions;
  final ValueChanged<StockSuggestion> onStockSuggestionSelected;
  final VoidCallback onAddStockSearchText;
  final VoidCallback onRun;
  final ValueChanged<BacktestRun> onOpenRun;

  @override
  Widget build(BuildContext context) {
    final strategy = selectedStrategy;
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuantPanelHeader(
            title: '批量回测',
            icon: Icons.grid_view_rounded,
            trailing: TextButton.icon(
              onPressed: isRunning ? null : onFillPositions,
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: const Text('填入持仓'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '股票可用代码或中文名称搜索加入；参数列表用逗号、空格或分号分隔，最终最多 50 组。',
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: stockSearchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onAddStockSearchText(),
            decoration: InputDecoration(
              labelText: '搜索股票/名称',
              hintText: '比音勒芬、NVDA、01398',
              suffixIcon: IconButton(
                tooltip: '加入股票池',
                onPressed: isRunning ? null : onAddStockSearchText,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ),
          ),
          if (isSearchingStocks || stockSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            QuantStockSuggestionList(
              suggestions: stockSuggestions,
              isSearching: isSearchingStocks,
              onSelected: onStockSuggestionSelected,
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: stockCodesController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '股票池',
              hintText: 'HK.02628, US.NVDA, SZ.002832',
            ),
          ),
          const SizedBox(height: 10),
          if (strategy == null)
            Text(
              '先选择一个策略',
              style: TextStyle(color: secondaryTextColor(context)),
            )
          else if (strategy.code == 'composite_factor')
            _CompositeBatchParameterSection(controllers: parameterControllers)
          else
            _BatchParameterGrid(
              strategyCode: strategy.code,
              controllers: parameterControllers,
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isRunning || strategy == null ? null : onRun,
              icon: isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.stacked_line_chart_rounded),
              label: Text(isRunning ? '批量回测中' : '启动批量回测'),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            _BatchResultSummary(result: result!),
            const SizedBox(height: 8),
            for (final item in _rankedResults(result!))
              _BatchResultTile(item: item, onOpenRun: onOpenRun),
          ],
        ],
      ),
    );
  }
}

class _BatchParameterGrid extends StatelessWidget {
  const _BatchParameterGrid({
    required this.strategyCode,
    required this.controllers,
    this.keyPrefix,
  });

  final String strategyCode;
  final Map<String, TextEditingController> controllers;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final specs = strategyParameterSpecsFor(strategyCode);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = specs.length >= 3 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final spec in specs)
              SizedBox(
                width: spec.valueType == StrategyParameterValueType.multiOption
                    ? constraints.maxWidth
                    : itemWidth,
                child: TextField(
                  controller: controllers[_controllerKey(spec.key)],
                  decoration: InputDecoration(
                    labelText: '${spec.label}列表',
                    hintText: spec.fallback,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _controllerKey(String parameterKey) {
    final prefix = keyPrefix;
    if (prefix == null) return parameterKey;
    return compositeFactorParameterKey(prefix, parameterKey);
  }
}

class _CompositeBatchParameterSection extends StatelessWidget {
  const _CompositeBatchParameterSection({required this.controllers});

  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    final factorController = controllers['factor_codes'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BatchParameterGrid(
          strategyCode: 'composite_factor',
          controllers: controllers,
        ),
        if (factorController != null)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: factorController,
            builder: (context, value, _) {
              final factorCodes = compositeFactorCodesFromText(value.text);
              if (factorCodes.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  for (final factorCode in factorCodes) ...[
                    _CompositeBatchFactorGroup(
                      factorCode: factorCode,
                      controllers: controllers,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _CompositeBatchFactorGroup extends StatelessWidget {
  const _CompositeBatchFactorGroup({
    required this.factorCode,
    required this.controllers,
  });

  final String factorCode;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strategyDisplayNameForCode(factorCode),
          style: TextStyle(
            color: primaryTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        _BatchParameterGrid(
          strategyCode: factorCode,
          keyPrefix: factorCode,
          controllers: controllers,
        ),
      ],
    );
  }
}

class _BatchResultSummary extends StatelessWidget {
  const _BatchResultSummary({required this.result});

  final BacktestBatchResult result;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SummaryChip(text: '共 ${result.totalCount} 组'),
        _SummaryChip(text: '完成 ${result.completedCount}'),
        _SummaryChip(text: '失败 ${result.failedCount}'),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primaryTextColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BatchResultTile extends StatelessWidget {
  const _BatchResultTile({required this.item, required this.onOpenRun});

  final BacktestBatchItemResult item;
  final ValueChanged<BacktestRun> onOpenRun;

  @override
  Widget build(BuildContext context) {
    final run = item.run;
    final request = item.request;
    final totalReturn = (run?.summaryDouble('total_return') ?? 0) * 100;
    final maxDrawdown = (run?.summaryDouble('max_drawdown') ?? 0) * 100;
    final winRate = (run?.summaryDouble('win_rate') ?? 0) * 100;
    final tradeCount = run?.summaryDouble('trade_count') ?? 0;
    final canOpen = run != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: canOpen ? () => onOpenRun(run) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _statusColor(
                  run?.status,
                  item.error,
                ).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.index + 1}',
                style: TextStyle(
                  color: _statusColor(run?.status, item.error),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    run?.stockCode ?? request?.stockCode ?? '--',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.error ??
                        _parameterText(run?.parameters ?? request?.parameters),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 11,
                    ),
                  ),
                  if (run != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '回撤 ${formatPercent(maxDrawdown)} · 胜率 ${formatPercent(winRate)} · ${tradeCount.toStringAsFixed(0)} 笔',
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
            const SizedBox(width: 8),
            Text(
              run == null ? '--' : formatPercent(totalReturn),
              style: TextStyle(
                color: run == null
                    ? secondaryTextColor(context)
                    : quantProfitColor(totalReturn),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

List<BacktestBatchItemResult> _rankedResults(BacktestBatchResult result) {
  final items = [...result.results];
  items.sort((left, right) {
    final leftRun = left.run;
    final rightRun = right.run;
    if (leftRun == null && rightRun != null) return 1;
    if (leftRun != null && rightRun == null) return -1;
    if (leftRun == null || rightRun == null) return left.index - right.index;
    return rightRun
        .summaryDouble('total_return')
        .compareTo(leftRun.summaryDouble('total_return'));
  });
  return items.take(12).toList();
}

Color _statusColor(String? status, String? error) {
  if (error != null) return const Color(0xFFFF3B45);
  return switch (status) {
    'completed' => const Color(0xFF12B886),
    'failed' => const Color(0xFFFF3B45),
    _ => const Color(0xFFE6B450),
  };
}

String _parameterText(Map<String, Object?>? parameters) {
  if (parameters == null || parameters.isEmpty) return '默认参数';
  return parameters.entries
      .where((entry) => entry.value != null)
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' · ');
}
