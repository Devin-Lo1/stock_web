from .base import BacktestStrategy
from .ma_cross import MaCrossStrategy
from .rsi_reversal import RsiReversalStrategy


_STRATEGIES: dict[str, BacktestStrategy] = {
    MaCrossStrategy.code: MaCrossStrategy(),
    RsiReversalStrategy.code: RsiReversalStrategy(),
}


def get_strategy(strategy_code: str) -> BacktestStrategy | None:
    return _STRATEGIES.get(strategy_code)
