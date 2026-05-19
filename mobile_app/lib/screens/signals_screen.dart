import 'package:flutter/material.dart';

import '../models/trade_signal.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_title.dart';
import '../widgets/signal/signal_tile.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({
    super.key,
    required this.signals,
    required this.isLoading,
    required this.isScanning,
    required this.usingBackendSignals,
    required this.onRefresh,
    required this.onScan,
  });

  final List<TradeSignal> signals;
  final bool isLoading;
  final bool isScanning;
  final bool usingBackendSignals;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onScan;

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
