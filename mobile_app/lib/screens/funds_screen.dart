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
        amount: draft.amount,
        fee: draft.fee,
        autoNav: draft.autoNav,
        tradeDate: draft.tradeDate,
        operationDate: draft.operationDate,
        operationAfterCutoff: draft.operationAfterCutoff,
        note: draft.note,
      );
      await _load(refresh: true, showSpinner: true);
    } catch (error) {
      if (mounted) _showSnack('添加基金失败：$error');
    }
  }

  Future<void> _trade(
    FundPositionSummary summary,
    String action, {
    String? operationLabel,
  }) async {
    final draft = await showModalBottomSheet<FundTradeDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _FundTradeSheet(
        summary: summary,
        action: action,
        operationLabel: operationLabel,
      ),
    );
    if (draft == null) return;
    try {
      await widget.repository.createTrade(summary.position.id, draft);
      await _load(refresh: true);
    } catch (error) {
      if (mounted) _showSnack('交易记录失败：$error');
    }
  }

  Future<void> _adjustFund(FundPositionSummary summary) async {
    final action = await showModalBottomSheet<_FundSyncAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _FundSyncActionSheet(summary: summary),
    );
    if (action == null) return;
    switch (action) {
      case _FundSyncAction.correct:
        await _syncCurrentHolding(summary);
        break;
      case _FundSyncAction.buy:
        await _trade(summary, 'buy', operationLabel: '同步加仓');
        break;
      case _FundSyncAction.sell:
        await _trade(summary, 'sell', operationLabel: '同步减仓');
        break;
      case _FundSyncAction.recurring:
        await _trade(summary, 'buy', operationLabel: '同步定投');
        break;
      case _FundSyncAction.convert:
      case _FundSyncAction.batch:
        if (mounted) _showSnack('转换和批量同步入口已预留，当前先用加仓/减仓记录迁移。');
        break;
    }
  }

  Future<void> _syncCurrentHolding(FundPositionSummary summary) async {
    final draft = await showModalBottomSheet<FundHoldingSyncDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => _FundHoldingSyncSheet(summary: summary),
    );
    if (draft == null) return;
    try {
      await widget.repository.syncPositionHolding(summary.position.id, draft);
      await _load(refresh: true, showSpinner: true);
    } catch (error) {
      if (mounted) _showSnack('修正持仓失败：$error');
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

  Future<void> _toggleSchedulerEnabled() async {
    final current = _schedulerStatus ?? FundAlertSchedulerStatus.defaults();
    final nextEnabled = !current.enabled;
    setState(() => _isRefreshing = true);
    try {
      final status = await widget.repository.updateAlertScheduler(
        FundAlertSchedulerDraft(
          enabled: nextEnabled,
          reminderTimes: current.reminderTimes.isEmpty
              ? const ['14:30']
              : current.reminderTimes,
          dueWindowMinutes: current.dueWindowMinutes,
        ),
      );
      if (!mounted) return;
      setState(() => _schedulerStatus = status);
      _showSnack(nextEnabled ? '已启用基金提醒自动扫描' : '已停用基金提醒自动扫描');
      await _load(refresh: false);
    } catch (error) {
      if (mounted) _showSnack('切换自动扫描失败：$error');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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
          onAdjust: () => _adjustFund(summary),
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
                onToggleEnabled: _toggleSchedulerEnabled,
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
    required this.onToggleEnabled,
    required this.onRunNow,
  });

  final FundAlertSchedulerStatus status;
  final VoidCallback onEdit;
  final VoidCallback onToggleEnabled;
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
              Switch(
                value: status.enabled,
                onChanged: status.scanning ? null : (_) => onToggleEnabled(),
              ),
              IconButton(
                tooltip: '立即扫描',
                onPressed: status.scanning ? null : onRunNow,
                icon: status.scanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
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
                  ? '${first.name} · ${_fundRecommendationLabel(first)}'
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
                        text: _fundRecommendationLabel(recommendation),
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

enum _FundSyncAction { correct, buy, sell, recurring, convert, batch }

class _FundSyncActionSheet extends StatelessWidget {
  const _FundSyncActionSheet({required this.summary});

  final FundPositionSummary summary;

  @override
  Widget build(BuildContext context) {
    final position = summary.position;
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
          _SheetTitle(
            title: '修改持仓',
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
          _NoticeBox(text: '修改仅用于同步原平台记录，并非真实交易。请确认已在原平台完成操作。'),
          const SizedBox(height: 12),
          _FundTradeSummaryCard(summary: summary),
          const SizedBox(height: 12),
          _SyncMetricGrid(
            items: [
              _SyncMetricItem(
                '持有金额',
                _money(summary.marketValue, signed: false),
              ),
              _SyncMetricItem('持有收益', _money(summary.holdingProfit)),
              _SyncMetricItem('持有份额', position.shares.toStringAsFixed(2)),
              const _SyncMetricItem('持有天数', '按记录'),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.15,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _SyncActionTile(
                label: '修正当前持仓',
                color: appAccentColor(context),
                onTap: () => Navigator.of(context).pop(_FundSyncAction.correct),
              ),
              _SyncActionTile(
                label: '同步加仓',
                color: const Color(0xFFFF4D67),
                onTap: () => Navigator.of(context).pop(_FundSyncAction.buy),
              ),
              _SyncActionTile(
                label: '同步减仓',
                color: const Color(0xFF20C997),
                onTap: () => Navigator.of(context).pop(_FundSyncAction.sell),
              ),
              _SyncActionTile(
                label: '同步定投',
                color: appAccentColor(context),
                onTap: () =>
                    Navigator.of(context).pop(_FundSyncAction.recurring),
              ),
              _SyncActionTile(
                label: '同步转换',
                color: appAccentColor(context),
                onTap: () => Navigator.of(context).pop(_FundSyncAction.convert),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_FundSyncAction.batch),
            icon: const Icon(Icons.library_add_check_rounded),
            label: const Text('批量同步操作'),
          ),
        ],
      ),
    );
  }
}

class _SyncActionTile extends StatelessWidget {
  const _SyncActionTile({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _SyncMetricGrid extends StatelessWidget {
  const _SyncMetricGrid({required this.items});

  final List<_SyncMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              width: (MediaQuery.sizeOf(context).width - 56) / 2,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: appAccentContainerColor(context).withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryTextColor(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SyncMetricItem {
  const _SyncMetricItem(this.label, this.value);

  final String label;
  final String value;
}

class _FundHoldingSyncSheet extends StatefulWidget {
  const _FundHoldingSyncSheet({required this.summary});

  final FundPositionSummary summary;

  @override
  State<_FundHoldingSyncSheet> createState() => _FundHoldingSyncSheetState();
}

class _FundHoldingSyncSheetState extends State<_FundHoldingSyncSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _sharesController;
  late final TextEditingController _holdingProfitController;
  bool _useAmount = true;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.summary.marketValue > 0
          ? widget.summary.marketValue.toStringAsFixed(2)
          : '',
    );
    _sharesController = TextEditingController(
      text: widget.summary.position.shares > 0
          ? widget.summary.position.shares.toStringAsFixed(2)
          : '',
    );
    _holdingProfitController = TextEditingController(
      text: widget.summary.holdingProfit == 0
          ? ''
          : widget.summary.holdingProfit.toStringAsFixed(2),
    );
    _amountController.addListener(_rebuild);
    _sharesController.addListener(_rebuild);
    _holdingProfitController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sharesController.dispose();
    _holdingProfitController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  double get _latestNav => widget.summary.displayNav;

  DateTime get _tradeDate =>
      widget.summary.latestNav?.navDate ?? DateTime.now();

  void _submit() {
    final values = _resolvedValues();
    if (values == null) return;
    Navigator.of(context).pop(
      FundHoldingSyncDraft(
        shares: values.shares,
        costNav: values.costNav,
        tradeDate: _tradeDate,
        note: [
          '修正当前持仓',
          '持有金额 ${values.amount.toStringAsFixed(2)}',
          '持有收益 ${values.holdingProfit.toStringAsFixed(2)}',
          '参考净值 ${_latestNav.toStringAsFixed(4)}',
        ].join('；'),
      ),
    );
  }

  _FundHoldingSyncValues? _resolvedValues() {
    final nav = _latestNav;
    if (nav <= 0) return null;
    final holdingProfit = double.tryParse(_holdingProfitController.text.trim());
    if (holdingProfit == null) return null;
    double amount;
    double shares;
    if (_useAmount) {
      amount = double.tryParse(_amountController.text.trim()) ?? 0;
      if (amount <= 0) return null;
      shares = amount / nav;
    } else {
      shares = double.tryParse(_sharesController.text.trim()) ?? 0;
      if (shares <= 0) return null;
      amount = shares * nav;
    }
    final costNav = (amount - holdingProfit) / shares;
    if (costNav <= 0) return null;
    return _FundHoldingSyncValues(
      amount: amount,
      holdingProfit: holdingProfit,
      shares: shares,
      costNav: costNav,
    );
  }

  String _previewText() {
    final values = _resolvedValues();
    if (values == null) return '';
    return '修正后份额 ${values.shares.toStringAsFixed(2)} · 成本净值 ${values.costNav.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewText();
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
          _SheetTitle(
            title: '修正当前持仓',
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
          _NoticeBox(text: '用于修正从其他平台同步来的当前持仓。保存后会用这一笔修正记录替换旧的导入交易记录。'),
          const SizedBox(height: 12),
          _FundTradeSummaryCard(summary: widget.summary),
          const SizedBox(height: 12),
          _SyncMetricGrid(
            items: [
              _SyncMetricItem('最新净值', _latestNav.toStringAsFixed(4)),
              _SyncMetricItem('净值日期', _dateOnlyText(_tradeDate)),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.payments_rounded),
                label: Text('金额'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.tag_rounded),
                label: Text('份额'),
              ),
            ],
            selected: {_useAmount},
            onSelectionChanged: (value) {
              setState(() => _useAmount = value.first);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _useAmount ? _amountController : _sharesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _useAmount ? '持有金额' : '持有份额',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _holdingProfitController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: '持有收益',
              helperText: '按其他平台显示的当前持有收益填写，亏损填负数。',
            ),
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              preview,
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _resolvedValues() == null ? null : _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('确认修正'),
          ),
        ],
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
  final _amountController = TextEditingController();
  final _sharesController = TextEditingController();
  final _costNavController = TextEditingController();
  final _feeController = TextEditingController(text: '0');
  final _holdingProfitController = TextEditingController();
  List<FundSearchResult> _results = const [];
  FundSearchResult? _selected;
  bool _useAmount = true;
  bool _isSearching = false;
  bool _isLoadingNav = false;
  _FundTradeTimeSelection _tradeTime = _FundTradeTimeSelection.initial();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_rebuildConversion);
    _sharesController.addListener(_rebuildConversion);
    _costNavController.addListener(_rebuildConversion);
    _feeController.addListener(_rebuildConversion);
    _holdingProfitController.addListener(_rebuildConversion);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _amountController.dispose();
    _sharesController.dispose();
    _costNavController.dispose();
    _feeController.dispose();
    _holdingProfitController.dispose();
    super.dispose();
  }

  void _rebuildConversion() {
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    try {
      final results = await widget.repository.searchFunds(query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectFund(FundSearchResult fund) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = fund;
      _isLoadingNav = true;
    });
    try {
      final navs = await widget.repository.loadNavs(
        fund.code,
        limit: 1,
        refresh: true,
      );
      if (!mounted ||
          navs.isEmpty ||
          _costNavController.text.trim().isNotEmpty) {
        return;
      }
      final nav = navs.first.unitNav;
      if (nav > 0) _costNavController.text = nav.toStringAsFixed(4);
    } finally {
      if (mounted) setState(() => _isLoadingNav = false);
    }
  }

  void _submit() {
    final selected = _selected;
    final values = _resolvedCreateValues();
    if (selected == null || values == null) {
      return;
    }
    Navigator.of(context).pop(
      _FundCreateDraft(
        fund: selected,
        shares: values.shares,
        costNav: values.costNav,
        amount: _useAmount && values.holdingProfit == null ? values.amount : 0,
        fee: values.fee,
        autoNav: values.holdingProfit == null,
        tradeDate: _tradeTime.confirmDate,
        operationDate: _tradeTime.date,
        operationAfterCutoff: _tradeTime.afterCutoff,
        note: _createNote(values),
      ),
    );
  }

  _FundCreateValues? _resolvedCreateValues() {
    final nav = double.tryParse(_costNavController.text.trim());
    final fee = double.tryParse(_feeController.text.trim()) ?? 0;
    if (nav == null || nav <= 0 || fee < 0) return null;
    final profitText = _holdingProfitController.text.trim();
    final holdingProfit = profitText.isEmpty
        ? null
        : double.tryParse(profitText);
    if (profitText.isNotEmpty && holdingProfit == null) return null;

    double shares;
    double referenceAmount;
    if (_useAmount) {
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) return null;
      referenceAmount = amount;
      shares = holdingProfit == null ? (amount - fee) / nav : amount / nav;
    } else {
      final parsedShares = double.tryParse(_sharesController.text.trim());
      if (parsedShares == null || parsedShares <= 0) return null;
      shares = parsedShares;
      referenceAmount = shares * nav;
    }
    if (shares <= 0) return null;

    final costNav = holdingProfit == null
        ? nav
        : (referenceAmount - holdingProfit - fee) / shares;
    if (costNav <= 0) return null;
    final amount = holdingProfit == null ? shares * nav + fee : referenceAmount;
    return _FundCreateValues(
      shares: shares,
      costNav: costNav,
      fee: fee,
      amount: amount,
      holdingProfit: holdingProfit,
    );
  }

  String _conversionText() {
    final values = _resolvedCreateValues();
    if (values == null) return '';
    if (values.holdingProfit != null) {
      return '同步份额 ${values.shares.toStringAsFixed(2)} · 成本净值 ${values.costNav.toStringAsFixed(4)}';
    }
    return _useAmount
        ? '预计份额 ${values.shares.toStringAsFixed(2)}'
        : '预计金额 ${values.amount.toStringAsFixed(2)}';
  }

  String _createNote(_FundCreateValues values) {
    final parts = <String>[
      '同步导入',
      '原平台时间 ${_dateLabel(_tradeTime.date)} ${_tradeTime.cutoffLabel}',
      '预计确认日 ${_dateOnlyText(_tradeTime.confirmDate)}',
    ];
    if (values.holdingProfit != null) {
      parts.add('持有收益 ${values.holdingProfit!.toStringAsFixed(2)}');
    }
    return parts.join('；');
  }

  Future<void> _editTradeTime() async {
    final next = await _showFundTradeTimePicker(
      context: context,
      title: '买入时间',
      initial: _tradeTime,
    );
    if (mounted && next != null) setState(() => _tradeTime = next);
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
          _SheetTitle(
            title: '添加场外基金',
            onClose: () => Navigator.of(context).pop(),
          ),
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
                    onTap: () => unawaited(_selectFund(fund)),
                  ),
                ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.payments_rounded),
                label: Text('金额'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.tag_rounded),
                label: Text('份额'),
              ),
            ],
            selected: {_useAmount},
            onSelectionChanged: (value) {
              setState(() => _useAmount = value.first);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _useAmount
                      ? _amountController
                      : _sharesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _useAmount ? '买入/持有金额' : '持有份额',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _costNavController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _isLoadingNav ? '净值 读取中' : '成本/同步净值',
                  ),
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
          const SizedBox(height: 8),
          TextField(
            controller: _holdingProfitController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: '初始持有收益',
              helperText: '迁移旧持仓时填写，用当前金额反推成本净值。',
            ),
          ),
          const SizedBox(height: 8),
          _TradeTimeTile(
            label: '原平台买入时间',
            selection: _tradeTime,
            onTap: _editTradeTime,
          ),
          if (_conversionText().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _conversionText(),
              style: TextStyle(
                color: secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
  const _FundTradeSheet({
    required this.summary,
    required this.action,
    this.operationLabel,
  });

  final FundPositionSummary summary;
  final String action;
  final String? operationLabel;

  @override
  State<_FundTradeSheet> createState() => _FundTradeSheetState();
}

class _FundTradeSheetState extends State<_FundTradeSheet> {
  final _amountController = TextEditingController();
  late final TextEditingController _sharesController;
  late final TextEditingController _navController;
  late final TextEditingController _feeRateController;
  late bool _useAmount;
  double? _selectedSellRatio;
  _FundTradeTimeSelection _tradeTime = _FundTradeTimeSelection.initial();

  @override
  void initState() {
    super.initState();
    final isBuy = widget.action == 'buy';
    _useAmount = isBuy;
    _sharesController = TextEditingController();
    _navController = TextEditingController(
      text: widget.summary.displayNav > 0
          ? widget.summary.displayNav.toStringAsFixed(4)
          : '',
    );
    _feeRateController = TextEditingController(text: isBuy ? '0' : '0.50');
    _amountController.addListener(_rebuild);
    _sharesController.addListener(_rebuild);
    _navController.addListener(_rebuild);
    _feeRateController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sharesController.dispose();
    _navController.dispose();
    _feeRateController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool get _isBuy => widget.action == 'buy';

  String get _title => widget.operationLabel ?? (_isBuy ? '同步加仓' : '同步减仓');

  void _submit() {
    final values = _resolvedTradeValues();
    if (values == null) return;
    Navigator.of(context).pop(
      FundTradeDraft(
        action: widget.action,
        shares: values.shares,
        nav: values.nav,
        amount: _useAmount ? values.amount : 0,
        fee: values.fee,
        autoNav: true,
        tradeDate: _tradeTime.confirmDate,
        operationDate: _tradeTime.date,
        operationAfterCutoff: _tradeTime.afterCutoff,
        note: _tradeNote(values),
      ),
    );
  }

  _FundTradeValues? _resolvedTradeValues() {
    final nav = double.tryParse(_navController.text.trim());
    final feeRate = double.tryParse(_feeRateController.text.trim()) ?? 0;
    if (nav == null || nav <= 0 || feeRate < 0) return null;

    double shares;
    double amount;
    if (_useAmount) {
      final parsedAmount = double.tryParse(_amountController.text.trim());
      if (parsedAmount == null || parsedAmount <= 0) return null;
      amount = parsedAmount;
      final fee = amount * feeRate / 100;
      shares = _isBuy ? (amount - fee) / nav : amount / nav;
    } else {
      final parsedShares = double.tryParse(_sharesController.text.trim());
      if (parsedShares == null || parsedShares <= 0) return null;
      shares = parsedShares;
      amount = shares * nav;
    }

    if (shares <= 0) return null;
    if (!_isBuy && shares > widget.summary.position.shares) return null;
    final fee = amount * feeRate / 100;
    return _FundTradeValues(
      shares: shares,
      nav: nav,
      amount: amount,
      fee: fee,
      feeRate: feeRate,
    );
  }

  String _tradeNote(_FundTradeValues values) {
    return [
      _title,
      '原平台时间 ${_dateLabel(_tradeTime.date)} ${_tradeTime.cutoffLabel}',
      '预计确认日 ${_dateOnlyText(_tradeTime.confirmDate)}',
      '金额 ${values.amount.toStringAsFixed(2)}',
      '费率 ${values.feeRate.toStringAsFixed(2)}%',
    ].join('；');
  }

  void _applySellRatio(double ratio) {
    final shares = widget.summary.position.shares * ratio;
    _sharesController.text = shares.toStringAsFixed(2);
    setState(() {
      _useAmount = false;
      _selectedSellRatio = ratio;
    });
  }

  Future<void> _editTradeTime() async {
    final next = await _showFundTradeTimePicker(
      context: context,
      title: _isBuy ? '加仓时间' : '减仓时间',
      initial: _tradeTime,
    );
    if (mounted && next != null) setState(() => _tradeTime = next);
  }

  void _setFeeRate(double value) {
    _feeRateController.text = value.toStringAsFixed(2);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final values = _resolvedTradeValues();
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
          _SheetTitle(
            title: '$_title ${widget.summary.position.name}',
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
          _NoticeBox(text: '这里仅同步你在原平台已完成的操作，不会真实下单。后端会按基金净值交易日确认。'),
          const SizedBox(height: 12),
          _FundTradeSummaryCard(summary: widget.summary),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.payments_rounded),
                label: Text('金额'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.tag_rounded),
                label: Text('份额'),
              ),
            ],
            selected: {_useAmount},
            onSelectionChanged: (value) {
              setState(() {
                _useAmount = value.first;
                if (_useAmount) _selectedSellRatio = null;
              });
            },
          ),
          if (!_isBuy) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RatioChip(
                  label: '1/4',
                  selected: _selectedSellRatio == 0.25,
                  onTap: () => _applySellRatio(0.25),
                ),
                _RatioChip(
                  label: '1/3',
                  selected: _selectedSellRatio == 1 / 3,
                  onTap: () => _applySellRatio(1 / 3),
                ),
                _RatioChip(
                  label: '1/2',
                  selected: _selectedSellRatio == 0.5,
                  onTap: () => _applySellRatio(0.5),
                ),
                _RatioChip(
                  label: '全部',
                  selected: _selectedSellRatio == 1,
                  onTap: () => _applySellRatio(1),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _useAmount
                      ? _amountController
                      : _sharesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _useAmount
                        ? (_isBuy ? '同步买入金额' : '同步卖出金额')
                        : (_isBuy ? '同步买入份额' : '同步卖出份额'),
                  ),
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
            controller: _feeRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '手续费率 %'),
          ),
          if (!_isBuy) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RateChip(label: '1.50%', onTap: () => _setFeeRate(1.5)),
                _RateChip(label: '0.50%', onTap: () => _setFeeRate(0.5)),
                _RateChip(label: '0.00%', onTap: () => _setFeeRate(0)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          _TradeTimeTile(
            label: _isBuy ? '原平台买入时间' : '原平台卖出时间',
            selection: _tradeTime,
            onTap: _editTradeTime,
          ),
          if (values != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(text: '份额 ${values.shares.toStringAsFixed(2)}'),
                _SummaryChip(text: '手续费 ${values.fee.toStringAsFixed(2)}'),
                _SummaryChip(
                  text: '预计 ${_dateOnlyText(_tradeTime.confirmDate)}',
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _submit,
            icon: Icon(_isBuy ? Icons.add_rounded : Icons.remove_rounded),
            label: const Text('确认同步'),
          ),
        ],
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: secondaryTextColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FundTradeSummaryCard extends StatelessWidget {
  const _FundTradeSummaryCard({required this.summary});

  final FundPositionSummary summary;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latestNav;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appAccentContainerColor(context).withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.position.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryTextColor(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${summary.position.fundCode} · 最新净值 ${summary.displayNav.toStringAsFixed(4)}'
            '${latest == null ? '' : '（${_dateOnlyText(latest.navDate)}）'} · ${_percent(summary.displayChangeRate)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeTimeTile extends StatelessWidget {
  const _TradeTimeTile({
    required this.label,
    required this.selection,
    required this.onTap,
  });

  final String label;
  final _FundTradeTimeSelection selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: appAccentContainerColor(context).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: secondaryTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_dateLabel(selection.date)} ${selection.cutoffLabel}',
              style: TextStyle(
                color: primaryTextColor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: secondaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatioChip extends StatelessWidget {
  const _RatioChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: appAccentContainerColor(context),
      labelStyle: TextStyle(
        color: selected ? appAccentColor(context) : secondaryTextColor(context),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: appAccentContainerColor(context).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: secondaryTextColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
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

  @override
  void initState() {
    super.initState();
    final position = widget.summary.position;
    _enabled = position.alertEnabled;
    _thresholdController = TextEditingController(
      text: position.alertThresholdPercent.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  void _submit() {
    final threshold = double.tryParse(_thresholdController.text.trim());
    if (threshold == null || threshold <= 0) {
      return;
    }
    Navigator.of(context).pop(
      FundAlertSettingsDraft(
        alertEnabled: _enabled,
        thresholdPercent: threshold,
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
          const SizedBox(height: 10),
          Text(
            '提醒只判断较上次操作净值的涨跌幅是否触线，实际买入或卖出数量由你自己决定。',
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
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
  late List<String> _reminderTimes;
  final _timeController = TextEditingController();
  late final TextEditingController _dueWindowController;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _enabled = widget.status.enabled;
    _reminderTimes = _normalizeReminderTimes(widget.status.reminderTimes);
    _dueWindowController = TextEditingController(
      text: widget.status.dueWindowMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _timeController.dispose();
    _dueWindowController.dispose();
    super.dispose();
  }

  void _submit() {
    final dueWindow = int.tryParse(_dueWindowController.text.trim());
    if (_reminderTimes.isEmpty ||
        dueWindow == null ||
        dueWindow < 1 ||
        dueWindow > 60) {
      return;
    }
    Navigator.of(context).pop(
      FundAlertSchedulerDraft(
        enabled: _enabled,
        reminderTimes: _reminderTimes,
        dueWindowMinutes: dueWindow,
      ),
    );
  }

  void _addTypedTime() {
    final time = _normalizeReminderTime(_timeController.text);
    if (time == null) {
      setState(() => _timeError = '请输入 09:30 这种 24 小时时间');
      return;
    }
    _addTime(time);
    _timeController.clear();
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked == null) return;
    _addTime(_formatReminderTime(picked.hour, picked.minute));
  }

  void _addTime(String time) {
    final next = {..._reminderTimes, time}.toList()..sort();
    setState(() {
      _reminderTimes = next;
      _timeError = null;
    });
  }

  void _removeTime(String time) {
    if (_reminderTimes.length <= 1) {
      setState(() => _timeError = '至少保留一个提醒时间');
      return;
    }
    setState(() {
      _reminderTimes = _reminderTimes.where((item) => item != time).toList();
      _timeError = null;
    });
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
          _SheetTitle(
            title: '扫描时间',
            onClose: () => Navigator.of(context).pop(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('启用自动扫描'),
          ),
          const SizedBox(height: 8),
          Text(
            '提醒时间',
            style: TextStyle(
              color: secondaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reminderTimes
                .map(
                  (time) => InputChip(
                    label: Text(time),
                    onDeleted: () => _removeTime(time),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _timeController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: '新增提醒时间',
              hintText: '14:20',
              errorText: _timeError,
              suffixIcon: IconButton(
                tooltip: '添加',
                onPressed: _addTypedTime,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            onSubmitted: (_) => _addTypedTime(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule_rounded),
            label: const Text('选择时间'),
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
  const _SheetTitle({required this.title, this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: '关闭',
          ),
      ],
    );
  }
}

class _FundCreateDraft {
  const _FundCreateDraft({
    required this.fund,
    required this.shares,
    required this.costNav,
    required this.amount,
    required this.fee,
    required this.autoNav,
    required this.tradeDate,
    required this.operationDate,
    required this.operationAfterCutoff,
    required this.note,
  });

  final FundSearchResult fund;
  final double shares;
  final double costNav;
  final double amount;
  final double fee;
  final bool autoNav;
  final DateTime tradeDate;
  final DateTime operationDate;
  final bool operationAfterCutoff;
  final String note;
}

class _FundCreateValues {
  const _FundCreateValues({
    required this.shares,
    required this.costNav,
    required this.fee,
    required this.amount,
    required this.holdingProfit,
  });

  final double shares;
  final double costNav;
  final double fee;
  final double amount;
  final double? holdingProfit;
}

class _FundHoldingSyncValues {
  const _FundHoldingSyncValues({
    required this.amount,
    required this.holdingProfit,
    required this.shares,
    required this.costNav,
  });

  final double amount;
  final double holdingProfit;
  final double shares;
  final double costNav;
}

class _FundTradeValues {
  const _FundTradeValues({
    required this.shares,
    required this.nav,
    required this.amount,
    required this.fee,
    required this.feeRate,
  });

  final double shares;
  final double nav;
  final double amount;
  final double fee;
  final double feeRate;
}

class _FundTradeTimeSelection {
  const _FundTradeTimeSelection({
    required this.date,
    required this.afterCutoff,
  });

  factory _FundTradeTimeSelection.initial() {
    final now = DateTime.now();
    return _FundTradeTimeSelection(
      date: DateTime(now.year, now.month, now.day),
      afterCutoff: now.hour >= 15,
    );
  }

  final DateTime date;
  final bool afterCutoff;

  DateTime get confirmDate {
    final base = DateTime(date.year, date.month, date.day);
    return afterCutoff ? base.add(const Duration(days: 1)) : base;
  }

  String get cutoffLabel => afterCutoff ? '下午3点后' : '下午3点前';
}

Future<_FundTradeTimeSelection?> _showFundTradeTimePicker({
  required BuildContext context,
  required String title,
  required _FundTradeTimeSelection initial,
}) {
  var selection = initial;
  return showModalBottomSheet<_FundTradeTimeSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: cardColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selection.date,
              firstDate: DateTime(2010),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked == null) return;
            setSheetState(() {
              selection = _FundTradeTimeSelection(
                date: DateTime(picked.year, picked.month, picked.day),
                afterCutoff: selection.afterCutoff,
              );
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetTitle(title: title),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(_dateLabel(selection.date)),
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('下午3点前')),
                    ButtonSegment(value: true, label: Text('下午3点后')),
                  ],
                  selected: {selection.afterCutoff},
                  onSelectionChanged: (value) {
                    setSheetState(() {
                      selection = _FundTradeTimeSelection(
                        date: selection.date,
                        afterCutoff: value.first,
                      );
                    });
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  '预计确认：${_dateOnlyText(selection.confirmDate)}，后端会按净值交易日校准',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondaryTextColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(selection),
                        child: const Text('确认'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
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

String _fundRecommendationLabel(FundGridRecommendation recommendation) {
  return recommendation.isBuy ? '下跌提醒' : '上涨提醒';
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month月$day日';
}

String _dateOnlyText(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

List<String> _normalizeReminderTimes(List<String> values) {
  final normalized =
      values.map(_normalizeReminderTime).whereType<String>().toSet().toList()
        ..sort();
  return normalized.isEmpty ? ['14:30'] : normalized;
}

String? _normalizeReminderTime(String value) {
  final match = RegExp(r'^(\d{1,2})[:：](\d{1,2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return _formatReminderTime(hour, minute);
}

String _formatReminderTime(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
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
