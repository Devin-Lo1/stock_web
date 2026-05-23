import 'dart:async';

import 'package:flutter/material.dart';

import '../models/fund_models.dart';
import '../repositories/fund_repository.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/empty_state.dart';
import 'fund_detail_screen.dart';

class FundsScreen extends StatefulWidget {
  const FundsScreen({super.key, required this.repository});

  final FundRepository repository;

  @override
  State<FundsScreen> createState() => _FundsScreenState();
}

class _FundsScreenState extends State<FundsScreen> {
  List<FundPositionSummary> _summaries = const [];
  FundAlertSchedulerStatus? _schedulerStatus;
  bool _isLoading = true;
  bool _isRefreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load(refresh: false, showSpinner: true));
    unawaited(_load(refresh: true, showSpinner: false));
  }

  Future<void> _load({bool refresh = true, bool showSpinner = false}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isRefreshing = true);
    }
    try {
      final summariesFuture = widget.repository.loadSummaries(refresh: refresh);
      final schedulerFuture = widget.repository.loadAlertSchedulerStatus();
      final summaries = await summariesFuture;
      final schedulerStatus = await schedulerFuture;
      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _schedulerStatus = schedulerStatus;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _addFund() async {
    final draft = await showModalBottomSheet<_FundCreateDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _FundAddSheet(repository: widget.repository),
    );
    if (draft == null) return;
    try {
      await widget.repository.createPosition(
        fund: draft.fund,
        shares: draft.shares,
        costNav: draft.costNav,
        fee: draft.fee,
      );
      await _load(refresh: true, showSpinner: true);
    } catch (error) {
      if (mounted) _showSnack('添加基金失败：$error');
    }
  }

  Future<void> _trade(FundPositionSummary summary, String action) async {
    final draft = await showModalBottomSheet<FundTradeDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _FundTradeSheet(summary: summary, action: action),
    );
    if (draft == null) return;
    try {
      await widget.repository.createTrade(summary.position.id, draft);
      await _load(refresh: true);
    } catch (error) {
      if (mounted) _showSnack('交易记录失败：$error');
    }
  }

  Future<void> _editAlert(FundPositionSummary summary) async {
    final draft = await showModalBottomSheet<FundAlertSettingsDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _FundAlertSettingsSheet(summary: summary),
    );
    if (draft == null) return;
    try {
      await widget.repository.updateAlertSettings(summary.position.id, draft);
      await _load(refresh: false);
    } catch (error) {
      if (mounted) _showSnack('保存提醒失败：$error');
    }
  }

  Future<void> _editScheduler() async {
    final draft = await showModalBottomSheet<FundAlertSchedulerDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _FundSchedulerSettingsSheet(
        status: _schedulerStatus ?? FundAlertSchedulerStatus.defaults(),
      ),
    );
    if (draft == null) return;
    try {
      final status = await widget.repository.updateAlertScheduler(draft);
      if (!mounted) return;
      setState(() => _schedulerStatus = status);
      await _load(refresh: false);
    } catch (error) {
      if (mounted) _showSnack('保存扫描时间失败：$error');
    }
  }

  Future<void> _runSchedulerScan() async {
    setState(() => _isRefreshing = true);
    try {
      final status = await widget.repository.runAlertScan(refresh: true);
      if (!mounted) return;
      setState(() => _schedulerStatus = status);
      await _load(refresh: false);
    } catch (error) {
      if (mounted) _showSnack('基金提醒扫描失败：$error');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _delete(FundPositionSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除基金持仓'),
        content: Text('删除“${summary.position.name}”后，当前基金持仓会移除。确认删除吗？'),
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
    if (confirmed != true) return;
    try {
      await widget.repository.deletePosition(summary.position.id);
      await _load(refresh: false, showSpinner: true);
    } catch (error) {
      if (mounted) _showSnack('删除失败：$error');
    }
  }

  Future<void> _openDetail(FundPositionSummary summary) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (detailContext) => FundDetailScreen(
          summary: summary,
          repository: widget.repository,
          onBuy: () => _trade(summary, 'buy'),
          onSell: () => _trade(summary, 'sell'),
          onEditAlert: () => _editAlert(summary),
          onDelete: () {
            Navigator.of(detailContext).pop();
            unawaited(_delete(summary));
          },
        ),
      ),
    );
    if (mounted) unawaited(_load(refresh: false));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final totalMarketValue = _sum((item) => item.marketValue);
    final totalProfit = _sum((item) => item.totalProfit);
    final totalDayProfit = _sum((item) => item.dayProfit);
    final recommendations = _summaries
        .map((item) => item.gridRecommendation)
        .whereType<FundGridRecommendation>()
        .toList();
    final hasEstimated = _summaries.any((item) => item.isEstimated);

    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
            children: [
              _FundHeader(
                isRefreshing: _isRefreshing,
                onBack: () => Navigator.of(context).pop(),
                onRefresh: () => _load(refresh: true),
              ),
              const SizedBox(height: 8),
              _FundAccountOverview(
                marketValue: totalMarketValue,
                dayProfit: totalDayProfit,
                totalProfit: totalProfit,
                label: hasEstimated ? '估算当日收益' : '当日收益',
              ),
              const SizedBox(height: 8),
              _FundSchedulerPanel(
                status: _schedulerStatus ?? FundAlertSchedulerStatus.defaults(),
                onEdit: _editScheduler,
                onRunNow: _runSchedulerScan,
              ),
              const SizedBox(height: 8),
              if (recommendations.isNotEmpty) ...[
                _FundAlertStrip(recommendations: recommendations),
                const SizedBox(height: 8),
              ],
              _FundToolbar(onAddFund: _addFund),
              const SizedBox(height: 6),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_error != null)
                EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: '加载失败',
                  subtitle: '基金数据暂时不可用，请稍后刷新。',
                  actionLabel: '重试',
                  onAction: () => _load(refresh: true, showSpinner: true),
                )
              else if (_summaries.isEmpty)
                EmptyState(
                  icon: Icons.savings_outlined,
                  title: '还没有基金',
                  subtitle: '搜索基金代码或名称，记录份额和成本净值。',
                  actionLabel: '添加基金',
                  onAction: _addFund,
                )
              else
                _FundHoldingTable(
                  summaries: _summaries,
                  onTap: _openDetail,
                  onEditAlert: _editAlert,
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _sum(double Function(FundPositionSummary item) select) {
    return _summaries.fold<double>(0, (sum, item) => sum + select(item));
  }
}

