import 'package:flutter/material.dart';

import '../data/sample_positions.dart';
import '../models/app_enums.dart';
import '../models/backend_connection_state.dart';
import '../models/candle.dart';
import '../models/strategy_settings.dart';
import '../models/stock_position.dart';
import '../repositories/backtest_repository.dart';
import '../repositories/position_repository.dart';
import '../services/api_client.dart';
import '../services/backtest_api_service.dart';
import '../services/local_signal_service.dart';
import '../services/position_api_service.dart';
import '../services/position_storage_service.dart';
import '../services/quote_api_service.dart';
import '../sheets/add_position_sheet.dart';
import '../utils/theme_helpers.dart';
import 'account_screen.dart';
import 'dashboard_screen.dart';
import 'positions_screen.dart';
import 'quant_screen.dart';
import 'settings_screen.dart';
import 'signals_screen.dart';

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
  List<StockPosition> _positions = List.of(samplePositions);
  StrategySettings _settings = StrategySettings.defaults;
  bool _isRefreshing = false;
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
    _positionRepository = PositionRepository(
      storageService: PositionStorageService(),
      apiService: PositionApiService(apiClient),
      quoteApiService: _quoteApiService,
    );
    _loadStoredPositions();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _positions
        .where((position) => position.market == _marketFilter)
        .toList();
    final signals = buildSignals(visible, _settings);
    final pages = [
      DashboardScreen(
        positions: visible,
        signals: signals,
        selectedMarket: _marketFilter,
        onMarketChanged: (market) => setState(() => _marketFilter = market),
        onAccountTap: _openAccount,
        onAddPosition: _addPosition,
        onEditPosition: _editPosition,
        onDeletePosition: _deletePosition,
        onRefresh: _refreshPositions,
        onLoadCandles: _loadCandles,
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
        onRefresh: _refreshPositions,
        onLoadCandles: _loadCandles,
      ),
      QuantScreen(
        positions: visible,
        repository: _backtestRepository,
        onLoadBacktestCandles: _loadBacktestCandles,
      ),
      SignalsScreen(signals: signals, onRefresh: _refreshPositions),
      SettingsScreen(
        settings: _settings,
        displayMode: widget.displayMode,
        backendState: _backendState,
        apiBaseUrl: _apiBaseUrl,
        onRefresh: _refreshPositions,
        onSettingsChanged: (settings) => setState(() => _settings = settings),
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
            : const Color(0xFFEAF6FF),
        indicatorColor: isDarkMode(context)
            ? const Color(0xFF1C3445)
            : const Color(0xFFD1E9FF),
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _positions.insert(0, position));
      await _savePositions();
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
      return remoteUpdated;
    } catch (_) {
      if (!mounted) return updated;
      setState(() => _replacePosition(position, updated));
      await _savePositions();
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

  Future<void> _loadStoredPositions() async {
    final result = await _positionRepository.loadPositions();
    if (!mounted) return;
    _applyLoadResult(result, notifyOnLocalFallback: false);
  }

  Future<List<StockPosition>> _refreshPositions() async {
    if (_isRefreshing) return _positions;
    setState(() => _isRefreshing = true);
    try {
      final result = await _positionRepository.loadPositions();
      if (!mounted) return result.positions;
      _applyLoadResult(result, notifyOnLocalFallback: true);
      return result.positions;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
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

  Future<List<Candle>> _loadBacktestCandles(
    String code, {
    String period = 'day',
    int limit = 1000,
  }) async {
    final cached = await _quoteApiService.fetchCandles(
      code,
      period: period,
      limit: limit,
      includeMock: false,
    );
    if (cached.isNotEmpty) return cached;
    return _quoteApiService.refreshCandles(code, period: period, limit: limit);
  }

  void _replacePosition(StockPosition original, StockPosition updated) {
    final index = _positions.indexOf(original);
    if (index != -1) _positions[index] = updated;
  }

  void _applyLoadResult(
    PositionLoadResult result, {
    required bool notifyOnLocalFallback,
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
  }

  String _errorMessage(Object? error) {
    if (error is ApiException) return error.message;
    return '请检查 FutuOpenD 或行情权限';
  }
}
