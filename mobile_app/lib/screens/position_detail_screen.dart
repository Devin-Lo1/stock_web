import 'package:flutter/material.dart';
import '../models/candle.dart';
import '../models/notification_models.dart';
import '../models/position_snapshot.dart';
import '../models/position_trade.dart';
import '../models/stock_position.dart';
import '../models/strategy_monitor.dart';
import '../models/trade_signal.dart';
import '../sheets/position_trade_sheet.dart';
import '../utils/formatters.dart';
import '../utils/theme_helpers.dart';
import '../widgets/chart/fullscreen_kline_screen.dart';
import '../widgets/chart/position_kline_chart.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/chart/kline_chart_period.dart';
import '../widgets/position/position_detail_activity_panel.dart';
import '../widgets/position/position_profit_curve.dart';
import '../widgets/position/position_detail_metric.dart';
import '../widgets/position/position_trade_history.dart';
import '../widgets/quote/quote_overview_grid.dart';

class PositionDetailScreen extends StatefulWidget {
  const PositionDetailScreen({
    super.key,
    required this.position,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
    required this.onLoadCandles,
    required this.onLoadPositionTrades,
    required this.onLoadPositionSnapshots,
    required this.onCreatePositionTrade,
    required this.onDeletePositionTrade,
    required this.onLoadStrategyMonitors,
    required this.onLoadPositionSignals,
    required this.onLoadPositionPushRecords,
    required this.onUpdateStrategyMonitor,
    required this.onDeleteStrategyMonitor,
    required this.onIgnoreSignal,
    required this.onOpenStrategyMonitor,
  });

  final StockPosition position;
  final Future<StockPosition?> Function(StockPosition position) onEdit;
  final VoidCallback onDelete;
  final Future<List<StockPosition>> Function() onRefresh;
  final Future<List<Candle>> Function(String code, {String period, int limit})
  onLoadCandles;
  final Future<List<PositionTrade>> Function(StockPosition position)
  onLoadPositionTrades;
  final Future<List<PositionSnapshot>> Function(StockPosition position)
  onLoadPositionSnapshots;
  final Future<StockPosition?> Function(
    StockPosition position,
    PositionTradeDraft draft,
  )
  onCreatePositionTrade;
  final Future<StockPosition?> Function(
    StockPosition position,
    PositionTrade trade,
  )
  onDeletePositionTrade;
  final Future<List<StrategyMonitor>> Function(StockPosition position)
  onLoadStrategyMonitors;
  final Future<List<TradeSignal>> Function(StockPosition position)
  onLoadPositionSignals;
  final Future<List<PushRecord>> Function(
    StockPosition position,
    List<TradeSignal> signals,
  )
  onLoadPositionPushRecords;
  final Future<StrategyMonitor> Function(
    StrategyMonitor monitor, {
    bool? enabled,
    bool? pushCandidate,
  })
  onUpdateStrategyMonitor;
  final Future<void> Function(StrategyMonitor monitor) onDeleteStrategyMonitor;
  final Future<void> Function(TradeSignal signal) onIgnoreSignal;
  final Future<void> Function(StockPosition position) onOpenStrategyMonitor;

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
  late StockPosition _position = widget.position;
  List<Candle> _candles = const [];
  List<PositionTrade> _trades = const [];
  List<PositionSnapshot> _snapshots = const [];
  List<StrategyMonitor> _strategyMonitors = const [];
  List<TradeSignal> _positionSignals = const [];
  List<PushRecord> _pushRecords = const [];
  final Set<String> _updatingMonitorIds = <String>{};
  bool _isLoadingCandles = true;
  bool _isLoadingDetail = true;
  bool _isLoadingActivity = true;
  Object? _candleError;
  Object? _detailError;
  Object? _activityError;
  KLineChartPeriod _selectedPeriod = KLineChartPeriod.day;

  @override
  void initState() {
    super.initState();
    _loadCandles();
    _loadDetailData();
    _loadActivityData();
  }

