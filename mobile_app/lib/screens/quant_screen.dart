import 'dart:async';

import 'package:flutter/material.dart';

import '../models/backtest_models.dart';
import '../models/candle.dart';
import '../models/stock_suggestion.dart';
import '../models/stock_position.dart';
import '../models/strategy_definition.dart';
import '../models/strategy_parameter_config.dart';
import '../repositories/backtest_repository.dart';
import '../services/api_client.dart';
import '../services/stock_search_api_service.dart';
import '../utils/stock_suggestion_search.dart';
import '../widgets/common/page_title.dart';
import '../widgets/quant/quant_panels.dart';
import 'backtest_result_screen.dart';

class QuantScreen extends StatefulWidget {
  const QuantScreen({
    super.key,
    required this.positions,
    required this.repository,
    required this.onLoadBacktestCandles,
  });

  final List<StockPosition> positions;
  final BacktestRepository repository;
  final Future<List<Candle>> Function(
    String code, {
    String period,
    int limit,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh,
  })
  onLoadBacktestCandles;

  @override
  State<QuantScreen> createState() => _QuantScreenState();
}

class _QuantScreenState extends State<QuantScreen> {
  final _scrollController = ScrollController();
  final _stockCodeController = TextEditingController(text: 'HK.02628');
  final _batchStockCodesController = TextEditingController();
  final _batchStockSearchController = TextEditingController();
  final _initialCashController = TextEditingController(text: '100000');
  final _feeRateController = TextEditingController(text: '0.0003');
  final _slippageRateController = TextEditingController(text: '0.0005');
  late final Map<String, TextEditingController> _strategyParameterControllers;
  late final Map<String, TextEditingController> _batchParameterControllers;
  final _historyStockCodeController = TextEditingController();
  late final StockSearchApiService _stockSearchService;
  Timer? _stockSearchDebounce;
  Timer? _batchStockSearchDebounce;
  int _stockSearchRequestId = 0;
  int _batchStockSearchRequestId = 0;
  DateTime _startDate = DateTime(2025, 1, 1);
  DateTime _endDate = _todayDate();
  List<StrategyDefinition> _strategies = const [];
  List<StockSuggestion> _stockSuggestions = const [];
  List<StockSuggestion> _batchStockSuggestions = const [];
  List<BacktestRun> _recentRuns = const [];
  StrategyDefinition? _selectedStrategy;
  String? _historyStrategyFilter;
  String? _historyStatusFilter;
  BacktestBatchResult? _batchResult;
  String _selectedStockName = '';
  Object? _error;
  bool _isLoadingStrategies = true;
  bool _isLoadingHistory = true;
  bool _isSearchingStocks = false;
  bool _isSearchingBatchStocks = false;
  bool _isRunning = false;
  bool _isBatchRunning = false;
  bool _isApplyingStockSuggestion = false;
  bool _isApplyingBatchStockSuggestion = false;

  @override
  void initState() {
    super.initState();
    _strategyParameterControllers = {
      for (final key in allStrategyParameterKeys())
        key: TextEditingController(),
    };
    _batchParameterControllers = {
      for (final key in allStrategyParameterKeys())
        key: TextEditingController(),
    };
    _batchStockCodesController.text = _defaultBatchStockCodes();
    _stockSearchService = StockSearchApiService(ApiClient());
    _stockCodeController.addListener(_updateStockSuggestions);
    _batchStockSearchController.addListener(_updateBatchStockSuggestions);
    _loadStrategies();
    _loadHistory();
    _updateStockSuggestions();
  }

