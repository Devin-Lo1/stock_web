import 'dart:async';

import 'package:flutter/material.dart';

import '../models/backtest_models.dart';
import '../models/candle.dart';
import '../models/stock_suggestion.dart';
import '../models/stock_position.dart';
import '../models/strategy_definition.dart';
import '../repositories/backtest_repository.dart';
import '../services/api_client.dart';
import '../services/stock_search_api_service.dart';
import '../utils/formatters.dart';
import '../utils/stock_suggestion_search.dart';
import '../utils/theme_helpers.dart';
import '../widgets/backtest/backtest_equity_chart.dart';
import '../widgets/backtest/backtest_kline_trade_chart.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_title.dart';

class QuantScreen extends StatefulWidget {
  const QuantScreen({
    super.key,
    required this.positions,
    required this.repository,
    required this.onLoadBacktestCandles,
  });

  final List<StockPosition> positions;
  final BacktestRepository repository;
  final Future<List<Candle>> Function(String code, {String period, int limit})
  onLoadBacktestCandles;

  @override
  State<QuantScreen> createState() => _QuantScreenState();
}

class _QuantScreenState extends State<QuantScreen> {
  final _stockCodeController = TextEditingController(text: 'HK.02628');
  final _initialCashController = TextEditingController(text: '100000');
  final _feeRateController = TextEditingController(text: '0.0003');
  final _slippageRateController = TextEditingController(text: '0.0005');
  final _shortWindowController = TextEditingController(text: '5');
  final _longWindowController = TextEditingController(text: '20');
  late final StockSearchApiService _stockSearchService;
  Timer? _stockSearchDebounce;
  int _stockSearchRequestId = 0;
  DateTime _startDate = DateTime(2025, 1, 1);
  DateTime _endDate = DateTime(2026, 5, 14);
  List<StrategyDefinition> _strategies = const [];
  List<StockSuggestion> _stockSuggestions = const [];
  StrategyDefinition? _selectedStrategy;
  BacktestResult? _result;
  List<Candle> _resultCandles = const [];
  String _selectedStockName = '';
  Object? _error;
  bool _isLoadingStrategies = true;
  bool _isSearchingStocks = false;
  bool _isRunning = false;
  bool _isApplyingStockSuggestion = false;

  @override
  void initState() {
    super.initState();
    _stockSearchService = StockSearchApiService(ApiClient());
    _stockCodeController.addListener(_updateStockSuggestions);
    _loadStrategies();
    _updateStockSuggestions();
  }

