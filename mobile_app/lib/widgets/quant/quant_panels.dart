import 'package:flutter/material.dart';

import '../../models/backtest_models.dart';
import '../../models/candle.dart';
import '../../models/stock_suggestion.dart';
import '../../models/strategy_definition.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_helpers.dart';
import '../backtest/backtest_equity_chart.dart';
import '../backtest/backtest_kline_trade_chart.dart';
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
            _QuantStockSuggestionList(
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

class QuantResultPanel extends StatelessWidget {
  const QuantResultPanel({
    super.key,
    required this.result,
    required this.candles,
  });

  final BacktestResult result;
  final List<Candle> candles;

  @override
  Widget build(BuildContext context) {
    final run = result.run;
    final totalReturn = run.summaryDouble('total_return') * 100;
    final maxDrawdown = run.summaryDouble('max_drawdown') * 100;
    final finalEquity = run.summaryDouble('final_equity');

    return QuantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuantPanelHeader(title: '结果', icon: Icons.analytics_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: QuantMetric(
                  label: '总收益',
                  value: formatPercent(totalReturn),
                  color: quantProfitColor(totalReturn),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuantMetric(
                  label: '最大回撤',
                  value: formatPercent(maxDrawdown),
                  color: const Color(0xFFFF3B45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: QuantMetric(
                  label: '期末权益',
                  value: formatHkd(finalEquity, showSign: false),
                  color: primaryTextColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuantMetric(
                  label: '交易次数',
                  value: '${result.trades.length}',
                  color: primaryTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '收益曲线',
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: softCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: BacktestEquityChart(points: result.equityCurve),
          ),
          const SizedBox(height: 14),
          Text(
            '买卖点',
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: softCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: BacktestKlineTradeChart(
              candles: candles,
              trades: result.trades,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '交易记录',
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (result.trades.isEmpty)
            Text('暂无交易', style: TextStyle(color: secondaryTextColor(context)))
          else
            ...result.trades.take(8).map((trade) => _TradeRow(trade: trade)),
        ],
      ),
    );
  }
}

class QuantErrorPanel extends StatelessWidget {
  const QuantErrorPanel({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : error.toString();
    return QuantPanel(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3B45)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: primaryTextColor(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantStockSuggestionList extends StatelessWidget {
  const _QuantStockSuggestionList({
    required this.suggestions,
    required this.isSearching,
    required this.onSelected,
  });

  final List<StockSuggestion> suggestions;
  final bool isSearching;
  final ValueChanged<StockSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSearching) const LinearProgressIndicator(minHeight: 2),
          for (final suggestion in suggestions.take(5))
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              onTap: () => onSelected(suggestion),
              leading: _QuantMarketBadge(market: suggestion.market),
              title: Text(
                suggestion.name,
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                suggestion.subtitle,
                style: TextStyle(color: secondaryTextColor(context)),
              ),
              trailing: const Icon(Icons.check_circle_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _QuantMarketBadge extends StatelessWidget {
  const _QuantMarketBadge({required this.market});

  final String market;

  @override
  Widget build(BuildContext context) {
    final text = market.isEmpty ? '--' : market;
    return Container(
      width: 42,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.trade});

  final BacktestTrade trade;

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.side == 'buy';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: (isBuy ? const Color(0xFF12B886) : const Color(0xFFFF3B45))
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isBuy ? '买入' : '卖出',
              style: TextStyle(
                color: isBuy
                    ? const Color(0xFF12B886)
                    : const Color(0xFFFF3B45),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${quantDateText(trade.time)}  ${trade.quantity.toStringAsFixed(2)}股',
              style: TextStyle(color: primaryTextColor(context)),
            ),
          ),
          Text(
            trade.price.toStringAsFixed(2),
            style: TextStyle(
              color: primaryTextColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
