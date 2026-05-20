import 'dart:async';

import 'package:flutter/material.dart';

import '../models/trade_signal.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_title.dart';
import '../widgets/signal/signal_presentation.dart';
import '../widgets/signal/signal_tile.dart';
import '../utils/theme_helpers.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({
    super.key,
    required this.signals,
    required this.isLoading,
    required this.isScanning,
    required this.usingBackendSignals,
    required this.onRefresh,
    required this.onScan,
    this.onLoadCategory,
  });

  final List<TradeSignal> signals;
  final bool isLoading;
  final bool isScanning;
  final bool usingBackendSignals;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onScan;
  final Future<List<TradeSignal>> Function(SignalCategory category)?
  onLoadCategory;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        children: [
          PageTitle(
            title: '信号',
            subtitle: usingBackendSignals
                ? '${signals.length} 条后端策略信号 · 已落库'
                : '${signals.length} 条本地风控信号 · 待扫描',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isScanning ? null : onScan,
                  icon: isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar_rounded, size: 18),
                  label: Text(isScanning ? '扫描中' : '扫描信号'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: '刷新',
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (signals.isEmpty)
            const ReadOnlyEmptyState(
              icon: Icons.notifications_none_rounded,
              title: '暂无信号',
              subtitle: '扫描后，触发条件的策略信号会显示在这里。',
            )
          else
            ...SignalCategory.values.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SignalCategoryTile(
                  category: category,
                  signals: _signalsForCategory(category),
                  onLoadCategory: onLoadCategory,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<TradeSignal> _signalsForCategory(SignalCategory category) {
    if (category == SignalCategory.important) {
      return signals.where((signal) => signal.level == '高').toList();
    }
    if (category == SignalCategory.ignored) {
      return signals.where((signal) => signal.readStatus == 'ignored').toList();
    }
    return signals.where((signal) => signal.category == category).toList();
  }
}

class _SignalCategoryTile extends StatelessWidget {
  const _SignalCategoryTile({
    required this.category,
    required this.signals,
    required this.onLoadCategory,
  });

  final SignalCategory category;
  final List<TradeSignal> signals;
  final Future<List<TradeSignal>> Function(SignalCategory category)?
  onLoadCategory;

  @override
  Widget build(BuildContext context) {
    final latest = signals.isEmpty ? null : signals.first;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: signals.isEmpty && onLoadCategory == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => SignalCategoryScreen(
                    category: category,
                    signals: signals,
                    onLoadSignals: onLoadCategory,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.title,
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${signals.length}',
                        style: TextStyle(
                          color: category.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latest == null
                        ? category.subtitle
                        : '${latest.stock} · ${latest.conditionLabel.isEmpty ? latest.type : latest.conditionLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: signals.isEmpty ? mutedIconColor(context) : category.color,
            ),
          ],
        ),
      ),
    );
  }
}

class SignalCategoryScreen extends StatelessWidget {
  const SignalCategoryScreen({
    super.key,
    required this.category,
    required this.signals,
    this.onLoadSignals,
  });

  final SignalCategory category;
  final List<TradeSignal> signals;
  final Future<List<TradeSignal>> Function(SignalCategory category)?
  onLoadSignals;

  @override
  Widget build(BuildContext context) {
    return _SignalCategoryScaffold(
      category: category,
      initialSignals: signals,
      onLoadSignals: onLoadSignals,
    );
  }
}

class _SignalCategoryScaffold extends StatefulWidget {
  const _SignalCategoryScaffold({
    required this.category,
    required this.initialSignals,
    required this.onLoadSignals,
  });

  final SignalCategory category;
  final List<TradeSignal> initialSignals;
  final Future<List<TradeSignal>> Function(SignalCategory category)?
  onLoadSignals;

  @override
  State<_SignalCategoryScaffold> createState() =>
      _SignalCategoryScaffoldState();
}

class _SignalCategoryScaffoldState extends State<_SignalCategoryScaffold> {
  late List<TradeSignal> _signals = widget.initialSignals;
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.onLoadSignals != null) {
      unawaited(_loadSignals());
    }
  }

  Future<void> _loadSignals() async {
    final loader = widget.onLoadSignals;
    if (loader == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final signals = await loader(widget.category);
      if (!mounted) return;
      setState(() => _signals = signals);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor(context),
      body: SafeArea(
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
                    title: widget.category.title,
                    subtitle:
                        '${_signals.length} 条信号 · ${widget.category.subtitle}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (_error != null)
              EmptyState(
                icon: Icons.error_outline_rounded,
                title: '加载失败',
                subtitle: '请刷新后重试。',
                actionLabel: '重试',
                onAction: _loadSignals,
              )
            else if (_signals.isEmpty)
              const ReadOnlyEmptyState(
                icon: Icons.notifications_none_rounded,
                title: '暂无信号',
                subtitle: '该分类下暂时没有触发记录。',
              )
            else
              ..._signals.map(
                (signal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SignalTile(signal: signal),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