  @override
  void dispose() {
    _stockCodeController.removeListener(_updateStockSuggestions);
    _stockSearchDebounce?.cancel();
    _stockCodeController.dispose();
    _initialCashController.dispose();
    _feeRateController.dispose();
    _slippageRateController.dispose();
    _shortWindowController.dispose();
    _longWindowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const PageTitle(title: '量化', subtitle: '策略回测和参数验证'),
        const SizedBox(height: 12),
        _StrategyPanel(
          strategies: _strategies,
          selectedStrategy: _selectedStrategy,
          isLoading: _isLoadingStrategies,
          onChanged: (strategy) => setState(() => _selectedStrategy = strategy),
          onReload: _loadStrategies,
        ),
        const SizedBox(height: 12),
        _ConfigPanel(
          stockCodeController: _stockCodeController,
          initialCashController: _initialCashController,
          feeRateController: _feeRateController,
          slippageRateController: _slippageRateController,
          shortWindowController: _shortWindowController,
          longWindowController: _longWindowController,
          selectedStockName: _selectedStockName,
          stockSuggestions: _stockSuggestions,
          isSearchingStocks: _isSearchingStocks,
          startDate: _startDate,
          endDate: _endDate,
          onStartDateChanged: (value) => setState(() => _startDate = value),
          onEndDateChanged: (value) => setState(() => _endDate = value),
          onSuggestionSelected: _applyStockSuggestion,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isRunning || _selectedStrategy == null ? null : _run,
          icon: _isRunning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(_isRunning ? '回测中' : '启动回测'),
        ),
        const SizedBox(height: 12),
        if (_error != null) _ErrorPanel(error: _error!),
        if (_result != null)
          _ResultPanel(result: _result!, candles: _resultCandles),
      ],
    );
  }

  Future<void> _loadStrategies() async {
    setState(() {
      _isLoadingStrategies = true;
      _error = null;
    });
    try {
      final strategies = await widget.repository.loadStrategies();
      if (!mounted) return;
      setState(() {
        _strategies = strategies;
        _selectedStrategy = strategies.isEmpty ? null : strategies.first;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoadingStrategies = false);
    }
  }

  Future<void> _run() async {
    final strategy = _selectedStrategy;
    if (strategy == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
    });
    try {
      final result = await widget.repository.runBacktest(
        BacktestRequest(
          strategyCode: strategy.code,
          stockCode: _stockCodeController.text.trim().toUpperCase(),
          period: 'day',
          startDate: _startDate,
          endDate: _endDate,
          initialCash: _readDouble(_initialCashController.text, 100000),
          feeRate: _readDouble(_feeRateController.text, 0.0003),
          slippageRate: _readDouble(_slippageRateController.text, 0.0005),
          parameters: {
            'short_window': _readInt(_shortWindowController.text, 5),
            'long_window': _readInt(_longWindowController.text, 20),
          },
        ),
      );
      final candles = await widget.onLoadBacktestCandles(
        _stockCodeController.text.trim().toUpperCase(),
        period: 'day',
        limit: 1000,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _resultCandles = _filterCandles(
          candles,
          result.run.startDate,
          result.run.endDate,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _updateStockSuggestions() {
    if (_isApplyingStockSuggestion) return;
    final query = _stockCodeController.text.trim();
    final localSuggestions = searchStockSuggestions(query);
    final exact =
        _findExactSuggestion(query, localSuggestions) ??
        _findPositionSuggestion(query);

    _stockSearchDebounce?.cancel();
    if (exact != null) {
      setState(() {
        _selectedStockName = exact.name;
        _stockSuggestions = const [];
        _isSearchingStocks = false;
      });
      return;
    }

    setState(() {
      _selectedStockName = '';
      _stockSuggestions = localSuggestions;
      _isSearchingStocks = normalizedStockSearchQuery(query).isNotEmpty;
    });

    if (normalizedStockSearchQuery(query).isEmpty) {
      setState(() => _isSearchingStocks = false);
      return;
    }

    _stockSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchRemoteStocks(query),
    );
  }

  Future<void> _searchRemoteStocks(String query) async {
    final requestId = ++_stockSearchRequestId;
    try {
      final results = await _stockSearchService.search(
        normalizedStockSearchQuery(query),
        limit: 8,
        includeDerivatives: shouldIncludeStockDerivatives(query),
      );
      if (!mounted || requestId != _stockSearchRequestId) return;
      final suggestions = results
          .map(
            (result) => StockSuggestion(
              code: result.code,
              name: result.name,
              market: result.market,
              stockType: result.stockType,
              lotSize: result.lotSize,
            ),
          )
          .toList();
      final exact = _findExactSuggestion(query, suggestions);
      setState(() {
        if (exact != null) {
          _selectedStockName = exact.name;
          _stockSuggestions = const [];
        } else {
          _selectedStockName = '';
          _stockSuggestions = suggestions.isEmpty
              ? searchStockSuggestions(query)
              : suggestions.take(5).toList();
        }
        _isSearchingStocks = false;
      });
    } catch (_) {
      if (!mounted || requestId != _stockSearchRequestId) return;
      setState(() => _isSearchingStocks = false);
    }
  }

  void _applyStockSuggestion(StockSuggestion suggestion) {
    _isApplyingStockSuggestion = true;
    _stockCodeController.text = suggestion.code;
    _isApplyingStockSuggestion = false;
    _stockSearchDebounce?.cancel();
    _stockSearchRequestId++;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedStockName = suggestion.name;
      _stockSuggestions = const [];
      _isSearchingStocks = false;
    });
  }

  StockSuggestion? _findExactSuggestion(
    String query,
    List<StockSuggestion> suggestions,
  ) {
    final normalized = query.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final suggestion in suggestions) {
      if (suggestion.code.toUpperCase() == normalized) return suggestion;
    }
    return null;
  }

  StockSuggestion? _findPositionSuggestion(String query) {
    final normalized = query.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final position in widget.positions) {
      if (position.code.toUpperCase() == normalized) {
        return StockSuggestion(
          code: position.code,
          name: position.name,
          market: position.market.name.toUpperCase(),
        );
      }
    }
    return null;
  }
}

class _StrategyPanel extends StatelessWidget {
  const _StrategyPanel({
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
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
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

class _ConfigPanel extends StatelessWidget {
  const _ConfigPanel({
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
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: '参数', icon: Icons.tune_rounded),
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
                child: _DateButton(
                  label: '开始日期',
                  value: startDate,
                  onChanged: onStartDateChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateButton(
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
                child: _NumberField(
                  controller: initialCashController,
                  label: '初始资金',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
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
                child: _NumberField(
                  controller: slippageRateController,
                  label: '滑点率',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  controller: shortWindowController,
                  label: '短均线',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
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

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result, required this.candles});

  final BacktestResult result;
  final List<Candle> candles;

  @override
  Widget build(BuildContext context) {
    final run = result.run;
    final totalReturn = run.summaryDouble('total_return') * 100;
    final maxDrawdown = run.summaryDouble('max_drawdown') * 100;
    final finalEquity = run.summaryDouble('final_equity');

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: '结果', icon: Icons.analytics_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: '总收益',
                  value: formatPercent(totalReturn),
                  color: _profitColor(totalReturn),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
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
                child: _Metric(
                  label: '期末权益',
                  value: formatHkd(finalEquity, showSign: false),
                  color: primaryTextColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
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
              '${_dateText(trade.time)}  ${trade.quantity.toStringAsFixed(2)}股',
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.icon, this.trailing});

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2035),
        );
        if (picked != null) onChanged(picked);
      },
      icon: const Icon(Icons.event_rounded, size: 18),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(_dateText(value), style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: secondaryTextColor(context))),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : error.toString();
    return _Panel(
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

double _readDouble(String value, double fallback) {
  return double.tryParse(value.trim()) ?? fallback;
}

int _readInt(String value, int fallback) {
  return int.tryParse(value.trim()) ?? fallback;
}

String _dateText(DateTime? value) {
  if (value == null) return '--';
  return '${value.year.toString().padLeft(4, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF3B45);
}

List<Candle> _filterCandles(
  List<Candle> candles,
  DateTime? startDate,
  DateTime? endDate,
) {
  if (startDate == null || endDate == null) return candles;
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
  return candles.where((candle) {
    final time = candle.time;
    if (time == null) return false;
    return !time.isBefore(start) && !time.isAfter(end);
  }).toList();
}
