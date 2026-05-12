import 'package:flutter/material.dart';

import '../models/trade_signal.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_title.dart';
import '../widgets/signal/signal_tile.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({
    super.key,
    required this.signals,
    required this.onRefresh,
  });

  final List<TradeSignal> signals;
  final Future<void> Function() onRefresh;

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
            subtitle: '${signals.length} 条本地策略信号 · 强信号优先提醒',
          ),
          const SizedBox(height: 14),
          if (signals.isEmpty)
            const ReadOnlyEmptyState(
              icon: Icons.notifications_none_rounded,
              title: '暂无信号',
              subtitle: '当持仓触发止盈、止损或当日异动时，这里会自动展示。',
            )
          else
            ...signals.map(
              (signal) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SignalTile(signal: signal),
              ),
            ),
        ],
      ),
    );
  }
}