  @override
  void didUpdateWidget(covariant QuantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_batchStockCodesController.text.trim().isEmpty &&
        oldWidget.positions.length != widget.positions.length) {
      _batchStockCodesController.text = _defaultBatchStockCodes();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _stockCodeController.removeListener(_updateStockSuggestions);
    _batchStockSearchController.removeListener(_updateBatchStockSuggestions);
    _stockSearchDebounce?.cancel();
    _batchStockSearchDebounce?.cancel();
    _stockCodeController.dispose();
    _batchStockCodesController.dispose();
    _batchStockSearchController.dispose();
    _initialCashController.dispose();
    _feeRateController.dispose();
    _slippageRateController.dispose();
    for (final controller in _strategyParameterControllers.values) {
      controller.dispose();
    }
    for (final controller in _batchParameterControllers.values) {
      controller.dispose();
    }
    _historyStockCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const PageTitle(title: '量化', subtitle: '策略回测和参数验证'),
        const SizedBox(height: 12),
        QuantStrategyPanel(
          strategies: _strategies,
          selectedStrategy: _selectedStrategy,
          isLoading: _isLoadingStrategies,
          onChanged: _selectStrategy,
          onReload: _loadStrategies,
        ),
        const SizedBox(height: 12),
        QuantHistoryPanel(
          runs: _recentRuns,
          strategies: _strategies,
          stockCodeController: _historyStockCodeController,
          strategyFilter: _historyStrategyFilter,
          statusFilter: _historyStatusFilter,
          isLoading: _isLoadingHistory,
          onReload: _loadHistory,
          onApplyFilters: _loadHistory,
          onClearFilters: _clearHistoryFilters,
          onStrategyFilterChanged: _setHistoryStrategyFilter,
          onStatusFilterChanged: _setHistoryStatusFilter,
          onSelected: _loadHistoryResult,
          onDelete: _confirmDeleteHistory,
          onRename: _confirmRenameHistory,
          onDeleteAll: _confirmDeleteAllHistory,
        ),
        const SizedBox(height: 12),
        QuantConfigPanel(
          stockCodeController: _stockCodeController,
          initialCashController: _initialCashController,
          feeRateController: _feeRateController,
          slippageRateController: _slippageRateController,
          strategyParameterControllers: _strategyParameterControllers,
          selectedStrategy: _selectedStrategy,
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
        QuantBatchPanel(
          stockCodesController: _batchStockCodesController,
          stockSearchController: _batchStockSearchController,
          parameterControllers: _batchParameterControllers,
          selectedStrategy: _selectedStrategy,
          stockSuggestions: _batchStockSuggestions,
          isSearchingStocks: _isSearchingBatchStocks,
          isRunning: _isBatchRunning,
          result: _batchResult,
          onFillPositions: _fillBatchStocksFromPositions,
          onStockSuggestionSelected: _applyBatchStockSuggestion,
          onAddStockSearchText: _addBatchStockSearchText,
          onRun: _runBatch,
          onOpenRun: _loadHistoryResult,
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
      final selected = strategies.isEmpty ? null : strategies.first;
      _applyStrategyDefaults(selected);
      _applyBatchDefaults(selected);
      setState(() {
        _strategies = strategies;
        _selectedStrategy = selected;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoadingStrategies = false);
    }
  }

  void _selectStrategy(StrategyDefinition? strategy) {
    _applyStrategyDefaults(strategy);
    _applyBatchDefaults(strategy);
    setState(() => _selectedStrategy = strategy);
  }

  void _applyStrategyDefaults(StrategyDefinition? strategy) {
    if (strategy == null) return;
    for (final spec in strategyParameterSpecsFor(strategy.code)) {
      _strategyParameterControllers[spec.key]?.text =
          strategyParameterDefaultText(strategy, spec);
    }
    if (strategy.code == 'composite_factor') {
      for (final factorCode in compositeFactorCodes) {
        for (final spec in strategyParameterSpecsFor(factorCode)) {
          _strategyParameterControllers[compositeFactorParameterKey(
                factorCode,
                spec.key,
              )]
              ?.text = compositeFactorParameterDefaultText(
            strategy,
            factorCode,
            spec,
          );
        }
      }
    }
  }

  void _applyBatchDefaults(StrategyDefinition? strategy) {
    if (strategy == null) return;
    for (final spec in strategyParameterSpecsFor(strategy.code)) {
      final base = strategyParameterDefaultText(strategy, spec);
      _batchParameterControllers[spec.key]?.text = _batchDefaultText(
        strategy.code,
        spec,
        base,
      );
    }
    if (strategy.code == 'composite_factor') {
      for (final factorCode in compositeFactorCodes) {
        for (final spec in strategyParameterSpecsFor(factorCode)) {
          final base = compositeFactorParameterDefaultText(
            strategy,
            factorCode,
            spec,
          );
          _batchParameterControllers[compositeFactorParameterKey(
                factorCode,
                spec.key,
              )]
              ?.text = _batchDefaultText(
            factorCode,
            spec,
            base,
          );
        }
      }
    }
  }

  Future<void> _loadHistory({bool showError = true}) async {
    setState(() {
      _isLoadingHistory = true;
      if (showError) _error = null;
    });
    try {
      final runs = await widget.repository.loadBacktestRuns(
        stockCode: _historyStockCodeController.text,
        strategyCode: _historyStrategyFilter,
        status: _historyStatusFilter,
        limit: 30,
      );
      if (!mounted) return;
      setState(() => _recentRuns = runs);
    } catch (error) {
      if (!mounted) return;
      if (showError) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _setHistoryStrategyFilter(String? value) {
    setState(() => _historyStrategyFilter = value);
    _loadHistory();
  }

  void _setHistoryStatusFilter(String? value) {
    setState(() => _historyStatusFilter = value);
    _loadHistory();
  }

  void _clearHistoryFilters() {
    _historyStockCodeController.clear();
    setState(() {
      _historyStrategyFilter = null;
      _historyStatusFilter = null;
    });
    _loadHistory();
  }

  Future<void> _loadHistoryResult(BacktestRun run) async {
    setState(() {
      _isRunning = true;
      _error = null;
    });
    try {
      final result = await widget.repository.loadBacktestResult(run.id);
      final failedMessage = _backtestFailureMessage(result);
      if (failedMessage != null) {
        if (!mounted) return;
        setState(() {
          _error = null;
          _stockCodeController.text = result.run.stockCode;
          _startDate = result.run.startDate ?? _startDate;
          _endDate = result.run.endDate ?? _endDate;
        });
        _openBacktestResultPage(result, const [], isHistoricalResult: true);
        return;
      }
      final candles = await widget.onLoadBacktestCandles(
        result.run.stockCode,
        period: result.run.period.isEmpty ? 'day' : result.run.period,
        limit: 1000,
      );
      if (!mounted) return;
      final resultCandles = _filterCandles(
        candles,
        result.run.startDate,
        result.run.endDate,
      );
      setState(() {
        _stockCodeController.text = result.run.stockCode;
        _startDate = result.run.startDate ?? _startDate;
        _endDate = result.run.endDate ?? _endDate;
      });
      _openBacktestResultPage(result, resultCandles, isHistoricalResult: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _confirmDeleteHistory(BacktestRun run) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除历史回测'),
          content: Text('确定删除 ${run.stockCode} 的这次回测记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _deleteHistory(run);
  }

  Future<void> _deleteHistory(BacktestRun run) async {
    setState(() {
      _isLoadingHistory = true;
      _error = null;
    });
    try {
      await widget.repository.deleteBacktestRun(run.id);
      if (!mounted) return;
      setState(() {
        _recentRuns = _recentRuns
            .where((candidate) => candidate.id != run.id)
            .toList();
      });
      await _loadHistory(showError: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _confirmRenameHistory(BacktestRun run) async {
    final controller = TextEditingController(text: run.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑历史名称'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (name == null) return;
    await _renameHistory(run, name);
  }

  Future<void> _renameHistory(BacktestRun run, String name) async {
    setState(() {
      _isLoadingHistory = true;
      _error = null;
    });
    try {
      final renamed = await widget.repository.renameBacktestRun(run.id, name);
      if (!mounted) return;
      setState(() {
        _recentRuns = [
          for (final candidate in _recentRuns)
            candidate.id == renamed.id ? renamed : candidate,
        ];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _confirmDeleteAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除全部历史回测'),
          content: const Text('确定删除全部历史回测记录吗？该操作会同时删除收益曲线和交易记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('全部删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _deleteAllHistory();
  }

  Future<void> _deleteAllHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _error = null;
    });
    try {
      await widget.repository.deleteAllBacktestRuns();
      if (!mounted) return;
      setState(() => _recentRuns = const []);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _runBatch() async {
    final strategy = _selectedStrategy;
    if (strategy == null) return;
    final requestsOrError = _buildBatchRequests(strategy);
    if (requestsOrError is _QuantValidationError) {
      setState(() {
        _error = requestsOrError;
        _batchResult = null;
      });
      return;
    }
    final requests = requestsOrError as List<BacktestRequest>;
    setState(() {
      _isBatchRunning = true;
      _error = null;
      _batchResult = null;
    });
    try {
      final result = await widget.repository.runBacktestBatch(
        BacktestBatchRequest(items: requests),
      );
      if (!mounted) return;
      setState(() => _batchResult = result);
      await _loadHistory(showError: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isBatchRunning = false);
    }
  }

  Future<void> _run() async {
    final strategy = _selectedStrategy;
    if (strategy == null) return;
    final requestOrError = _buildRequest(strategy);
    if (requestOrError is _QuantValidationError) {
      setState(() => _error = requestOrError);
      return;
    }
    final request = requestOrError as BacktestRequest;

    setState(() {
      _isRunning = true;
      _error = null;
    });
    try {
      await widget.onLoadBacktestCandles(
        request.stockCode,
        period: request.period,
        limit: 1000,
        startDate: request.startDate,
        endDate: request.endDate,
        forceRefresh: true,
      );
      final result = await widget.repository.runBacktest(request);
      final failedMessage = _backtestFailureMessage(result);
      if (failedMessage != null) {
        if (!mounted) return;
        setState(() => _error = _QuantValidationError(failedMessage));
        return;
      }
      final candles = await widget.onLoadBacktestCandles(
        request.stockCode,
        period: request.period,
        limit: 1000,
      );
      if (!mounted) return;
      final resultCandles = _filterCandles(
        candles,
        result.run.startDate,
        result.run.endDate,
      );
      await _loadHistory(showError: false);
      _openBacktestResultPage(result, resultCandles, isHistoricalResult: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _openBacktestResultPage(
    BacktestResult result,
    List<Candle> candles, {
    required bool isHistoricalResult,
  }) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BacktestResultScreen(
          result: result,
          candles: candles,
          isHistoricalResult: isHistoricalResult,
        ),
      ),
    );
  }

  Object _buildRequest(StrategyDefinition strategy) {
    final stockCode = _stockCodeController.text.trim().toUpperCase();
    if (stockCode.isEmpty) {
      return const _QuantValidationError('请输入股票代码');
    }
    if (!stockCode.contains('.') || stockCode.length < 4) {
      return const _QuantValidationError('股票代码格式不正确，例如 HK.02628');
    }
    if (_startDate.isAfter(_endDate)) {
      return const _QuantValidationError('开始日期不能晚于结束日期');
    }

    final initialCash = _parsePositiveDouble(
      _initialCashController.text,
      '初始资金',
    );
    if (initialCash is _QuantValidationError) return initialCash;
    final feeRate = _parseNonNegativeDouble(_feeRateController.text, '手续费率');
    if (feeRate is _QuantValidationError) return feeRate;
    final slippageRate = _parseNonNegativeDouble(
      _slippageRateController.text,
      '滑点率',
    );
    if (slippageRate is _QuantValidationError) return slippageRate;
    final parametersOrError = _buildStrategyParameters(strategy);
    if (parametersOrError is _QuantValidationError) return parametersOrError;

    return BacktestRequest(
      strategyCode: strategy.code,
      stockCode: stockCode,
      period: 'day',
      startDate: _startDate,
      endDate: _endDate,
      initialCash: initialCash as double,
      feeRate: feeRate as double,
      slippageRate: slippageRate as double,
      parameters: parametersOrError as Map<String, Object?>,
    );
  }

  Object _buildBatchRequests(StrategyDefinition strategy) {
    final stockCodesOrError = _batchStockCodes();
    if (stockCodesOrError is _QuantValidationError) return stockCodesOrError;
    if (_startDate.isAfter(_endDate)) {
      return const _QuantValidationError('开始日期不能晚于结束日期');
    }

    final initialCash = _parsePositiveDouble(
      _initialCashController.text,
      '初始资金',
    );
    if (initialCash is _QuantValidationError) return initialCash;
    final feeRate = _parseNonNegativeDouble(_feeRateController.text, '手续费率');
    if (feeRate is _QuantValidationError) return feeRate;
    final slippageRate = _parseNonNegativeDouble(
      _slippageRateController.text,
      '滑点率',
    );
    if (slippageRate is _QuantValidationError) return slippageRate;

    final parameterVariantsOrError = _buildBatchParameterVariants(strategy);
    if (parameterVariantsOrError is _QuantValidationError) {
      return parameterVariantsOrError;
    }
    final stockCodes = stockCodesOrError as List<String>;
    final parameterVariants =
        parameterVariantsOrError as List<Map<String, Object?>>;
    final totalCount = stockCodes.length * parameterVariants.length;
    if (totalCount > 50) {
      return _QuantValidationError('批量组合最多 50 组，当前 $totalCount 组');
    }

    return [
      for (final stockCode in stockCodes)
        for (final parameters in parameterVariants)
          BacktestRequest(
            strategyCode: strategy.code,
            stockCode: stockCode,
            period: 'day',
            startDate: _startDate,
            endDate: _endDate,
            initialCash: initialCash as double,
            feeRate: feeRate as double,
            slippageRate: slippageRate as double,
            parameters: parameters,
          ),
    ];
  }

  Object _batchStockCodes() {
    final codes = _batchStockCodesController.text
        .split(RegExp(r'[\s,，;；]+'))
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList();
    if (codes.isEmpty) return const _QuantValidationError('请输入批量股票池');
    final uniqueCodes = <String>[];
    final seen = <String>{};
    for (final code in codes) {
      if (!code.contains('.') || code.length < 4) {
        return _QuantValidationError('股票代码格式不正确：$code');
      }
      if (seen.add(code)) uniqueCodes.add(code);
    }
    return uniqueCodes;
  }

  Object _buildBatchParameterVariants(StrategyDefinition strategy) {
    if (strategy.code == 'composite_factor') {
      return _buildCompositeBatchParameterVariants(strategy);
    }

    final specs = strategyParameterSpecsFor(strategy.code);
    var variants = <Map<String, Object?>>[<String, Object?>{}];
    for (final spec in specs) {
      final valuesOrError = _parseBatchParameterValues(spec);
      if (valuesOrError is _QuantValidationError) return valuesOrError;
      final values = valuesOrError as List<Object?>;
      variants = [
        for (final variant in variants)
          for (final value in values) {...variant, spec.key: value},
      ];
      if (variants.length > 50) {
        return const _QuantValidationError('参数组合过多，请缩小参数列表');
      }
    }

    for (final parameters in variants) {
      final relationError = _validateStrategyParameterRelations(
        strategy.code,
        parameters,
      );
      if (relationError != null) return relationError;
    }
    return variants;
  }

  Object _buildCompositeBatchParameterVariants(StrategyDefinition strategy) {
    var topVariants = <Map<String, Object?>>[<String, Object?>{}];
    for (final spec in strategyParameterSpecsFor(strategy.code)) {
      final valuesOrError = _parseBatchParameterValues(spec);
      if (valuesOrError is _QuantValidationError) return valuesOrError;
      final values = valuesOrError as List<Object?>;
      topVariants = [
        for (final variant in topVariants)
          for (final value in values) {...variant, spec.key: value},
      ];
      if (topVariants.length > 50) {
        return const _QuantValidationError('参数组合过多，请缩小参数列表');
      }
    }

    final variants = <Map<String, Object?>>[];
    for (final topParameters in topVariants) {
      final relationError = _validateStrategyParameterRelations(
        strategy.code,
        topParameters,
      );
      if (relationError != null) return relationError;

      final nestedOrError = _buildCompositeBatchFactorParameterVariants(
        topParameters,
      );
      if (nestedOrError is _QuantValidationError) return nestedOrError;
      final nestedVariants =
          nestedOrError as List<Map<String, Map<String, Object?>>>;
      for (final factorParameters in nestedVariants) {
        variants.add({...topParameters, 'factor_parameters': factorParameters});
        if (variants.length > 50) {
          return const _QuantValidationError('参数组合过多，请缩小参数列表');
        }
      }
    }
    return variants;
  }

  Object _buildCompositeBatchFactorParameterVariants(
    Map<String, Object?> parameters,
  ) {
    final rawFactorCodes = parameters['factor_codes'];
    if (rawFactorCodes is! List) {
      return const _QuantValidationError('组合因子至少选择两个');
    }
    final factorCodes = rawFactorCodes.cast<String>();
    var factorVariants = <Map<String, Map<String, Object?>>>[
      <String, Map<String, Object?>>{},
    ];
    for (final factorCode in factorCodes) {
      var parameterVariants = <Map<String, Object?>>[<String, Object?>{}];
      for (final spec in strategyParameterSpecsFor(factorCode)) {
        final valuesOrError = _parseBatchParameterValues(
          spec,
          controllerKey: compositeFactorParameterKey(factorCode, spec.key),
        );
        if (valuesOrError is _QuantValidationError) {
          return _QuantValidationError(
            '${strategyDisplayNameForCode(factorCode)}：${valuesOrError.message}',
          );
        }
        final values = valuesOrError as List<Object?>;
        parameterVariants = [
          for (final variant in parameterVariants)
            for (final value in values) {...variant, spec.key: value},
        ];
        if (parameterVariants.length > 50) {
          return _QuantValidationError(
            '${strategyDisplayNameForCode(factorCode)}：参数组合过多',
          );
        }
      }

      for (final childParameters in parameterVariants) {
        final relationError = _validateStrategyParameterRelations(
          factorCode,
          childParameters,
        );
        if (relationError != null) {
          return _QuantValidationError(
            '${strategyDisplayNameForCode(factorCode)}：${relationError.message}',
          );
        }
      }

      factorVariants = [
        for (final existing in factorVariants)
          for (final childParameters in parameterVariants)
            {...existing, factorCode: childParameters},
      ];
      if (factorVariants.length > 50) {
        return const _QuantValidationError('组合因子参数组合过多，请缩小参数列表');
      }
    }
    return factorVariants;
  }

  Object _parseBatchParameterValues(
    StrategyParameterSpec spec, {
    String? controllerKey,
  }) {
    final text =
        (_batchParameterControllers[controllerKey ?? spec.key]?.text ??
                spec.fallback)
            .trim();
    if (spec.valueType == StrategyParameterValueType.multiOption) {
      final value = _parseMultiOption(text, spec);
      if (value is _QuantValidationError) return value;
      return [value];
    }

    final parts = text
        .split(RegExp(r'[,，;；\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return _QuantValidationError('请输入${spec.label}参数');
    final values = <Object?>[];
    for (final part in parts) {
      final value = switch (spec.valueType) {
        StrategyParameterValueType.positiveInt => _parsePositiveInt(
          part,
          spec.label,
        ),
        StrategyParameterValueType.boundedDouble => _parseBoundedDouble(
          part,
          spec.label,
        ),
        StrategyParameterValueType.option => _parseOption(part, spec),
        StrategyParameterValueType.multiOption => _parseMultiOption(part, spec),
      };
      if (value is _QuantValidationError) return value;
      values.add(value);
    }
    return values;
  }

  Object _buildStrategyParameters(StrategyDefinition strategy) {
    final parameters = <String, Object?>{};
    for (final spec in strategyParameterSpecsFor(strategy.code)) {
      final value = _parseStrategyParameter(spec);
      if (value is _QuantValidationError) return value;
      parameters[spec.key] = value;
    }

    if (strategy.code == 'composite_factor') {
      final nestedOrError = _buildCompositeFactorParameters(parameters);
      if (nestedOrError is _QuantValidationError) return nestedOrError;
      parameters['factor_parameters'] = nestedOrError;
    }

    final relationError = _validateStrategyParameterRelations(
      strategy.code,
      parameters,
    );
    if (relationError != null) return relationError;

    return parameters;
  }

  Object _buildCompositeFactorParameters(Map<String, Object?> parameters) {
    final rawFactorCodes = parameters['factor_codes'];
    if (rawFactorCodes is! List) {
      return const _QuantValidationError('组合因子至少选择两个');
    }
    final factorCodes = rawFactorCodes.cast<String>();
    final factorParameters = <String, Map<String, Object?>>{};
    for (final factorCode in factorCodes) {
      final values = <String, Object?>{};
      for (final spec in strategyParameterSpecsFor(factorCode)) {
        final value = _parseStrategyParameter(
          spec,
          controllerKey: compositeFactorParameterKey(factorCode, spec.key),
        );
        if (value is _QuantValidationError) {
          return _QuantValidationError(
            '${strategyDisplayNameForCode(factorCode)}：${value.message}',
          );
        }
        values[spec.key] = value;
      }
      final relationError = _validateStrategyParameterRelations(
        factorCode,
        values,
      );
      if (relationError != null) {
        return _QuantValidationError(
          '${strategyDisplayNameForCode(factorCode)}：${relationError.message}',
        );
      }
      factorParameters[factorCode] = values;
    }
    return factorParameters;
  }

  Object _parseStrategyParameter(
    StrategyParameterSpec spec, {
    String? controllerKey,
  }) {
    final text =
        _strategyParameterControllers[controllerKey ?? spec.key]?.text ?? '';
    return switch (spec.valueType) {
      StrategyParameterValueType.positiveInt => _parsePositiveInt(
        text,
        spec.label,
      ),
      StrategyParameterValueType.boundedDouble => _parseBoundedDouble(
        text,
        spec.label,
      ),
      StrategyParameterValueType.option => _parseOption(text, spec),
      StrategyParameterValueType.multiOption => _parseMultiOption(text, spec),
    };
  }

  Object _parseOption(String text, StrategyParameterSpec spec) {
    final value = text.trim();
    if (spec.options.any((option) => option.value == value)) return value;
    return _QuantValidationError('请选择${spec.label}');
  }

  Object _parseMultiOption(String text, StrategyParameterSpec spec) {
    final allowed = {for (final option in spec.options) option.value};
    final values = text
        .split(RegExp(r'[,\uff0c;\uff1b\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (values.length >= 2 && values.every(allowed.contains)) return values;
    return _QuantValidationError('${spec.label}至少选择两个');
  }

  _QuantValidationError? _validateStrategyParameterRelations(
    String strategyCode,
    Map<String, Object?> parameters,
  ) {
    if (strategyCode == 'rsi_reversal') {
      final window = parameters['rsi_window'];
      final oversold = parameters['oversold'];
      final overbought = parameters['overbought'];
      if (window is int && window <= 1) {
        return const _QuantValidationError('RSI 周期必须大于 1');
      }
      if (oversold is double &&
          overbought is double &&
          oversold >= overbought) {
        return const _QuantValidationError('超卖线必须小于超买线');
      }
      return null;
    }

    if (strategyCode == 'macd_trend') {
      final fastWindow = parameters['fast_window'];
      final slowWindow = parameters['slow_window'];
      if (fastWindow is int && slowWindow is int && fastWindow >= slowWindow) {
        return const _QuantValidationError('快线周期必须小于慢线周期');
      }
      return null;
    }

    if (strategyCode == 'price_break_ma') {
      final maWindow = parameters['ma_window'];
      final direction = parameters['direction'];
      if (maWindow is int && maWindow <= 1) {
        return const _QuantValidationError('均线周期必须大于 1');
      }
      if (direction is! String ||
          !{'break_down', 'recover_up', 'both'}.contains(direction)) {
        return const _QuantValidationError('请选择有效触发方向');
      }
      return null;
    }

    if (strategyCode == 'volume_breakout') {
      final lookback = parameters['lookback_window'];
      final volumeWindow = parameters['volume_window'];
      final multiplier = parameters['volume_multiplier'];
      if (lookback is int && lookback <= 1) {
        return const _QuantValidationError('突破窗口必须大于 1');
      }
      if (volumeWindow is int && volumeWindow <= 1) {
        return const _QuantValidationError('均量窗口必须大于 1');
      }
      if (multiplier is double && multiplier <= 0) {
        return const _QuantValidationError('放量倍数必须大于 0');
      }
      return null;
    }

    if (strategyCode == 'ma_breakdown_stop') {
      final maWindow = parameters['ma_window'];
      final buffer = parameters['stop_buffer_pct'];
      if (maWindow is int && maWindow <= 1) {
        return const _QuantValidationError('止损均线必须大于 1');
      }
      if (buffer is double && (buffer < 0 || buffer >= 50)) {
        return const _QuantValidationError('缓冲比例需在 0 到 50 之间');
      }
      return null;
    }

    if (strategyCode == 'atr_trailing_stop') {
      final atrWindow = parameters['atr_window'];
      final multiplier = parameters['atr_multiplier'];
      final entryMa = parameters['entry_ma_window'];
      if (atrWindow is int && atrWindow <= 1) {
        return const _QuantValidationError('ATR 周期必须大于 1');
      }
      if (entryMa is int && entryMa <= 1) {
        return const _QuantValidationError('入场均线必须大于 1');
      }
      if (multiplier is double && multiplier <= 0) {
        return const _QuantValidationError('ATR 倍数必须大于 0');
      }
      return null;
    }

    if (strategyCode == 'rsi_oversold_rebound') {
      final window = parameters['rsi_window'];
      final oversold = parameters['oversold'];
      final overbought = parameters['overbought'];
      if (window is int && window <= 1) {
        return const _QuantValidationError('RSI 周期必须大于 1');
      }
      if (oversold is double &&
          overbought is double &&
          oversold >= overbought) {
        return const _QuantValidationError('超卖线必须小于止盈线');
      }
      return null;
    }

    if (strategyCode == 'trend_score') {
      final buyScore = parameters['buy_score'];
      final sellScore = parameters['sell_score'];
      if (buyScore is int &&
          sellScore is int &&
          (sellScore < 0 || sellScore >= buyScore || buyScore > 4)) {
        return const _QuantValidationError('转弱分必须小于转强分，且最高为 4');
      }
      return null;
    }

    if (strategyCode == 'composite_factor') {
      final factorCodes = parameters['factor_codes'];
      final confirmWindow = parameters['confirm_window'];
      if (factorCodes is List && factorCodes.length < 2) {
        return const _QuantValidationError('组合因子至少选择两个');
      }
      if (confirmWindow is int && confirmWindow < 1) {
        return const _QuantValidationError('确认窗口必须大于 0');
      }
      return null;
    }

    if (strategyCode != 'ma_cross') return null;

    final shortWindow = parameters['short_window'];
    final longWindow = parameters['long_window'];
    if (shortWindow is int && longWindow is int && shortWindow >= longWindow) {
      return const _QuantValidationError('短均线必须小于长均线');
    }
    return null;
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

  void _updateBatchStockSuggestions() {
    if (_isApplyingBatchStockSuggestion) return;
    final query = _batchStockSearchController.text.trim();
    final normalizedQuery = normalizedStockSearchQuery(query);
    final localSuggestions = _uniqueStockSuggestions([
      ..._findPositionSuggestions(query),
      ...searchStockSuggestions(query),
    ]);

    _batchStockSearchDebounce?.cancel();
    setState(() {
      _batchStockSuggestions = localSuggestions.take(5).toList();
      _isSearchingBatchStocks = normalizedQuery.isNotEmpty;
    });

    if (normalizedQuery.isEmpty) {
      setState(() => _isSearchingBatchStocks = false);
      return;
    }

    _batchStockSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchRemoteBatchStocks(query),
    );
  }

  Future<void> _searchRemoteBatchStocks(String query) async {
    final requestId = ++_batchStockSearchRequestId;
    try {
      final results = await _stockSearchService.search(
        normalizedStockSearchQuery(query),
        limit: 8,
        includeDerivatives: shouldIncludeStockDerivatives(query),
      );
      if (!mounted || requestId != _batchStockSearchRequestId) return;
      final remoteSuggestions = results
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
      final suggestions = _uniqueStockSuggestions([
        ..._findPositionSuggestions(query),
        ...remoteSuggestions,
        ...searchStockSuggestions(query),
      ]);
      setState(() {
        _batchStockSuggestions = suggestions.take(5).toList();
        _isSearchingBatchStocks = false;
      });
    } catch (_) {
      if (!mounted || requestId != _batchStockSearchRequestId) return;
      setState(() => _isSearchingBatchStocks = false);
    }
  }

  void _applyBatchStockSuggestion(StockSuggestion suggestion) {
    _isApplyingBatchStockSuggestion = true;
    _batchStockSearchController.clear();
    _isApplyingBatchStockSuggestion = false;
    _batchStockSearchDebounce?.cancel();
    _batchStockSearchRequestId++;
    _addBatchStockCode(suggestion.code);
    setState(() {
      _batchStockSuggestions = const [];
      _isSearchingBatchStocks = false;
    });
  }

  void _addBatchStockSearchText() {
    final query = _batchStockSearchController.text.trim();
    if (query.isEmpty) return;
    final suggestion =
        _findExactSuggestion(query, _batchStockSuggestions) ??
        _findPositionSuggestion(query) ??
        (_batchStockSuggestions.isEmpty ? null : _batchStockSuggestions.first);
    if (suggestion != null) {
      _applyBatchStockSuggestion(suggestion);
      return;
    }
    final code = query.toUpperCase();
    if (!code.contains('.') || code.length < 4) {
      setState(() {
        _error = const _QuantValidationError('请先从搜索结果选择股票');
      });
      return;
    }
    _isApplyingBatchStockSuggestion = true;
    _batchStockSearchController.clear();
    _isApplyingBatchStockSuggestion = false;
    _batchStockSearchDebounce?.cancel();
    _batchStockSearchRequestId++;
    _addBatchStockCode(code);
    setState(() {
      _batchStockSuggestions = const [];
      _isSearchingBatchStocks = false;
    });
  }

  void _addBatchStockCode(String code) {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return;
    final currentCodes = _batchStockCodesController.text
        .split(RegExp(r'[\s,\uff0c;\uff1b]+'))
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList();
    final uniqueCodes = <String>[];
    final seen = <String>{};
    for (final currentCode in currentCodes) {
      if (seen.add(currentCode)) uniqueCodes.add(currentCode);
    }
    if (seen.add(normalizedCode)) uniqueCodes.add(normalizedCode);
    _batchStockCodesController.text = uniqueCodes.join(', ');
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

  List<StockSuggestion> _findPositionSuggestions(String query) {
    final raw = query.trim();
    final normalized = raw.toUpperCase();
    if (normalized.isEmpty) return const [];
    final digitQuery = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    final suggestions = <StockSuggestion>[];
    for (final position in widget.positions) {
      final code = position.code.toUpperCase();
      final codeDigits = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (code.contains(normalized) ||
          (digitQuery.isNotEmpty && codeDigits.contains(digitQuery)) ||
          position.name.contains(raw)) {
        suggestions.add(
          StockSuggestion(
            code: position.code,
            name: position.name,
            market: position.market.name.toUpperCase(),
          ),
        );
      }
    }
    return suggestions;
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

  List<StockSuggestion> _uniqueStockSuggestions(
    List<StockSuggestion> suggestions,
  ) {
    final unique = <StockSuggestion>[];
    final seen = <String>{};
    for (final suggestion in suggestions) {
      if (seen.add(suggestion.code.toUpperCase())) unique.add(suggestion);
    }
    return unique;
  }

  void _fillBatchStocksFromPositions() {
    _batchStockCodesController.text = _defaultBatchStockCodes();
  }

  String _defaultBatchStockCodes() {
    final codes = [
      for (final position in widget.positions) position.code.toUpperCase(),
    ];
    if (codes.isEmpty) return _stockCodeController.text.trim().toUpperCase();
    return codes.toSet().join(', ');
  }
}

String _batchDefaultText(
  String strategyCode,
  StrategyParameterSpec spec,
  String base,
) {
  if (strategyCode == 'ma_cross') {
    return switch (spec.key) {
      'short_window' => '3,5,8,10',
      'long_window' => '20,30,60',
      _ => base,
    };
  }
  if (strategyCode == 'rsi_reversal' ||
      strategyCode == 'rsi_oversold_rebound') {
    return switch (spec.key) {
      'rsi_window' => '6,14,21',
      'oversold' => '25,30,35',
      'overbought' => '65,70,75',
      _ => base,
    };
  }
  if (strategyCode == 'macd_trend') {
    return switch (spec.key) {
      'fast_window' => '8,12',
      'slow_window' => '21,26',
      'signal_window' => '9',
      _ => base,
    };
  }
  if (strategyCode == 'trend_score') {
    return switch (spec.key) {
      'ma_window' => '10,20,30',
      'momentum_window' => '10,20',
      'volume_window' => '20',
      _ => base,
    };
  }
  return base;
}

Object _parsePositiveDouble(String value, String label) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null) {
    return _QuantValidationError('$label必须是数字');
  }
  if (parsed <= 0) {
    return _QuantValidationError('$label必须大于 0');
  }
  return parsed;
}

Object _parseNonNegativeDouble(String value, String label) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null) {
    return _QuantValidationError('$label必须是数字');
  }
  if (parsed < 0) {
    return _QuantValidationError('$label不能为负数');
  }
  return parsed;
}

Object _parseBoundedDouble(String value, String label) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null) {
    return _QuantValidationError('$label必须是数字');
  }
  if (parsed <= 0 || parsed >= 100) {
    return _QuantValidationError('$label必须大于 0 且小于 100');
  }
  return parsed;
}

Object _parsePositiveInt(String value, String label) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null) {
    return _QuantValidationError('$label必须是整数');
  }
  if (parsed <= 0) {
    return _QuantValidationError('$label必须大于 0');
  }
  return parsed;
}

String? _backtestFailureMessage(BacktestResult result) {
  if (result.run.status != 'failed') return null;
  final errorMessage = result.run.summary['error_message'];
  if (errorMessage is String && errorMessage.isNotEmpty) return errorMessage;
  final error = result.run.summary['error'];
  return switch (error) {
    'unsupported_strategy' => '暂不支持该策略',
    'invalid_ma_parameters' => '均线参数不合法，短均线必须小于长均线',
    'invalid_rsi_parameters' => 'RSI 参数不合法，周期必须大于 1，且超卖线小于超买线',
    'invalid_macd_parameters' => 'MACD 参数不合法，快线周期必须小于慢线周期',
    'not_enough_candles' => 'K 线数据不足，无法完成回测',
    String value when value.isNotEmpty => value,
    _ => '回测失败，请检查参数和 K 线数据',
  };
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

DateTime _todayDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

class _QuantValidationError implements Exception {
  const _QuantValidationError(this.message);

  final String message;

  @override
  String toString() => message;
}