  Future<void> _editPosition() async {
    final updated = await widget.onEdit(_position);
    if (updated != null && mounted) {
      setState(() => _position = updated);
      await Future.wait([
        _loadCandles(silent: true),
        _loadDetailData(silent: true),
        _loadActivityData(silent: true),
      ]);
    }
  }

  void _deletePosition() {
    widget.onDelete();
    Navigator.of(context).pop();
  }

  void _openFullScreenChart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FullScreenKLineScreen(
          position: _position,
          candles: _candles,
          period: _selectedPeriod,
        ),
      ),
    );
  }

  Future<void> _refreshPosition() async {
    final positionsFuture = widget.onRefresh();
    final candlesFuture = _loadCandles(silent: true);
    final detailFuture = _loadDetailData(silent: true);
    final activityFuture = _loadActivityData(silent: true);
    final positions = await positionsFuture;
    await Future.wait([candlesFuture, detailFuture, activityFuture]);
    if (!mounted) return;
    final latest = _findLatestPosition(positions, _position);
    if (latest != null) {
      setState(() => _position = latest);
    }
  }

  Future<void> _loadDetailData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoadingDetail = true;
        _detailError = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        widget.onLoadPositionTrades(_position),
        widget.onLoadPositionSnapshots(_position),
      ]);
      if (!mounted) return;
      setState(() {
        _trades = results[0] as List<PositionTrade>;
        _snapshots = results[1] as List<PositionSnapshot>;
        _isLoadingDetail = false;
        _detailError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDetail = false;
        _detailError = error;
      });
    }
  }

  Future<void> _loadActivityData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoadingActivity = true;
        _activityError = null;
      });
    }
    try {
      final result = await Future.wait<Object>([
        widget.onLoadStrategyMonitors(_position),
        widget.onLoadPositionSignals(_position),
      ]);
      final signals = result[1] as List<TradeSignal>;
      final pushRecords = await widget.onLoadPositionPushRecords(
        _position,
        signals,
      );
      if (!mounted) return;
      setState(() {
        _strategyMonitors = result[0] as List<StrategyMonitor>;
        _positionSignals = signals;
        _pushRecords = pushRecords;
        _isLoadingActivity = false;
        _activityError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingActivity = false;
        _activityError = error;
      });
    }
  }

  Future<List<Candle>> _loadCandles({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoadingCandles = true;
        _candleError = null;
      });
    }
    try {
      final candles = await widget.onLoadCandles(
        _position.code,
        period: _selectedPeriod.apiPeriod,
        limit: _selectedPeriod.limit,
      );
      if (mounted) {
        setState(() {
          _candles = candles;
          _isLoadingCandles = false;
          _candleError = null;
        });
      }
      return candles;
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingCandles = false;
          _candleError = error;
        });
      }
      return const [];
    }
  }

  Future<void> _changeChartPeriod(KLineChartPeriod period) async {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
      _candles = const [];
      _candleError = null;
    });
    await _loadCandles();
  }

  Future<void> _recordTrade(String action) async {
    final draft = await showPositionTradeSheet(
      context: context,
      position: _position,
      action: action,
    );
    if (draft == null || !mounted) return;
    try {
      final updated = await widget.onCreatePositionTrade(_position, draft);
      if (updated != null && mounted) {
        setState(() => _position = updated);
      }
      await _loadDetailData();
      await _loadActivityData(silent: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('交易记录保存失败：$error')));
    }
  }

  Future<void> _deleteTrade(PositionTrade trade) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除交易记录'),
        content: const Text('删除后会重新计算持仓数量、成本和已实现盈亏。确认删除这条记录吗？'),
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
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final updated = await widget.onDeletePositionTrade(_position, trade);
      if (updated != null && mounted) {
        setState(() => _position = updated);
      }
      await Future.wait([
        _loadDetailData(silent: true),
        _loadActivityData(silent: true),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('交易记录已删除，持仓已重算')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('交易记录删除失败：$error')));
    }
  }

  Future<void> _ignoreSignal(TradeSignal signal) async {
    if (signal.id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('忽略历史信号'),
        content: const Text('这条信号会移到“已忽略”，不再出现在当前股票详情页。确认忽略吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('忽略'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.onIgnoreSignal(signal);
      if (!mounted) return;
      setState(() {
        _positionSignals = _positionSignals
            .where((item) => item.id != signal.id)
            .toList();
        _pushRecords = _pushRecords
            .where((item) => item.signalEventId != signal.id)
            .toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('信号已忽略')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('信号忽略失败：$error')));
    }
  }

  Future<void> _updateStrategyMonitor(
    StrategyMonitor monitor, {
    bool? enabled,
    bool? pushCandidate,
  }) async {
    if (_updatingMonitorIds.contains(monitor.id)) return;
    setState(() => _updatingMonitorIds.add(monitor.id));
    try {
      final updated = await widget.onUpdateStrategyMonitor(
        monitor,
        enabled: enabled,
        pushCandidate: pushCandidate,
      );
      if (!mounted) return;
      setState(() => _replaceStrategyMonitor(updated));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('监控保存失败：$error')));
    } finally {
      if (mounted) setState(() => _updatingMonitorIds.remove(monitor.id));
    }
  }

  Future<void> _deleteStrategyMonitor(StrategyMonitor monitor) async {
    if (_updatingMonitorIds.contains(monitor.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除策略监控'),
        content: Text('删除“${monitor.strategyName}”后，这只股票将不再按该策略扫描。确认删除吗？'),
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
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updatingMonitorIds.add(monitor.id));
    try {
      await widget.onDeleteStrategyMonitor(monitor);
      if (!mounted) return;
      setState(() {
        _strategyMonitors = _strategyMonitors
            .where((item) => item.id != monitor.id)
            .toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('策略监控已删除')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('监控删除失败：$error')));
    } finally {
      if (mounted) setState(() => _updatingMonitorIds.remove(monitor.id));
    }
  }

  void _replaceStrategyMonitor(StrategyMonitor updated) {
    final index = _strategyMonitors.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    _strategyMonitors = [
      ..._strategyMonitors.take(index),
      updated,
      ..._strategyMonitors.skip(index + 1),
    ];
  }

  Future<void> _openStrategyMonitor() async {
    await widget.onOpenStrategyMonitor(_position);
    if (!mounted) return;
    await _loadActivityData(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final dailyColor = _profitColor(_position.dailyProfit);
    final hasBackendMetrics = _position.hasBackendMetrics;

    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: pageBackgroundColor(context),
        title: Column(
          children: [
            Text(_position.name, style: const TextStyle(fontSize: 19)),
            Text(
              _position.code,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '删除持仓',
            onPressed: _deletePosition,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: '编辑持仓',
            onPressed: _editPosition,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosition,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          children: [
            Text(
              _position.price,
              style: TextStyle(
                color: dailyColor,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${formatHkd(_position.currentPrice - _position.previousClose)}  ${_position.change}',
              style: TextStyle(
                color: dailyColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            QuoteOverviewGrid(position: _position),
            const SizedBox(height: 14),
            KLineChartTabs(
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: _changeChartPeriod,
            ),
            const SizedBox(height: 8),
            PositionKLineChart(
              position: _position,
              candles: _candles,
              period: _selectedPeriod,
              isLoading: _isLoadingCandles,
              hasError: _candleError != null,
              onRetry: _loadCandles,
              onOpenFullScreen: _openFullScreenChart,
            ),
            const SizedBox(height: 16),
            if (!hasBackendMetrics || _detailError != null) ...[
              _DetailSyncNotice(
                message: _detailError == null
                    ? '后端持仓收益快照未同步'
                    : '详情数据加载失败，请下拉刷新',
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppTag(text: _position.signal),
                AppTag(text: '数量 ${formatNumberInput(_position.quantity)}'),
                AppTag(text: '现价 ${_position.price}'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _recordTrade('add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('加仓'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _position.quantity <= 0
                        ? null
                        : () => _recordTrade('reduce'),
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('减仓'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _position.quantity <= 0
                        ? null
                        : () => _recordTrade('close'),
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('清仓'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PositionDetailMetric(
                    label: '当日收益',
                    value: _formatMoneyOrDash(
                      _position,
                      _position.backendDayProfit,
                    ),
                    subValue: _formatPercentOrDash(
                      _position.backendDayProfitRate,
                    ),
                    color: _profitColor(_position.backendDayProfit ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PositionDetailMetric(
                    label: '持有收益',
                    value: _formatMoneyOrDash(
                      _position,
                      _position.backendHoldingProfit,
                    ),
                    subValue: _formatPercentOrDash(
                      _position.backendHoldingProfitRate,
                    ),
                    color: _profitColor(_position.backendHoldingProfit ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PositionDetailMetric(
                    label: '摊薄成本',
                    value: _formatPrice(_position, _position.costPrice),
                    subValue: hasBackendMetrics
                        ? '市值 ${_formatMoney(_position, _position.backendMarketValue!)}'
                        : '市值 --',
                    color: primaryTextColor(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PositionDetailMetric(
                    label: '仓位占比',
                    value: _formatPercentOrDash(
                      _position.backendPositionWeight,
                    ),
                    subValue: hasBackendMetrics
                        ? '总收益 ${_formatMoneyOrDash(_position, _position.totalProfit)}'
                        : '总收益 --',
                    color: primaryTextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _editPosition,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('修改持仓'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _deletePosition,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('删除'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingDetail)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              PositionProfitCurve(snapshots: _snapshots),
              const SizedBox(height: 12),
              PositionTradeHistory(
                trades: _trades,
                onDeleteTrade: _deleteTrade,
              ),
            ],
            const SizedBox(height: 12),
            PositionDetailActivityPanel(
              monitors: _strategyMonitors,
              signals: _positionSignals,
              pushRecords: _pushRecords,
              isLoading: _isLoadingActivity,
              error: _activityError,
              updatingMonitorIds: _updatingMonitorIds,
              onRetry: () => _loadActivityData(),
              onMonitorEnabledChanged: (monitor, enabled) =>
                  _updateStrategyMonitor(monitor, enabled: enabled),
              onMonitorPushChanged: (monitor, pushCandidate) =>
                  _updateStrategyMonitor(monitor, pushCandidate: pushCandidate),
              onDeleteMonitor: _deleteStrategyMonitor,
              onIgnoreSignal: _ignoreSignal,
              onOpenStrategyMonitor: _openStrategyMonitor,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSyncNotice extends StatelessWidget {
  const _DetailSyncNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: secondaryTextColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

StockPosition? _findLatestPosition(
  List<StockPosition> positions,
  StockPosition current,
) {
  for (final position in positions) {
    if (current.id != null && position.id == current.id) return position;
  }
  for (final position in positions) {
    if (position.code.toUpperCase() == current.code.toUpperCase()) {
      return position;
    }
  }
  return null;
}

Color _profitColor(double value) {
  return value >= 0 ? const Color(0xFF12B886) : const Color(0xFFFF3B45);
}

String _formatMoney(StockPosition position, double value) {
  return '${_currencyPrefix(position.code)}${value.abs().toStringAsFixed(2)}';
}

String _formatMoneyOrDash(StockPosition position, double? value) {
  if (value == null) return '--';
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  return '$sign${_formatMoney(position, value)}';
}

String _formatPrice(StockPosition position, double value) {
  if (value == 0) return '--';
  return '${_currencyPrefix(position.code)}${value.toStringAsFixed(2)}';
}

String _formatPercentOrDash(double? value) {
  if (value == null) return '--';
  return formatPercent(value);
}

String _currencyPrefix(String code) {
  final upper = code.toUpperCase();
  if (upper.startsWith('US.')) return 'US\$';
  if (upper.startsWith('SH.') || upper.startsWith('SZ.')) return 'CN¥';
  return 'HK\$';
}
