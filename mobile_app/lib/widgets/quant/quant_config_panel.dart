import 'package:flutter/material.dart';

import '../../models/stock_suggestion.dart';
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
    required this.shortWindowController,
    required this.longWindowController,
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
  final TextEditingController shortWindowController;
  final TextEditingController longWindowController;
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
              const SizedBox(width: 10),
              Expanded(
                child: QuantNumberField(
                  controller: shortWindowController,
                  label: '短均线',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuantNumberField(
                  controller: longWindowController,
                  label: '长均线',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
