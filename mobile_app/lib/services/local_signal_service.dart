import 'package:flutter/material.dart';

import '../models/stock_position.dart';
import '../models/strategy_settings.dart';
import '../models/trade_signal.dart';
import '../utils/formatters.dart';

List<TradeSignal> buildSignals(
  List<StockPosition> positions,
  StrategySettings settings,
) {
  final signals = <TradeSignal>[];
  for (final position in positions) {
    if (position.profitRate >= settings.takeProfitPercent) {
      signals.add(
        TradeSignal(
          type: '止盈观察',
          stock: '${position.name} ${position.code}',
          time: '持有收益 ${formatPercent(position.profitRate)}',
          level: '高',
          color: const Color(0xFF12B886),
        ),
      );
    }
    if (position.profitRate <= settings.stopLossPercent) {
      signals.add(
        TradeSignal(
          type: '止损观察',
          stock: '${position.name} ${position.code}',
          time: '持有收益 ${formatPercent(position.profitRate)}',
          level: '高',
          color: const Color(0xFFFF3B45),
        ),
      );
    }
    if (position.dailyProfitRate >= settings.dailySurgePercent) {
      signals.add(
        TradeSignal(
          type: '上涨异动',
          stock: '${position.name} ${position.code}',
          time: '当日 ${formatPercent(position.dailyProfitRate)}',
          level: '中',
          color: const Color(0xFF12B886),
        ),
      );
    }
    if (position.dailyProfitRate <= settings.dailyDropPercent) {
      signals.add(
        TradeSignal(
          type: '下跌异动',
          stock: '${position.name} ${position.code}',
          time: '当日 ${formatPercent(position.dailyProfitRate)}',
          level: '中',
          color: const Color(0xFFFF3B45),
        ),
      );
    }
  }
  return signals;
}
