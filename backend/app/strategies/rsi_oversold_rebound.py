from ..schemas import Candle
from .base import StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .factors import relative_strength_index


class RsiOversoldReboundStrategy:
    code = "rsi_oversold_rebound"

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        window, _, _, _ = _read_parameters(parameters)
        return window + 1

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        window, oversold, overbought, exit_enabled = _read_parameters(parameters)
        closes = [candle.close for candle in candles]
        rsi_values = relative_strength_index(closes, window)
        signals: list[StrategySignal] = []

        for index in range(window + 1, len(candles)):
            previous_rsi = rsi_values[index - 1]
            current_rsi = rsi_values[index]
            if previous_rsi is None or current_rsi is None:
                continue
            if previous_rsi < oversold <= current_rsi:
                signals.append(StrategySignal(index=index, side="buy"))
            elif exit_enabled and previous_rsi > overbought >= current_rsi:
                signals.append(StrategySignal(index=index, side="sell"))

        return StrategyEvaluation(warmup=window, signals=signals)


def _read_parameters(parameters: dict[str, object]) -> tuple[int, float, float, bool]:
    window = int(parameters.get("rsi_window", 14))
    oversold = float(parameters.get("oversold", 30))
    overbought = float(parameters.get("overbought", 70))
    exit_mode = str(parameters.get("exit_mode", "overbought")).strip()
    if (
        window <= 1
        or not 0 < oversold < overbought < 100
        or exit_mode not in {"none", "overbought"}
    ):
        raise StrategyConfigurationError("invalid_rsi_oversold_rebound_parameters")
    return window, oversold, overbought, exit_mode == "overbought"
