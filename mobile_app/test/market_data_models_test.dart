import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/models/candle.dart';
import 'package:stock_mobile/models/quote_snapshot.dart';
import 'package:stock_mobile/widgets/chart/kline_chart_values.dart';

void main() {
  test('QuoteSnapshot parses backend style json', () {
    final quote = QuoteSnapshot.fromJson({
      'code': 'HK.00700',
      'market': 'HK',
      'currency': 'HKD',
      'current_price': '382.4',
      'previous_close': 375.0,
      'open': 376.2,
      'high': 386.0,
      'low': 374.8,
      'volume': 12000000,
      'turnover': 4500000000,
      'change': 7.4,
      'change_rate': 1.97,
      'quote_time': '2026-05-11T10:30:00',
    });

    expect(quote.code, 'HK.00700');
    expect(quote.currentPrice, 382.4);
    expect(quote.previousClose, 375.0);
    expect(quote.quoteTime, DateTime(2026, 5, 11, 10, 30));
  });

  test('Candle parses and serializes kline values', () {
    final candle = Candle.fromJson({
      'code': 'US.AAPL',
      'market': 'US',
      'period': 'day',
      'time': '2026-05-11T00:00:00',
      'open': '180.1',
      'high': 184.0,
      'low': 179.5,
      'close': 183.2,
      'volume': 82000000,
      'turnover': 15000000000,
    });

    expect(candle.code, 'US.AAPL');
    expect(candle.period, 'day');
    expect(candle.open, 180.1);
    expect(candle.toJson()['close'], 183.2);
  });

  test('volume moving average uses candle volume values', () {
    final candles = [
      for (var index = 1; index <= 5; index++)
        Candle(
          code: 'HK.00700',
          market: 'HK',
          period: 'day',
          time: DateTime(2026, 5, index),
          open: 10,
          high: 11,
          low: 9,
          close: 10.5,
          volume: index * 1000,
          turnover: index * 10000,
        ),
    ];

    expect(volumeMovingAverageAt(candles, 2, 3), 2000);
    expect(volumeMaValuesAt(candles, 4)[5], 3000);
  });
}
