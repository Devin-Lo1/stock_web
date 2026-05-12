class StrategySettings {
  const StrategySettings({
    required this.takeProfitPercent,
    required this.stopLossPercent,
    required this.dailySurgePercent,
    required this.dailyDropPercent,
  });

  static const defaults = StrategySettings(
    takeProfitPercent: 5,
    stopLossPercent: -5,
    dailySurgePercent: 5,
    dailyDropPercent: -5,
  );

  final double takeProfitPercent;
  final double stopLossPercent;
  final double dailySurgePercent;
  final double dailyDropPercent;
}
