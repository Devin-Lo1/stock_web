import 'dart:async';

import 'package:flutter/material.dart';

import '../data/sample_positions.dart';
import '../models/app_enums.dart';
import '../models/backend_connection_state.dart';
import '../models/candle.dart';
import '../models/capital_flow.dart';
import '../models/notification_models.dart';
import '../models/position_snapshot.dart';
import '../models/position_trade.dart';
import '../models/strategy_settings.dart';
import '../models/stock_position.dart';
import '../models/strategy_monitor.dart';
import '../models/trade_signal.dart';
import '../repositories/backtest_repository.dart';
import '../repositories/fund_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/position_repository.dart';
import '../repositories/signal_repository.dart';
import '../repositories/strategy_monitor_repository.dart';
import '../services/api_client.dart';
import '../services/backtest_api_service.dart';
import '../services/fund_api_service.dart';
import '../services/local_signal_service.dart';
import '../services/notification_api_service.dart';
import '../services/notification_service.dart';
import '../services/position_api_service.dart';
import '../services/position_storage_service.dart';
import '../services/push_token_service.dart';
import '../services/quote_api_service.dart';
import '../services/signal_api_service.dart';
import '../services/strategy_monitor_api_service.dart';
import '../sheets/add_position_sheet.dart';
import '../utils/theme_helpers.dart';
import 'account_screen.dart';
import 'dashboard_screen.dart';
import 'funds_screen.dart';
import 'positions_screen.dart';
import 'quant_screen.dart';
import 'settings_screen.dart';
import 'signals_screen.dart';
import 'strategy_monitor_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.displayMode,
    required this.onDisplayModeChanged,
  });

  final DisplayMode displayMode;
  final ValueChanged<DisplayMode> onDisplayModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  MarketFilter _marketFilter = MarketFilter.hk;
  late final PositionRepository _positionRepository;
  late final QuoteApiService _quoteApiService;
  late final BacktestRepository _backtestRepository;
  late final FundRepository _fundRepository;
  late final NotificationRepository _notificationRepository;
  late final NotificationService _notificationService;
  late final SignalRepository _signalRepository;
  late final StrategyMonitorRepository _strategyMonitorRepository;
  List<StockPosition> _positions = List.of(samplePositions);
  List<TradeSignal> _backendSignals = const [];
  StrategySettings _settings = StrategySettings.defaults;
  final Set<String> _notifiedSignalKeys = <String>{};
  bool _isRefreshing = false;
  bool _isLoadingSignals = false;
  bool _isScanningSignals = false;
  BackendConnectionState _backendState = BackendConnectionState.connecting;
  DateTime? _lastUpdatedAt;
  late final String _apiBaseUrl;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _apiBaseUrl = apiClient.baseUrl;
    _quoteApiService = QuoteApiService(apiClient);
    _backtestRepository = BacktestRepository(BacktestApiService(apiClient));
    _fundRepository = FundRepository(FundApiService(apiClient));
    _signalRepository = SignalRepository(SignalApiService(apiClient));
    _strategyMonitorRepository = StrategyMonitorRepository(
      StrategyMonitorApiService(apiClient),
    );
    _notificationService = NotificationService();
    _notificationRepository = NotificationRepository(
      apiService: NotificationApiService(apiClient),
      tokenService: const PushTokenService(),
    );
    _positionRepository = PositionRepository(
      storageService: PositionStorageService(),
      apiService: PositionApiService(apiClient),
      quoteApiService: _quoteApiService,
    );
    unawaited(_notificationService.initialize());
    _loadStoredPositions();
    unawaited(_loadSignalEvents(showError: false));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _positions
        .where((position) => position.market == _marketFilter)
        .toList();
    final localSignals = buildSignals(visible, _settings);
    final allSignals = _backendSignals.isEmpty ? localSignals : _backendSignals;
    final visibleSignals = allSignals
        .where((signal) => signal.readStatus != 'ignored')
        .toList();
    final pages = [
      DashboardScreen(
        positions: visible,
        signals: visibleSignals,
        selectedMarket: _marketFilter,
        onMarketChanged: (market) => setState(() => _marketFilter = market),
        onAccountTap: _openAccount,
        onAddPosition: _addPosition,
        onEditPosition: _editPosition,
        onDeletePosition: _deletePosition,
        onRefresh: _refreshPositions,
        onLoadCandles: _loadCandles,
        onLoadCapitalFlow: _loadCapitalFlow,
        onLoadPositionTrades: _loadPositionTrades,
        onLoadPositionSnapshots: _loadPositionSnapshots,
        onCreatePositionTrade: _createPositionTrade,
        onDeletePositionTrade: _deletePositionTrade,
        onLoadStrategyMonitors: _loadPositionStrategyMonitors,
        onLoadPositionSignals: _loadPositionSignalHistory,
        onLoadPositionPushRecords: _loadPositionPushRecords,
        onUpdateStrategyMonitor: _updateStrategyMonitor,
        onDeleteStrategyMonitor: _deleteStrategyMonitor,
        onIgnoreSignal: _ignoreSignalEvent,
        onOpenStrategyMonitor: _openStrategyMonitorForPosition,
        isRefreshing: _isRefreshing,
        backendState: _backendState,
        lastUpdatedAt: _lastUpdatedAt,
      ),
      PositionsScreen(
        positions: visible,
        selectedMarket: _marketFilter,
        onMarketChanged: (market) => setState(() => _marketFilter = market),
        onAddPosition: _addPosition,
        onEditPosition: _editPosition,
        onDeletePosition: _deletePosition,
        onOpenFunds: _openFunds,
        onRefresh: _refreshPositions,
        onLoadCandles: _loadCandles,
        onLoadCapitalFlow: _loadCapitalFlow,
        onLoadPositionTrades: _loadPositionTrades,
        onLoadPositionSnapshots: _loadPositionSnapshots,
        onCreatePositionTrade: _createPositionTrade,
        onDeletePositionTrade: _deletePositionTrade,
        onLoadStrategyMonitors: _loadPositionStrategyMonitors,
        onLoadPositionSignals: _loadPositionSignalHistory,
        onLoadPositionPushRecords: _loadPositionPushRecords,
        onUpdateStrategyMonitor: _updateStrategyMonitor,
        onDeleteStrategyMonitor: _deleteStrategyMonitor,
        onIgnoreSignal: _ignoreSignalEvent,
        onOpenStrategyMonitor: _openStrategyMonitorForPosition,
      ),
      QuantScreen(
        positions: visible,
        repository: _backtestRepository,
        onLoadBacktestCandles: _loadBacktestCandles,
      ),
      SignalsScreen(
        signals: allSignals,
        isLoading: _isLoadingSignals,
        isScanning: _isScanningSignals,
        usingBackendSignals: _backendSignals.isNotEmpty,
        positions: _positions,
        onRefresh: _refreshSignalsPage,
        onScan: _scanSignals,
        backtestRepository: _backtestRepository,
        strategyMonitorRepository: _strategyMonitorRepository,
        notificationRepository: _notificationRepository,
        onLoadCategory: _backendSignals.isEmpty ? null : _loadSignalCategory,
        onIgnoreSignal: _ignoreSignalEvent,
        onLoadConfigs: _signalRepository.loadScanConfigs,
        onUpdateConfig: _signalRepository.updateScanConfig,
      ),
      SettingsScreen(
        settings: _settings,
        displayMode: widget.displayMode,
        backendState: _backendState,
        apiBaseUrl: _apiBaseUrl,
        notificationRepository: _notificationRepository,
        notificationService: _notificationService,
        onRefresh: _refreshPositions,
        onSettingsChanged: _updateSettings,
        onDisplayModeChanged: widget.onDisplayModeChanged,
      ),
    ];

    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: isDarkMode(context)
            ? const Color(0xFF0B141D)
            : Colors.white,
        indicatorColor: appAccentContainerColor(context),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: '持仓',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded),
            label: '量化',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: '信号',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AccountScreen(
          displayMode: widget.displayMode,
          onDisplayModeChanged: widget.onDisplayModeChanged,
          onRefresh: _refreshPositions,
        ),
      ),
    );
  }

  void _openFunds() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FundsScreen(repository: _fundRepository),
      ),
    );
  }

  Future<void> _addPosition() async {
    final position = await showModalBottomSheet<StockPosition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => AddPositionSheet(initialMarket: _marketFilter),
    );
    if (position == null) return;
    try {
      final created = await _positionRepository.createPosition(
        position,
        _positions,
      );
      if (!mounted) return;
      setState(() => _positions.insert(0, created));
      unawaited(_notifyCurrentSignals());
    } catch (_) {
      if (!mounted) return;
      setState(() => _positions.insert(0, position));
      await _savePositions();
      unawaited(_notifyCurrentSignals());
    }
  }

  Future<StockPosition?> _editPosition(StockPosition position) async {
    final updated = await showModalBottomSheet<StockPosition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => AddPositionSheet(initialPosition: position),
    );
    if (updated == null) return null;
    try {
      final remoteUpdated = await _positionRepository.updatePosition(
        position,
        updated,
        _positions,
      );
      if (!mounted) return remoteUpdated;
      setState(() => _replacePosition(position, remoteUpdated));
      unawaited(_notifyCurrentSignals());
      return remoteUpdated;
    } catch (_) {
      if (!mounted) return updated;
      setState(() => _replacePosition(position, updated));
      await _savePositions();
      unawaited(_notifyCurrentSignals());
      return updated;
    }
  }

  Future<void> _deletePosition(StockPosition position) async {
    final nextPositions = _positions.where((item) => item != position).toList();
    try {
      await _positionRepository.deletePosition(position, nextPositions);
    } catch (_) {
      await _positionRepository.savePositions(nextPositions);
    }
    if (!mounted) return;
    setState(() => _positions = nextPositions);
  }

  Future<List<PositionTrade>> _loadPositionTrades(StockPosition position) {
    return _positionRepository.loadPositionTrades(position);
  }

  Future<List<PositionSnapshot>> _loadPositionSnapshots(
    StockPosition position,
  ) {
    return _positionRepository.loadPositionSnapshotHistory(position);
  }

  Future<List<StrategyMonitor>> _loadPositionStrategyMonitors(
    StockPosition position,
  ) {
    return _strategyMonitorRepository.loadMonitors(
      code: position.code,
      limit: 50,
    );
  }

  Future<List<TradeSignal>> _loadPositionSignalHistory(StockPosition position) {
    return _signalRepository
        .loadSignals(code: position.code, limit: 80)
        .then(
          (signals) => signals
              .where((signal) => signal.readStatus != 'ignored')
              .take(60)
              .toList(),
        );
  }

  Future<List<PushRecord>> _loadPositionPushRecords(
    StockPosition position,
    List<TradeSignal> signals,
  ) async {
    return _notificationRepository.loadPushRecords(
      code: position.code,
      limit: 20,
    );
  }

  Future<StrategyMonitor> _updateStrategyMonitor(
    StrategyMonitor monitor, {
    bool? enabled,
    bool? pushCandidate,
  }) {
    return _strategyMonitorRepository.updateMonitor(
      monitor.id,
      enabled: enabled,
      pushCandidate: pushCandidate,
    );
  }

  Future<void> _deleteStrategyMonitor(StrategyMonitor monitor) {
    return _strategyMonitorRepository.deleteMonitor(monitor.id);
  }

  Future<void> _openStrategyMonitorForPosition(StockPosition position) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StrategyMonitorScreen(
          positions: _positions,
          backtestRepository: _backtestRepository,
          monitorRepository: _strategyMonitorRepository,
          initialCode: position.code,
        ),
      ),
    );
  }

  Future<StockPosition?> _createPositionTrade(
    StockPosition position,
    PositionTradeDraft draft,
  ) async {
    final result = await _positionRepository.createPositionTrade(
      position,
      draft,
    );
    if (result.positions.isNotEmpty && mounted) {
      setState(() => _positions = result.positions);
    }
    return result.updatedPosition;
  }

  Future<StockPosition?> _deletePositionTrade(
    StockPosition position,
    PositionTrade trade,
  ) async {
    final result = await _positionRepository.deletePositionTrade(
      position,
      trade,
    );
    if (result.positions.isNotEmpty && mounted) {
      setState(() => _positions = result.positions);
    }
    return result.updatedPosition;
  }

  Future<void> _ignoreSignalEvent(TradeSignal signal) async {
    if (signal.id.isEmpty) return;
    await _signalRepository.ignoreSignalEvent(signal.id);
    if (!mounted) return;
    setState(() {
      _backendSignals = _backendSignals
          .map(
            (item) => item.id == signal.id
                ? TradeSignal(
                    id: item.id,
                    code: item.code,
                    type: item.type,
                    stock: item.stock,
                    time: item.time,
                    level: item.level,
                    signalType: item.signalType,
                    tone: item.tone,
                    message: item.message,
                    strategyCode: item.strategyCode,
                    strategyName: item.strategyName,
                    conditionLabel: item.conditionLabel,
                    triggerValue: item.triggerValue,
                    thresholdValue: item.thresholdValue,
                    pushCandidate: item.pushCandidate,
                    sourceCategory: item.sourceCategory,
                    readStatus: 'ignored',
                  )
                : item,
          )
          .toList();
    });
  }

  Future<void> _loadStoredPositions() async {
    final result = await _positionRepository.loadPositions();
    if (!mounted) return;
    _applyLoadResult(
      result,
      notifyOnLocalFallback: false,
      notifyOnSignals: false,
    );
  }

  Future<List<StockPosition>> _refreshPositions() async {
    if (_isRefreshing) return _positions;
    setState(() => _isRefreshing = true);
    try {
      final result = await _positionRepository.loadPositions();
      if (!mounted) return result.positions;
      _applyLoadResult(
        result,
        notifyOnLocalFallback: true,
        notifyOnSignals: true,
      );
      return result.positions;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _refreshSignalsPage() async {
    await _refreshPositions();
    await _loadSignalEvents();
  }

  Future<void> _loadSignalEvents({bool showError = true}) async {
    if (_isLoadingSignals) return;
    setState(() => _isLoadingSignals = true);
    try {
      final signals = await _signalRepository.loadSignals(limit: 80);
      if (!mounted) return;
      setState(() => _backendSignals = signals);
    } catch (error) {
      if (!mounted || !showError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('信号中心加载失败：${_errorMessage(error)}')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingSignals = false);
    }
  }

  Future<void> _scanSignals() async {
    if (_isScanningSignals) return;
    setState(() => _isScanningSignals = true);
    try {
      final result = await _signalRepository.scanSignals(refresh: true);
      if (!mounted) return;
      await _loadSignalEvents(showError: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '扫描完成：新增 ${result.createdCount} 条，扫描 ${result.scannedCount} 个策略条件',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('扫描失败：${_errorMessage(error)}')));
    } finally {
      if (mounted) setState(() => _isScanningSignals = false);
    }
  }

  Future<List<TradeSignal>> _loadSignalCategory(SignalCategory category) {
    return switch (category) {
      SignalCategory.important => _signalRepository.loadSignals(
        limit: 200,
        level: 'important',
      ),
      SignalCategory.strategy => _signalRepository.loadSignals(
        limit: 200,
        sourceCategory: 'strategy',
      ),
      SignalCategory.risk => _signalRepository.loadSignals(
        limit: 200,
        sourceCategory: 'risk',
      ),
      SignalCategory.system => _signalRepository.loadSignals(
        limit: 200,
        sourceCategory: 'system',
      ),
      SignalCategory.ignored => _signalRepository.loadSignals(
        limit: 200,
        readStatus: 'ignored',
      ),
    };
  }

  Future<void> _savePositions() {
    return _positionRepository.savePositions(_positions);
  }

  Future<List<Candle>> _loadCandles(
    String code, {
    String period = 'day',
    int limit = 240,
  }) {
    return _quoteApiService.refreshCandles(code, period: period, limit: limit);
  }

  Future<CapitalFlowSnapshot> _loadCapitalFlow(String code) {
    return _quoteApiService.fetchCapitalFlow(code);
  }

  Future<List<Candle>> _loadBacktestCandles(
    String code, {
    String period = 'day',
    int limit = 1000,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _quoteApiService.fetchCandles(
        code,
        period: period,
        limit: limit,
        includeMock: false,
      );
      if (cached.isNotEmpty) return cached;
    }
    return _quoteApiService.refreshCandles(
      code,
      period: period,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void _replacePosition(StockPosition original, StockPosition updated) {
    final index = _positions.indexOf(original);
    if (index != -1) _positions[index] = updated;
  }

  void _updateSettings(StrategySettings settings) {
    setState(() => _settings = settings);
    unawaited(_notifyCurrentSignals());
  }

  Future<void> _notifyCurrentSignals() async {
    final visible = _positions
        .where((position) => position.market == _marketFilter)
        .toList();
    await _notifyNewSignals(buildSignals(visible, _settings));
  }

  Future<void> _notifyNewSignals(List<TradeSignal> signals) async {
    for (final signal in signals) {
      if (_notifiedSignalKeys.add(signal.notificationKey)) {
        await _notificationService.showTradeSignal(signal);
      }
    }
  }

  void _applyLoadResult(
    PositionLoadResult result, {
    required bool notifyOnLocalFallback,
    required bool notifyOnSignals,
  }) {
    setState(() {
      _positions = result.positions;
      _backendState = result.isRemote
          ? BackendConnectionState.connected
          : BackendConnectionState.offline;
      _lastUpdatedAt = DateTime.now();
    });

    if (notifyOnLocalFallback && !result.isRemote) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('后端连接失败，已保留本地数据')));
    } else if (notifyOnLocalFallback && result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('后端已连接，行情刷新失败：${_errorMessage(result.error)}')),
      );
    }

    if (notifyOnSignals) {
      unawaited(_notifyCurrentSignals());
    }
  }

  String _errorMessage(Object? error) {
    if (error is ApiException) return error.message;
    return '请检查 FutuOpenD 或行情权限';
  }
}
