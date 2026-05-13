import 'package:flutter/material.dart';
import '../models/candle.dart';
import '../models/stock_position.dart';
import '../utils/formatters.dart';
import '../utils/theme_helpers.dart';
import '../widgets/chart/fullscreen_kline_screen.dart';
import '../widgets/chart/position_kline_chart.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/chart/kline_chart_period.dart';
import '../widgets/position/position_detail_metric.dart';
import '../widgets/quote/quote_overview_grid.dart';

class PositionDetailScreen extends StatefulWidget {
  const PositionDetailScreen({
    super.key,
    required this.position,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
    required this.onLoadCandles,
  });

  final StockPosition position;
  final Future<StockPosition?> Function(StockPosition position) onEdit;
  final VoidCallback onDelete;
  final Future<List<StockPosition>> Function() onRefresh;
  final Future<List<Candle>> Function(String code, {String period, int limit})
  onLoadCandles;

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
  late StockPosition _position = widget.position;
  List<Candle> _candles = const [];
  bool _isLoadingCandles = true;
  Object? _candleError;
  KLineChartPeriod _selectedPeriod = KLineChartPeriod.day;

  @override
  void initState() {
    super.initState();
    _loadCandles();
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
    final results = await Future.wait<Object>([
      widget.onRefresh(),
      _loadCandles(silent: true),
    ]);
    if (!mounted) return;
    final positions = results.first as List<StockPosition>;
    final latest = _findLatestPosition(positions, _position);
    if (latest != null) {
      setState(() => _position = latest);
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

  @override
  Widget build(BuildContext context) {
    final dailyColor = _profitColor(_position.dailyProfit);

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
                  child: PositionDetailMetric(
                    label: '当日收益',
                    value: formatHkd(_position.dailyProfit),
                    subValue: formatPercent(_position.dailyProfitRate),
                    color: _profitColor(_position.dailyProfit),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PositionDetailMetric(
                    label: '持有收益',
                    value: _position.pnl,
                    subValue: formatPercent(_position.profitRate),
                    color: _profitColor(_position.profit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PositionDetailMetric(
                    label: '成本价',
                    value: formatHkd(
                      _position.costPrice,
                      showSign: false,
                      decimals: 2,
                    ),
                    subValue:
                        '成本 ${formatHkd(_position.costValue, showSign: false)}',
                    color: primaryTextColor(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PositionDetailMetric(
                    label: '昨收',
                    value: formatHkd(
                      _position.previousClose,
                      showSign: false,
                      decimals: 2,
                    ),
                    subValue: '涨跌 ${_position.change}',
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
          ],
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
