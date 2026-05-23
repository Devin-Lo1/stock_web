import 'dart:async';

import 'package:flutter/material.dart';

import '../models/fund_models.dart';
import '../repositories/fund_repository.dart';
import '../utils/theme_helpers.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_title.dart';

class FundsScreen extends StatefulWidget {
  const FundsScreen({super.key, required this.repository});

  final FundRepository repository;

  @override
  State<FundsScreen> createState() => _FundsScreenState();
}

class _FundsScreenState extends State<FundsScreen> {
  List<FundPositionSummary> _summaries = const [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final summaries = await widget.repository.loadSummaries();
      if (!mounted) return;
      setState(() => _summaries = summaries);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showSnack('添加基金失败：$error');
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
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showSnack('交易记录失败：$error');
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
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showSnack('删除失败：$error');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final totalMarketValue = _summaries.fold<double>(
      0,
      (sum, item) => sum + item.marketValue,
    );
    final totalProfit = _summaries.fold<double>(
      0,
      (sum, item) => sum + item.totalProfit,
    );
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: PageTitle(
                      title: '基金',
                      subtitle:
                          '${_summaries.length} 只基金 · 总盈亏 ${_money(totalProfit)}',
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: '刷新',
                    onPressed: _isLoading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FundSummaryBand(
                marketValue: totalMarketValue,
                totalProfit: totalProfit,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _addFund,
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加场外基金'),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (_error != null)
                EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: '加载失败',
                  subtitle: '基金数据暂时不可用，请稍后刷新。',
                  actionLabel: '重试',
                  onAction: _load,
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
                ..._summaries.map(
                  (summary) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FundCard(
                      summary: summary,
                      onBuy: () => _trade(summary, 'buy'),
                      onSell: () => _trade(summary, 'sell'),
                      onDelete: () => _delete(summary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FundSummaryBand extends StatelessWidget {
  const _FundSummaryBand({
    required this.marketValue,
    required this.totalProfit,
  });

  final double marketValue;
  final double totalProfit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Metric(label: '基金市值', value: _money(marketValue)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Metric(
              label: '累计盈亏',
              value: _money(totalProfit),
              valueColor: _profitColor(totalProfit),
            ),
          ),
        ],
      ),
    );
  }
}

class _FundCard extends StatelessWidget {
  const _FundCard({
    required this.summary,
    required this.onBuy,
    required this.onSell,
    required this.onDelete,
  });

  final FundPositionSummary summary;
  final VoidCallback onBuy;
  final VoidCallback onSell;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final position = summary.position;
    final latest = summary.latestNav;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  position.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${position.fundCode} · ${position.fundType.isEmpty ? '场外基金' : position.fundType}',
            style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(label: '份额', value: position.shares.toStringAsFixed(2)),
              _InfoChip(
                label: '成本净值',
                value: position.avgCostNav.toStringAsFixed(4),
              ),
              _InfoChip(
                label: '最新净值',
                value: latest == null
                    ? '--'
                    : latest.unitNav.toStringAsFixed(4),
              ),
              _InfoChip(
                label: '日涨跌',
                value: latest == null ? '--' : _percent(latest.dailyGrowthRate),
                valueColor: latest == null
                    ? secondaryTextColor(context)
                    : _profitColor(latest.dailyGrowthRate),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(label: '市值', value: _money(summary.marketValue)),
              ),
              Expanded(
                child: _Metric(
                  label: '持有盈亏',
                  value:
                      '${_money(summary.holdingProfit)} / ${_percent(summary.holdingProfitRate)}',
                  valueColor: _profitColor(summary.holdingProfit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onBuy,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('买入'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSell,
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('卖出'),
                ),
              ),
            ],
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
      if (!mounted) return;
      setState(() => _results = results);
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
          Text(
            '添加场外基金',
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
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
      text: widget.summary.latestNav?.unitNav.toStringAsFixed(4) ?? '',
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
          Text(
            '${isBuy ? '买入' : '卖出'} ${widget.summary.position.name}',
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: secondaryTextColor(context), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? primaryTextColor(context),
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: softCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor(context)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: valueColor ?? primaryTextColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _money(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
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

Color _profitColor(double value) {
  if (value > 0) return const Color(0xFF20C997);
  if (value < 0) return const Color(0xFFFF4D67);
  return const Color(0xFF94A3B8);
}