class _FundHeader extends StatelessWidget {
  const _FundHeader({
    required this.isRefreshing,
    required this.onBack,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '基金',
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: '刷新',
          onPressed: isRefreshing ? null : onRefresh,
          icon: isRefreshing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _FundAccountOverview extends StatelessWidget {
  const _FundAccountOverview({
    required this.marketValue,
    required this.dayProfit,
    required this.totalProfit,
    required this.label,
  });

  final double marketValue;
  final double dayProfit;
  final double totalProfit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OverviewMetric(
              label: '账户资产',
              value: _money(marketValue, signed: false),
            ),
          ),
          Expanded(
            child: _OverviewMetric(
              label: label,
              value: _money(dayProfit),
              valueColor: _profitColor(dayProfit),
              alignCenter: true,
            ),
          ),
          Expanded(
            child: _OverviewMetric(
              label: '持有收益',
              value: _money(totalProfit),
              valueColor: _profitColor(totalProfit),
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FundToolbar extends StatelessWidget {
  const _FundToolbar({required this.onAddFund});

  final VoidCallback onAddFund;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.tune_rounded, color: mutedIconColor(context)),
        const SizedBox(width: 12),
        Icon(Icons.grid_view_rounded, color: mutedIconColor(context)),
        const SizedBox(width: 12),
        Icon(Icons.flag_outlined, color: mutedIconColor(context)),
        const Spacer(),
        TextButton.icon(
          onPressed: onAddFund,
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加基金'),
        ),
      ],
    );
  }
}

class _FundSchedulerPanel extends StatelessWidget {
  const _FundSchedulerPanel({
    required this.status,
    required this.onEdit,
    required this.onRunNow,
  });

  final FundAlertSchedulerStatus status;
  final VoidCallback onEdit;
  final VoidCallback onRunNow;

