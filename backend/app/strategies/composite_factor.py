from ..schemas import Candle
from .atr_trailing_stop import AtrTrailingStopStrategy
from .base import BacktestStrategy, StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .macd_trend import MacdTrendStrategy
from .ma_breakdown_stop import MaBreakdownStopStrategy
from .ma_cross import MaCrossStrategy
from .price_break_ma import PriceBreakMaStrategy
from .rsi_oversold_rebound import RsiOversoldReboundStrategy
from .rsi_reversal import RsiReversalStrategy
from .trend_score import TrendScoreStrategy
from .volume_breakout import VolumeBreakoutStrategy


DEFAULT_FACTOR_PARAMETERS: dict[str, dict[str, object]] = {
    "ma_cross": {
        "short_window": 5,
        "long_window": 20,
    },
    "rsi_reversal": {
        "rsi_window": 14,
        "oversold": 30,
        "overbought": 70,
    },
    "macd_trend": {
        "fast_window": 12,
        "slow_window": 26,
        "signal_window": 9,
    },
    "price_break_ma": {
        "ma_window": 10,
        "direction": "both",
    },
    "volume_breakout": {
        "lookback_window": 20,
        "volume_window": 20,
        "volume_multiplier": 1.5,
        "direction": "both",
    },
    "ma_breakdown_stop": {
        "ma_window": 20,
        "stop_buffer_pct": 0,
        "direction": "break_down",
    },
    "atr_trailing_stop": {
        "atr_window": 14,
        "atr_multiplier": 3,
        "entry_ma_window": 20,
        "direction": "stop_only",
    },
    "rsi_oversold_rebound": {
        "rsi_window": 14,
        "oversold": 30,
        "overbought": 70,
        "exit_mode": "overbought",
    },
    "trend_score": {
        "ma_window": 20,
        "momentum_window": 20,
        "volume_window": 20,
        "buy_score": 3,
        "sell_score": 1,
    },
}


class CompositeFactorStrategy:
    code = "composite_factor"

    def __init__(self) -> None:
        self._strategies: dict[str, BacktestStrategy] = {
            "ma_cross": MaCrossStrategy(),
            "rsi_reversal": RsiReversalStrategy(),
            "macd_trend": MacdTrendStrategy(),
            "price_break_ma": PriceBreakMaStrategy(),
            "volume_breakout": VolumeBreakoutStrategy(),
            "ma_breakdown_stop": MaBreakdownStopStrategy(),
            "atr_trailing_stop": AtrTrailingStopStrategy(),
            "rsi_oversold_rebound": RsiOversoldReboundStrategy(),
            "trend_score": TrendScoreStrategy(),
        }

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        factor_codes, _, _, factor_parameters = _read_parameters(parameters)
        return max(
            self._strategies[code].minimum_candles(factor_parameters[code])
            for code in factor_codes
        )

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        factor_codes, mode, confirm_window, factor_parameters = _read_parameters(
            parameters,
        )
        evaluations = {
            code: self._strategies[code].evaluate(candles, factor_parameters[code])
            for code in factor_codes
        }
        warmup = max(evaluation.warmup for evaluation in evaluations.values())
        signals_by_code = {
            code: {
                "buy": {signal.index for signal in evaluation.signals if signal.side == "buy"},
                "sell": {signal.index for signal in evaluation.signals if signal.side == "sell"},
            }
            for code, evaluation in evaluations.items()
        }
        signals: list[StrategySignal] = []

        for index in range(warmup + 1, len(candles)):
            for side in ("buy", "sell"):
                current = _is_confirmed(
                    signals_by_code,
                    factor_codes,
                    index,
                    side,
                    mode,
                    confirm_window,
                )
                previous = _is_confirmed(
                    signals_by_code,
                    factor_codes,
                    index - 1,
                    side,
                    mode,
                    confirm_window,
                )
                if current and not previous:
                    signals.append(StrategySignal(index=index, side=side))

        return StrategyEvaluation(warmup=warmup, signals=signals)


def _is_confirmed(
    signals_by_code: dict[str, dict[str, set[int]]],
    factor_codes: list[str],
    index: int,
    side: str,
    mode: str,
    confirm_window: int,
) -> bool:
    start = max(0, index - confirm_window)
    confirmations = [
        any(signal_index in signals_by_code[code][side] for signal_index in range(start, index + 1))
        for code in factor_codes
    ]
    if mode == "any":
        return any(confirmations)
    return all(confirmations)


def _read_parameters(
    parameters: dict[str, object],
) -> tuple[list[str], str, int, dict[str, dict[str, object]]]:
    factor_codes = _read_factor_codes(parameters.get("factor_codes"))
    mode = str(parameters.get("mode", "all")).strip()
    confirm_window = int(parameters.get("confirm_window", 3))
    if len(factor_codes) < 2 or mode not in {"all", "any"} or confirm_window < 0:
        raise StrategyConfigurationError("invalid_composite_factor_parameters")

    overrides = parameters.get("factor_parameters")
    factor_parameters: dict[str, dict[str, object]] = {}
    for code in factor_codes:
        merged = dict(DEFAULT_FACTOR_PARAMETERS[code])
        if isinstance(overrides, dict) and isinstance(overrides.get(code), dict):
            merged.update(overrides[code])
        factor_parameters[code] = merged
    return factor_codes, mode, confirm_window, factor_parameters


def _read_factor_codes(value: object) -> list[str]:
    if isinstance(value, str):
        raw_codes = [item.strip() for item in value.split(",")]
    elif isinstance(value, list):
        raw_codes = [str(item).strip() for item in value]
    else:
        raw_codes = ["volume_breakout", "trend_score"]
    result: list[str] = []
    for code in raw_codes:
        if not code or code not in DEFAULT_FACTOR_PARAMETERS or code in result:
            continue
        result.append(code)
    return result
