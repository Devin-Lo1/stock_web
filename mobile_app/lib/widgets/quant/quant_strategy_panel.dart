import 'package:flutter/material.dart';

import '../../models/strategy_definition.dart';
import '../common/empty_state.dart';
import 'quant_common_widgets.dart';

class QuantStrategyPanel extends StatelessWidget {
  const QuantStrategyPanel({
    super.key,
    required this.strategies,
    required this.selectedStrategy,
    required this.isLoading,
    required this.onChanged,
    required this.onReload,
  });

  final List<StrategyDefinition> strategies;
  final StrategyDefinition? selectedStrategy;
  final bool isLoading;
  final ValueChanged<StrategyDefinition?> onChanged;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuantPanelHeader(
            title: '策略',
            icon: Icons.account_tree_rounded,
            trailing: IconButton(
              onPressed: isLoading ? null : onReload,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '刷新策略',
            ),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const LinearProgressIndicator()
          else if (strategies.isEmpty)
            const ReadOnlyEmptyState(
              icon: Icons.account_tree_outlined,
              title: '暂无策略',
              subtitle: '后端策略列表为空，请先检查策略定义。',
            )
          else
            DropdownButtonFormField<StrategyDefinition>(
              initialValue: selectedStrategy,
              items: strategies
                  .map(
                    (strategy) => DropdownMenuItem(
                      value: strategy,
                      child: Text(strategy.name),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              decoration: const InputDecoration(labelText: '策略'),
            ),
        ],
      ),
    );
  }
}
