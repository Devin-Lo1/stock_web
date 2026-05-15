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
import '../utils/stock_suggestion_search.dart';
import '../widgets/common/page_title.dart';
import '../widgets/quant/quant_panels.dart';

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
        QuantStrategyPanel(
          strategies: _strategies,
          selectedStrategy: _selectedStrategy,
          isLoading: _isLoadingStrategies,
          onChanged: (strategy) => setState(() => _selectedStrategy = strategy),
          onReload: _loadStrategies,
        ),
        const SizedBox(height: 12),
        QuantConfigPanel(
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
        if (_error != null) QuantErrorPanel(error: _error!),
        if (_result != null)
          QuantResultPanel(result: _result!, candles: _resultCandles),
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

double _readDouble(String value, double fallback) {
  return double.tryParse(value.trim()) ?? fallback;
}

int _readInt(String value, int fallback) {
  return int.tryParse(value.trim()) ?? fallback;
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
