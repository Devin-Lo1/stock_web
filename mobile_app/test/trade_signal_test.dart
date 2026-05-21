import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/models/trade_signal.dart';

void main() {
  test('TradeSignal parses backend strategy event without UI dependencies', () {
    final signal = TradeSignal.fromSignalEvent({
      'id': 'event-1',
      'code': 'US.MU',
      'signal_type': 'price_break_ma_sell',
      'level': 'important',
      'title': '美光科技触发价格跌破均线观察',
      'message': '收盘价跌破 MA5',
      'trigger_value': 681.54,
      'threshold_value': 750.48,
      'triggered_at': '2026-05-18T00:00:00Z',
      'payload': {
        'source_category': 'strategy',
        'stock_name': '美光科技',
        'strategy_code': 'price_break_ma',
        'strategy_name': 'Price Break MA',
        'condition_label': '收盘价跌破 MA5',
        'push_candidate': true,
      },
    });

    expect(signal.id, 'event-1');
    expect(signal.code, 'US.MU');
    expect(signal.signalType, 'price_break_ma_sell');
    expect(signal.strategyCode, 'price_break_ma');
    expect(signal.stock, '美光科技 US.MU');
    expect(signal.time, '2026/05/18');
    expect(signal.level, '高');
    expect(signal.tone, SignalTone.negative);
    expect(signal.category, SignalCategory.strategy);
    expect(signal.pushCandidate, isTrue);
  });

  test('TradeSignal classifies system events separately', () {
    final signal = TradeSignal.fromSignalEvent({
      'code': 'TEST',
      'signal_type': 'notification_test',
      'level': 'info',
      'read_status': 'ignored',
      'title': '测试提醒',
      'message': '通知链路测试',
      'triggered_at': '2026-05-20T00:00:00Z',
      'payload': {'source_category': 'system'},
    });

    expect(signal.tone, SignalTone.info);
    expect(signal.readStatus, 'ignored');
    expect(signal.category, SignalCategory.ignored);
  });
}
