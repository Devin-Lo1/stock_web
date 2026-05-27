import 'package:flutter_test/flutter_test.dart';
import 'package:stock_mobile/models/backtest_models.dart';
import 'package:stock_mobile/models/app_enums.dart';
import 'package:stock_mobile/models/candle.dart';
import 'package:stock_mobile/models/capital_flow.dart';
import 'package:stock_mobile/models/quote_snapshot.dart';
import 'package:stock_mobile/models/stock_position.dart';
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
      'extended_session': 'after',
      'extended_price': 381.2,
      'extended_change': -1.2,
      'extended_change_rate': -0.31,
      'extended_volume': 12000,
      'extended_turnover': 4574400,
    });

    expect(quote.code, 'HK.00700');
    expect(quote.currentPrice, 382.4);
    expect(quote.previousClose, 375.0);
    expect(quote.quoteTime, DateTime(2026, 5, 11, 10, 30));
    expect(quote.extendedSession, 'after');
    expect(quote.extendedPrice, 381.2);
    expect(quote.extendedChangeRate, -0.31);
    expect(quote.hasExtendedSession, isTrue);
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

  test('CapitalFlowSnapshot parses fund flow values', () {
    final snapshot = CapitalFlowSnapshot.fromJson({
      'code': 'US.MU',
      'market': 'US',
      'currency': 'USD',
      'update_time': '2026-05-22T19:59:56',
      'total_inflow': 1000,
      'total_outflow': 800,
      'net_inflow': 200,
      'buckets': [
        {
          'bucket': 'big',
          'inflow': '300.5',
          'outflow': 100,
          'net_inflow': 200.5,
        },
      ],
      'points': [
        {
          'time': '2026-05-22T16:00:00',
          'net_inflow': 200,
          'super_net_inflow': 70,
          'big_net_inflow': 60,
          'mid_net_inflow': 50,
          'small_net_inflow': 20,
        },
      ],
    });

    expect(snapshot.code, 'US.MU');
    expect(snapshot.currency, 'USD');
    expect(snapshot.buckets.single.netInflow, 200.5);
    expect(snapshot.points.single.superNetInflow, 70);
  });

  test('StockPosition classifies A-share codes as CN market', () {
    expect(_position('SH.600519').market, MarketFilter.cn);
    expect(_position('SZ.000001').market, MarketFilter.cn);
    expect(_position('US.NVDA').market, MarketFilter.us);
    expect(_position('HK.00700').market, MarketFilter.hk);
  });

  test('BacktestBatchResult parses ranked run summaries', () {
    final result = BacktestBatchResult.fromJson({
      'total_count': 2,
      'completed_count': 1,
      'failed_count': 1,
      'results': [
        {
          'index': 0,
          'request': {
            'strategy_code': 'ma_cross',
            'stock_code': 'US.NVDA',
            'period': 'day',
            'start_date': '2025-01-01',
            'end_date': '2026-05-27',
            'initial_cash': 100000,
            'fee_rate': 0.0003,
            'slippage_rate': 0.0005,
            'parameters': {'short_window': 5, 'long_window': 20},
          },
          'run': {
            'id': 'run-1',
            'name': '',
            'strategy_code': 'ma_cross',
            'stock_code': 'US.NVDA',
            'period': 'day',
            'start_date': '2025-01-01',
            'end_date': '2026-05-27',
            'initial_cash': 100000,
            'fee_rate': 0.0003,
            'slippage_rate': 0.0005,
            'parameters': {'short_window': 5, 'long_window': 20},
            'status': 'completed',
            'summary': {'total_return': 0.18},
          },
        },
        {
          'index': 1,
          'request': {
            'strategy_code': 'ma_cross',
            'stock_code': 'US.AAPL',
            'period': 'day',
            'start_date': '2025-01-01',
            'end_date': '2026-05-27',
            'initial_cash': 100000,
            'fee_rate': 0.0003,
            'slippage_rate': 0.0005,
            'parameters': {'short_window': 8, 'long_window': 30},
          },
          'error': 'not enough candles',
        },
      ],
    });

    expect(result.totalCount, 2);
    expect(result.completedCount, 1);
    expect(result.results.first.run?.summaryDouble('total_return'), 0.18);
    expect(result.results.last.isFailed, isTrue);
  });

  test('VolumeProfileBacktestResult parses profile chart payload', () {
    final result = VolumeProfileBacktestResult.fromJson({
      'request': {
        'stock_code': 'US.TQQQ',
        'start_date': '2025-01-01',
        'end_date': '2026-05-27',
        'deviation_threshold': 0.5,
        'bucket_count': 250,
        'value_area_ratio': 0.68,
        'stop_loss_multiple': 1.0,
      },
      'summary': {'success_rate': 0.66, 'triggered_count': 12},
      'signals': [
        {
          'date': '2026-05-27',
          'profile_date': '2026-05-26',
          'direction': 'short',
          'open_price': 100.8,
          'target_price': 100.2,
          'stop_price': 101.4,
          'deviation': 0.42,
          'outcome': 'success',
          'outcome_time': '2026-05-27T10:05:00',
          'outcome_price': 100.2,
          'poc': 100.1,
          'vah': 100.2,
          'val': 98.8,
        },
      ],
      'chart_profile': {
        'date': '2026-05-26',
        'poc': 100.1,
        'vah': 100.2,
        'val': 98.8,
        'total_volume': 1200000,
        'bucket_count': 2,
        'value_area_ratio': 0.68,
        'buckets': [
          {
            'price_low': 98.8,
            'price_high': 99.5,
            'price_mid': 99.15,
            'volume': 300000,
            'volume_ratio': 0.25,
          },
        ],
      },
      'chart_candles': [
        {
          'code': 'US.TQQQ',
          'market': 'US',
          'period': '1m',
          'time': '2026-05-27T09:30:00',
          'open': 100.8,
          'high': 101.0,
          'low': 100.1,
          'close': 100.3,
          'volume': 12000,
          'turnover': 1200000,
        },
      ],
    });

    expect(result.request?.stockCode, 'US.TQQQ');
    expect(result.summaryDouble('success_rate'), 0.66);
    expect(result.summaryInt('triggered_count'), 12);
    expect(result.signals.single.isSuccess, isTrue);
    expect(result.chartProfile?.buckets.single.volumeRatio, 0.25);
    expect(result.chartCandles.single.period, '1m');
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

StockPosition _position(String code) {
  return StockPosition(
    name: 'Test',
    code: code,
    quantity: 1,
    costPrice: 10,
    currentPrice: 12,
    previousClose: 11,
    changeRate: 9.09,
    signal: 'ok',
  );
}
