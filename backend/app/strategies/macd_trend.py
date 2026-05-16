from ..schemas import Candle
from .base import StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .factors import macd


class MacdTrendStrategy:
    code = "macd_trend"

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        fast_window, slow_window, signal_window = _read_parameters(parameters)
        return slow_window + signal_window

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        fast_window, slow_window, signal_window = _read_parameters(parameters)
        closes = [candle.close for candle in candles]
        _, _, histogram = macd(closes, fast_window, slow_window, signal_window)
        signals: list[StrategySignal] = []

        for index in range(slow_window + signal_window, len(candles)):
            previous = histogram[index - 1]
            current = histogram[index]
            if previous is None or current is None:
                continue
            if previous <= 0 < current:
                signals.append(StrategySignal(index=index, side="buy"))
            elif previous >= 0 > current:
                signals.append(StrategySignal(index=index, side="sell"))

        return StrategyEvaluation(
            warmup=slow_window + signal_window - 1,
            signals=signals,
        )


def _read_parameters(parameters: dict[str, object]) -> tuple[int, int, int]:
    fast_window = int(parameters.get("fast_window", 12))
    slow_window = int(parameters.get("slow_window", 26))
    signal_window = int(parameters.get("signal_window", 9))
    if (
        fast_window <= 0
        or slow_window <= 0
        or signal_window <= 0
        or fast_window >= slow_window
    ):
        raise StrategyConfigurationError("invalid_macd_parameters")
    return fast_window, slow_window, signal_window
