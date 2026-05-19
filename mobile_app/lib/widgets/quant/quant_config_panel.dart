import 'package:flutter/material.dart';

import '../../models/stock_suggestion.dart';
import '../../models/strategy_definition.dart';
import '../../models/strategy_parameter_config.dart';
import '../../utils/theme_helpers.dart';
import 'quant_common_widgets.dart';
import 'quant_stock_suggestion_list.dart';

class QuantConfigPanel extends StatelessWidget {
  const QuantConfigPanel({
    super.key,
    required this.stockCodeController,
    required this.initialCashController,
    required this.feeRateController,
    required this.slippageRateController,
    required this.strategyParameterControllers,
    required this.selectedStrategy,
    required this.selectedStockName,
    required this.stockSuggestions,
    required this.isSearchingStocks,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onSuggestionSelected,
  });

  final TextEditingController stockCodeController;
  final TextEditingController initialCashController;
  final TextEditingController feeRateController;
  final TextEditingController slippageRateController;
  final Map<String, TextEditingController> strategyParameterControllers;
  final StrategyDefinition? selectedStrategy;
  final String selectedStockName;
  final List<StockSuggestion> stockSuggestions;
  final bool isSearchingStocks;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<StockSuggestion> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuantPanelHeader(title: '参数', icon: Icons.tune_rounded),
          const SizedBox(height: 10),
          TextField(
            controller: stockCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: '股票代码'),
          ),
          if (selectedStockName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              selectedStockName,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (isSearchingStocks || stockSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            QuantStockSuggestionList(
              suggestions: stockSuggestions,
              isSearching: isSearchingStocks,
              onSelected: onSuggestionSelected,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: QuantDateButton(
                  label: '开始日期',
                  value: startDate,
                  onChanged: onStartDateChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuantDateButton(
                  label: '结束日期',
                  value: endDate,
                  onChanged: onEndDateChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: QuantNumberField(
                  controller: initialCashController,
                  label: '初始资金',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuantNumberField(
                  controller: feeRateController,
                  label: '手续费率',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: QuantNumberField(
                  controller: slippageRateController,
                  label: '滑点率',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StrategyParameterFields(
            specs: strategyParameterSpecsFor(selectedStrategy?.code ?? ''),
            controllers: strategyParameterControllers,
          ),
        ],
      ),
    );
  }
}

class _StrategyParameterFields extends StatelessWidget {
  const _StrategyParameterFields({
    required this.specs,
    required this.controllers,
  });

  final List<StrategyParameterSpec> specs;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
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
                width: itemWidth,
                child: _StrategyParameterField(
                  spec: spec,
                  controller: controllers[spec.key]!,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StrategyParameterField extends StatelessWidget {
  const _StrategyParameterField({required this.spec, required this.controller});

  final StrategyParameterSpec spec;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    if (spec.valueType != StrategyParameterValueType.option) {
      return QuantNumberField(controller: controller, label: spec.label);
    }

    final selectedValue = _selectedOptionValue();
    return DropdownButtonFormField<String>(
      key: ValueKey(spec.key),
      initialValue: selectedValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: spec.label),
      items: [
        for (final option in spec.options)
          DropdownMenuItem(
            value: option.value,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        if (value != null) controller.text = value;
      },
    );
  }

  String? _selectedOptionValue() {
    final current = controller.text.trim();
    if (spec.options.any((option) => option.value == current)) return current;
    if (spec.options.any((option) => option.value == spec.fallback)) {
      return spec.fallback;
    }
    return spec.options.isEmpty ? null : spec.options.first.value;
  }
}
