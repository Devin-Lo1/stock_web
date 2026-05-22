import 'package:flutter/material.dart';

import '../../models/trade_signal.dart';

extension SignalCategoryPresentation on SignalCategory {
  String get title {
    return switch (this) {
      SignalCategory.important => '重要信号',
      SignalCategory.strategy => '量化策略',
      SignalCategory.risk => '风控提醒',
      SignalCategory.system => '系统通知',
      SignalCategory.ignored => '已忽略',
    };
  }

  String get subtitle {
    return switch (this) {
      SignalCategory.important => '高优先级观察信号',
      SignalCategory.strategy => 'MA、RSI、MACD 等策略触发',
      SignalCategory.risk => '止盈、止损和当日异动',
      SignalCategory.system => '连接、推送和任务状态',
      SignalCategory.ignored => '手动忽略的信号记录',
    };
  }

  IconData get icon {
    return switch (this) {
      SignalCategory.important => Icons.priority_high_rounded,
      SignalCategory.strategy => Icons.science_rounded,
      SignalCategory.risk => Icons.shield_rounded,
      SignalCategory.system => Icons.settings_suggest_rounded,
      SignalCategory.ignored => Icons.visibility_off_rounded,
    };
  }

  Color get color {
    return switch (this) {
      SignalCategory.important => const Color(0xFFFF3B45),
      SignalCategory.strategy => const Color(0xFF6B7280),
      SignalCategory.risk => const Color(0xFFE6B450),
      SignalCategory.system => const Color(0xFF8B9CB3),
      SignalCategory.ignored => const Color(0xFF7C8798),
    };
  }
}

Color signalColor(TradeSignal signal) {
  return switch (signal.tone) {
    SignalTone.positive => const Color(0xFF12B886),
    SignalTone.negative => const Color(0xFFFF3B45),
    SignalTone.warning => const Color(0xFFE6B450),
    SignalTone.info => const Color(0xFF6B7280),
  };
}
