from .base import BacktestStrategy
from .atr_trailing_stop import AtrTrailingStopStrategy
from .macd_trend import MacdTrendStrategy
from .ma_breakdown_stop import MaBreakdownStopStrategy
from .ma_cross import MaCrossStrategy
from .composite_factor import CompositeFactorStrategy
from .price_break_ma import PriceBreakMaStrategy
from .rsi_oversold_rebound import RsiOversoldReboundStrategy
from .rsi_reversal import RsiReversalStrategy
from .trend_score import TrendScoreStrategy
from .volume_breakout import VolumeBreakoutStrategy


_STRATEGIES: dict[str, BacktestStrategy] = {
    MaCrossStrategy.code: MaCrossStrategy(),
    MaBreakdownStopStrategy.code: MaBreakdownStopStrategy(),
    AtrTrailingStopStrategy.code: AtrTrailingStopStrategy(),
    CompositeFactorStrategy.code: CompositeFactorStrategy(),
    MacdTrendStrategy.code: MacdTrendStrategy(),
    PriceBreakMaStrategy.code: PriceBreakMaStrategy(),
    RsiOversoldReboundStrategy.code: RsiOversoldReboundStrategy(),
    RsiReversalStrategy.code: RsiReversalStrategy(),
    TrendScoreStrategy.code: TrendScoreStrategy(),
    VolumeBreakoutStrategy.code: VolumeBreakoutStrategy(),
}


def get_strategy(strategy_code: str) -> BacktestStrategy | None:
    return _STRATEGIES.get(strategy_code)
