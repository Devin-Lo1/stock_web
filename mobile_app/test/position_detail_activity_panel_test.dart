import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/models/notification_models.dart';
import 'package:stock_mobile/models/strategy_monitor.dart';
import 'package:stock_mobile/models/trade_signal.dart';
import 'package:stock_mobile/widgets/position/position_detail_activity_panel.dart';

void main() {
  testWidgets('PositionDetailActivityPanel renders activity rows and action', (
    tester,
  ) async {
    var openedMonitor = false;
    StrategyMonitor? enabledMonitor;
    bool? enabledValue;
    StrategyMonitor? pushMonitor;
    bool? pushValue;
    StrategyMonitor? deletedMonitor;
    TradeSignal? ignoredSignal;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PositionDetailActivityPanel(
            monitors: [
              StrategyMonitor(
                id: 'monitor-1',
                positionId: 'position-1',
                market: 'HK',
                code: 'HK.00700',
                name: '腾讯控股',
                strategyCode: 'price_break_ma',
                strategyName: 'Price Break MA',
                parameters: const {'ma_window': 5},
                period: 'day',
                scanIntervalMinutes: 15,
                cooldownMinutes: 120,
                enabled: true,
                pushCandidate: true,
                sourceBacktestRunId: null,
                lastScannedAt: DateTime.utc(2026, 5, 21, 1),
                lastTriggeredAt: DateTime.utc(2026, 5, 21, 2),
                lastSignalEventId: 'signal-1',
              ),
            ],
            signals: const [
              TradeSignal(
                id: 'signal-1',
                code: 'HK.00700',
                type: '腾讯控股触发Price Break MA观察',
                stock: '腾讯控股 HK.00700',
                time: '2026/05/21',
                level: '高',
                conditionLabel: '收盘价跌破 MA5',
                pushCandidate: true,
              ),
            ],
            pushRecords: [
              PushRecord(
                id: 'push-1',
                signalEventId: 'signal-1',
                deviceId: 'device-1',
                status: 'sent',
                provider: 'local',
                errorMessage: '',
                attemptCount: 1,
                sentAt: DateTime.utc(2026, 5, 21, 3),
                createdAt: DateTime.utc(2026, 5, 21, 3),
              ),
            ],
            isLoading: false,
            error: null,
            updatingMonitorIds: const {},
            onRetry: () {},
            onMonitorEnabledChanged: (monitor, enabled) {
              enabledMonitor = monitor;
              enabledValue = enabled;
            },
            onMonitorPushChanged: (monitor, pushCandidate) {
              pushMonitor = monitor;
              pushValue = pushCandidate;
            },
            onDeleteMonitor: (monitor) => deletedMonitor = monitor,
            onIgnoreSignal: (signal) => ignoredSignal = signal,
            onOpenStrategyMonitor: () => openedMonitor = true,
          ),
        ),
      ),
    );

    expect(find.text('单股监控与信号'), findsOneWidget);
    expect(find.text('策略监控'), findsOneWidget);
    expect(find.text('Price Break MA（价格跌破/站回均线）'), findsOneWidget);
    expect(find.text('历史信号'), findsOneWidget);
    expect(find.text('收盘价跌破 MA5'), findsOneWidget);
    expect(find.text('推送记录'), findsOneWidget);
    expect(find.text('已发送'), findsOneWidget);

    await tester.tap(find.byTooltip('停用监控'));
    expect(enabledMonitor?.id, 'monitor-1');
    expect(enabledValue, isFalse);

    await tester.tap(find.byTooltip('关闭推送'));
    expect(pushMonitor?.id, 'monitor-1');
    expect(pushValue, isFalse);

    await tester.tap(find.byTooltip('删除监控'));
    expect(deletedMonitor?.id, 'monitor-1');

    await tester.tap(find.text('创建监控'));

    expect(openedMonitor, isTrue);

    await tester.tap(find.byTooltip('忽略信号'));

    expect(ignoredSignal?.id, 'signal-1');
  });
}
