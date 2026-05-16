from .base import BacktestStrategy
from .macd_trend import MacdTrendStrategy
from .ma_cross import MaCrossStrategy
from .rsi_reversal import RsiReversalStrategy


_STRATEGIES: dict[str, BacktestStrategy] = {
    MaCrossStrategy.code: MaCrossStrategy(),
    MacdTrendStrategy.code: MacdTrendStrategy(),
    RsiReversalStrategy.code: RsiReversalStrategy(),
}


def get_strategy(strategy_code: str) -> BacktestStrategy | None:
    return _STRATEGIES.get(strategy_code)
