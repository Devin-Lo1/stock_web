from ..schemas import Candle
from .base import StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .factors import moving_average


class MaCrossStrategy:
    code = "ma_cross"

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        _, long_window = _read_windows(parameters)
        return long_window

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        short_window, long_window = _read_windows(parameters)
        closes = [candle.close for candle in candles]
        short_ma = moving_average(closes, short_window)
        long_ma = moving_average(closes, long_window)
        signals: list[StrategySignal] = []

        for index in range(long_window, len(candles)):
            previous_short = short_ma[index - 1]
            previous_long = long_ma[index - 1]
            current_short = short_ma[index]
            current_long = long_ma[index]
            if (
                previous_short is None
                or previous_long is None
                or current_short is None
                or current_long is None
            ):
                continue
            if previous_short <= previous_long and current_short > current_long:
                signals.append(StrategySignal(index=index, side="buy"))
            elif previous_short >= previous_long and current_short < current_long:
                signals.append(StrategySignal(index=index, side="sell"))

        return StrategyEvaluation(warmup=long_window - 1, signals=signals)


def _read_windows(parameters: dict[str, object]) -> tuple[int, int]:
    short_window = int(parameters.get("short_window", 5))
    long_window = int(parameters.get("long_window", 20))
    if short_window <= 0 or long_window <= 0 or short_window >= long_window:
        raise StrategyConfigurationError("invalid_ma_parameters")
    return short_window, long_window
