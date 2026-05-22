import 'package:flutter/material.dart';
import '../models/candle.dart';
import '../models/position_snapshot.dart';
import '../models/position_trade.dart';
import '../models/stock_position.dart';
import '../sheets/position_trade_sheet.dart';
import '../utils/formatters.dart';
import '../utils/theme_helpers.dart';
import '../widgets/chart/fullscreen_kline_screen.dart';
import '../widgets/chart/position_kline_chart.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/chart/kline_chart_period.dart';
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

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
  late StockPosition _position = widget.position;
  List<Candle> _candles = const [];
  List<PositionTrade> _trades = const [];
  List<PositionSnapshot> _snapshots = const [];
  bool _isLoadingCandles = true;
  bool _isLoadingDetail = true;
  Object? _candleError;
  Object? _detailError;
  KLineChartPeriod _selectedPeriod = KLineChartPeriod.day;

  @override
  void initState() {
    super.initState();
    _loadCandles();
    _loadDetailData();
  }

  Future<void> _editPosition() async {
    final updated = await widget.onEdit(_position);
    if (updated != null && mounted) {
      setState(() => _position = updated);
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
    final positions = await positionsFuture;
    await Future.wait([candlesFuture, detailFuture]);
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('交易记录保存失败：$error')));
    }
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
              PositionTradeHistory(trades: _trades),
            ],
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