  @override
  Widget build(BuildContext context) {
    final accent = status.enabled
        ? appAccentColor(context)
        : secondaryTextColor(context);
    final stateText = status.enabled
        ? status.running
              ? '已启用'
              : '已启用 · 待启动'
        : '未启用';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor(context),
        border: Border.all(color: borderColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '策略提醒',
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stateText,
                      style: TextStyle(
                        color: secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '立即扫描',
                onPressed: status.scanning ? null : onRunNow,
                icon: status.scanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: '设置时间',
                onPressed: onEdit,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SchedulerChip(
                icon: Icons.access_time_rounded,
                label: status.reminderTimes.join(' / '),
              ),
              _SchedulerChip(
                icon: Icons.fact_check_outlined,
                label: '上次 ${_dateTimeText(status.lastScanAt)}',
              ),
              _SchedulerChip(
                icon: Icons.notifications_active_outlined,
                label: '触发 ${status.createdCount}',
              ),
              _SchedulerChip(
                icon: Icons.skip_next_rounded,
                label: '下次 ${_dateTimeText(status.nextRunAt)}',
              ),
              if (status.lastError.isNotEmpty)
                _SchedulerChip(
                  icon: Icons.error_outline_rounded,
                  label: '异常',
                  color: const Color(0xFFFF4D67),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SchedulerChip extends StatelessWidget {
  const _SchedulerChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? secondaryTextColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: effectiveColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FundAlertStrip extends StatelessWidget {
  const _FundAlertStrip({required this.recommendations});

  final List<FundGridRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    final first = recommendations.first;
    final color = first.isBuy
        ? const Color(0xFFFF4D67)
        : const Color(0xFF20C997);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              recommendations.length == 1
                  ? '${first.name} · ${first.actionLabel}'
                  : '${recommendations.length} 只基金触发提醒',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primaryTextColor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            _percent(first.changeRate),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _FundHoldingTable extends StatelessWidget {
  const _FundHoldingTable({
    required this.summaries,
    required this.onTap,
    required this.onEditAlert,
  });

  final List<FundPositionSummary> summaries;
  final ValueChanged<FundPositionSummary> onTap;
  final ValueChanged<FundPositionSummary> onEditAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor(context),
        border: Border.all(color: borderColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _TableHeader(),
          ...summaries.map(
            (summary) => _FundTableRow(
              summary: summary,
              onTap: () => onTap(summary),
              onEditAlert: () => onEditAlert(summary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: secondaryTextColor(context),
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor(context))),
      ),
      child: Row(
        children: [
          Expanded(flex: 44, child: Text('基金', style: style)),
          Expanded(
            flex: 28,
            child: Text('当日收益', textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 28,
            child: Text('持有收益', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _FundTableRow extends StatelessWidget {
  const _FundTableRow({
    required this.summary,
    required this.onTap,
    required this.onEditAlert,
  });

  final FundPositionSummary summary;
  final VoidCallback onTap;
  final VoidCallback onEditAlert;

  @override
  Widget build(BuildContext context) {
    final position = summary.position;
    final recommendation = summary.gridRecommendation;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor(context))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${summary.marketValue.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (recommendation != null) ...[
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: onEditAlert,
                      child: _SmallSignalBadge(
                        text: recommendation.actionLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 28,
              child: _ValueColumn(
                primary: _money(summary.dayProfit),
                secondary: _percent(summary.dayProfitRate),
                value: summary.dayProfit,
              ),
            ),
            Expanded(
              flex: 28,
              child: _ValueColumn(
                primary: _money(summary.holdingProfit),
                secondary: _percent(summary.holdingProfitRate),
                value: summary.holdingProfit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
    this.alignCenter = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;
  final bool alignCenter;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment = alignEnd
        ? CrossAxisAlignment.end
        : alignCenter
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final alignment = alignEnd
        ? Alignment.centerRight
        : alignCenter
        ? Alignment.center
        : Alignment.centerLeft;
    final textAlign = alignEnd
        ? TextAlign.right
        : alignCenter
        ? TextAlign.center
        : TextAlign.left;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          maxLines: 1,
          textAlign: textAlign,
          style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: valueColor ?? primaryTextColor(context),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ValueColumn extends StatelessWidget {
  const _ValueColumn({
    required this.primary,
    required this.secondary,
    required this.value,
  });

  final String primary;
  final String secondary;
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = _profitColor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          secondary,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: color.withValues(alpha: 0.82),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SmallSignalBadge extends StatelessWidget {
  const _SmallSignalBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: appAccentContainerColor(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: appAccentColor(context),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FundAddSheet extends StatefulWidget {
  const _FundAddSheet({required this.repository});

  final FundRepository repository;

  @override
  State<_FundAddSheet> createState() => _FundAddSheetState();
}

class _FundAddSheetState extends State<_FundAddSheet> {
  final _queryController = TextEditingController();
  final _sharesController = TextEditingController();
  final _costNavController = TextEditingController();
  final _feeController = TextEditingController(text: '0');
  List<FundSearchResult> _results = const [];
  FundSearchResult? _selected;
  bool _isSearching = false;

  @override
  void dispose() {
    _queryController.dispose();
    _sharesController.dispose();
    _costNavController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = await widget.repository.searchFunds(query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _submit() {
    final selected = _selected;
    final shares = double.tryParse(_sharesController.text.trim());
    final costNav = double.tryParse(_costNavController.text.trim());
    final fee = double.tryParse(_feeController.text.trim()) ?? 0;
    if (selected == null ||
        shares == null ||
        shares <= 0 ||
        costNav == null ||
        costNav < 0) {
      return;
    }
    Navigator.of(context).pop(
      _FundCreateDraft(
        fund: selected,
        shares: shares,
        costNav: costNav,
        fee: fee,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          _SheetTitle(title: '添加场外基金'),
          const SizedBox(height: 12),
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: '基金代码/名称',
              suffixIcon: IconButton(
                onPressed: _isSearching ? null : _search,
                icon: const Icon(Icons.search_rounded),
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          if (_isSearching)
            const LinearProgressIndicator()
          else
            ..._results
                .take(6)
                .map(
                  (fund) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(fund.name),
                    subtitle: Text(
                      '${fund.code} · ${fund.company.isEmpty ? fund.fundType : fund.company}',
                    ),
                    trailing: _selected?.code == fund.code
                        ? const Icon(Icons.check_circle_rounded)
                        : null,
                    onTap: () => setState(() => _selected = fund),
                  ),
                ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sharesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '持有份额'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _costNavController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '成本净值'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '手续费'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('保存基金'),
          ),
        ],
      ),
    );
  }
}

class _FundTradeSheet extends StatefulWidget {
  const _FundTradeSheet({required this.summary, required this.action});

  final FundPositionSummary summary;
  final String action;

  @override
  State<_FundTradeSheet> createState() => _FundTradeSheetState();
}

class _FundTradeSheetState extends State<_FundTradeSheet> {
  late final TextEditingController _sharesController;
  late final TextEditingController _navController;
  final _feeController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _sharesController = TextEditingController();
    _navController = TextEditingController(
      text: widget.summary.displayNav > 0
          ? widget.summary.displayNav.toStringAsFixed(4)
          : '',
    );
  }

  @override
  void dispose() {
    _sharesController.dispose();
    _navController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _submit() {
    final shares = double.tryParse(_sharesController.text.trim());
    final nav = double.tryParse(_navController.text.trim());
    final fee = double.tryParse(_feeController.text.trim()) ?? 0;
    if (shares == null || shares <= 0 || nav == null || nav < 0) return;
    Navigator.of(context).pop(
      FundTradeDraft(action: widget.action, shares: shares, nav: nav, fee: fee),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = widget.action == 'buy';
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle(
            title: '${isBuy ? '买入' : '卖出'} ${widget.summary.position.name}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sharesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '份额'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _navController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '净值'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '手续费'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _submit,
            icon: Icon(isBuy ? Icons.add_rounded : Icons.remove_rounded),
            label: Text(isBuy ? '记录买入' : '记录卖出'),
          ),
        ],
      ),
    );
  }
}

class _FundAlertSettingsSheet extends StatefulWidget {
  const _FundAlertSettingsSheet({required this.summary});

  final FundPositionSummary summary;

  @override
  State<_FundAlertSettingsSheet> createState() =>
      _FundAlertSettingsSheetState();
}

class _FundAlertSettingsSheetState extends State<_FundAlertSettingsSheet> {
  late bool _enabled;
  late final TextEditingController _thresholdController;
  late final TextEditingController _buyAmountController;
  late final TextEditingController _sellRatioController;

  @override
  void initState() {
    super.initState();
    final position = widget.summary.position;
    _enabled = position.alertEnabled;
    _thresholdController = TextEditingController(
      text: position.alertThresholdPercent.toStringAsFixed(1),
    );
    _buyAmountController = TextEditingController(
      text: position.alertBuyAmount.toStringAsFixed(0),
    );
    _sellRatioController = TextEditingController(
      text: (position.alertSellRatio * 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _buyAmountController.dispose();
    _sellRatioController.dispose();
    super.dispose();
  }

  void _submit() {
    final threshold = double.tryParse(_thresholdController.text.trim());
    final buyAmount = double.tryParse(_buyAmountController.text.trim());
    final sellPercent = double.tryParse(_sellRatioController.text.trim());
    if (threshold == null ||
        threshold <= 0 ||
        buyAmount == null ||
        buyAmount < 0 ||
        sellPercent == null ||
        sellPercent <= 0 ||
        sellPercent > 100) {
      return;
    }
    Navigator.of(context).pop(
      FundAlertSettingsDraft(
        alertEnabled: _enabled,
        thresholdPercent: threshold,
        buyAmount: buyAmount,
        sellRatio: sellPercent / 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          _SheetTitle(title: '提醒规则'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('启用涨跌提醒'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _thresholdController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '涨跌阈值 %'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _buyAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '下跌触发加仓金额'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sellRatioController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '上涨触发减仓比例 %'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('保存规则'),
          ),
        ],
      ),
    );
  }
}

class _FundSchedulerSettingsSheet extends StatefulWidget {
  const _FundSchedulerSettingsSheet({required this.status});

  final FundAlertSchedulerStatus status;

  @override
  State<_FundSchedulerSettingsSheet> createState() =>
      _FundSchedulerSettingsSheetState();
}

class _FundSchedulerSettingsSheetState
    extends State<_FundSchedulerSettingsSheet> {
  late bool _enabled;
  late final TextEditingController _timesController;
  late final TextEditingController _dueWindowController;

  @override
  void initState() {
    super.initState();
    _enabled = widget.status.enabled;
    _timesController = TextEditingController(
      text: widget.status.reminderTimes.join(', '),
    );
    _dueWindowController = TextEditingController(
      text: widget.status.dueWindowMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _timesController.dispose();
    _dueWindowController.dispose();
    super.dispose();
  }

  void _submit() {
    final times = _timesController.text
        .split(RegExp(r'[,，\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final dueWindow = int.tryParse(_dueWindowController.text.trim());
    if (times.isEmpty || dueWindow == null || dueWindow < 1 || dueWindow > 60) {
      return;
    }
    Navigator.of(context).pop(
      FundAlertSchedulerDraft(
        enabled: _enabled,
        reminderTimes: times,
        dueWindowMinutes: dueWindow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          _SheetTitle(title: '扫描时间'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('启用自动扫描'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _timesController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: '提醒时间',
              hintText: '14:20, 14:30, 14:50',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dueWindowController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '有效窗口(分钟)'),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('保存时间'),
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: primaryTextColor(context),
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _FundCreateDraft {
  const _FundCreateDraft({
    required this.fund,
    required this.shares,
    required this.costNav,
    required this.fee,
  });

  final FundSearchResult fund;
  final double shares;
  final double costNav;
  final double fee;
}

String _money(double value, {bool signed = true}) {
  final sign = signed
      ? value > 0
            ? '+'
            : value < 0
            ? '-'
            : ''
      : '';
  return '$sign¥${value.abs().toStringAsFixed(2)}';
}

String _percent(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  return '$sign${value.abs().toStringAsFixed(2)}%';
}

String _dateTimeText(DateTime? value) {
  if (value == null) return '尚未扫描';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

Color _profitColor(double value) {
  if (value > 0) return const Color(0xFFFF4D67);
  if (value < 0) return const Color(0xFF20C997);
  return const Color(0xFF94A3B8);
}
