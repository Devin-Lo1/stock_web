import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/models/personalized_strategy.dart';

void main() {
  test('PersonalizedStrategyDecision parses replay metadata', () {
    final decision = PersonalizedStrategyDecision.fromJson({
      'kind': 'previous_close',
      'title': 'previous',
      'action': 'hold_long',
      'action_label': 'hold',
      'current_position': 'long',
      'latest_date': '2026-06-05',
      'latest_price': 394.39,
      'signal_date': '2026-06-01',
      'reason': 'position_still_long',
      'detail': {
        'position_entry_date': '2026-06-01',
        'position_entry_price': 465.96,
        'position_hold_days': 4,
        'last_event': {
          'date': '2026-06-01',
          'action': 'long_entry',
          'price': 465.96,
          'reason': 'channel_breakout_with_filters',
        },
      },
    });

    expect(decision.positionEntryDate, DateTime(2026, 6, 1));
    expect(decision.positionEntryPrice, 465.96);
    expect(decision.positionHoldDays, 4);
    expect(decision.lastEvent?.date, DateTime(2026, 6, 1));
    expect(decision.lastEvent?.action, 'long_entry');
    expect(decision.lastEvent?.price, 465.96);
    expect(decision.lastEvent?.reason, 'channel_breakout_with_filters');
  });
}
