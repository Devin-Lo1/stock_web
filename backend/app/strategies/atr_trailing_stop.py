from ..schemas import Candle
from .base import StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .factors import average_true_range, moving_average


class AtrTrailingStopStrategy:
    code = "atr_trailing_stop"

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        atr_window, _, entry_ma_window, _ = _read_parameters(parameters)
        return max(atr_window, entry_ma_window) + 1

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        atr_window, atr_multiplier, entry_ma_window, direction = _read_parameters(
            parameters,
        )
        highs = [candle.high for candle in candles]
        lows = [candle.low for candle in candles]
        closes = [candle.close for candle in candles]
        atr_values = average_true_range(highs, lows, closes, atr_window)
        entry_ma = moving_average(closes, entry_ma_window)
        start_index = max(atr_window, entry_ma_window)
        signals: list[StrategySignal] = []
        peak_close: float | None = None

        for index in range(start_index, len(candles)):
            current_atr = atr_values[index]
            previous_atr = atr_values[index - 1]
            current_ma = entry_ma[index]
            previous_ma = entry_ma[index - 1]
            if (
                current_atr is None
                or previous_atr is None
                or current_ma is None
                or previous_ma is None
            ):
                continue

            if peak_close is None:
                peak_close = closes[index - 1]
            peak_close = max(peak_close, closes[index - 1])
            previous_stop = peak_close - previous_atr * atr_multiplier
            peak_close = max(peak_close, closes[index])
            current_stop = peak_close - current_atr * atr_multiplier

            if (
                direction in {"reentry_and_stop", "both"}
                and closes[index - 1] <= previous_ma
                and closes[index] > current_ma
            ):
                signals.append(StrategySignal(index=index, side="buy"))
                peak_close = closes[index]
            elif (
                direction in {"stop_only", "reentry_and_stop", "both"}
                and closes[index - 1] >= previous_stop
                and closes[index] < current_stop
            ):
                signals.append(StrategySignal(index=index, side="sell"))
                peak_close = closes[index]

        return StrategyEvaluation(warmup=start_index - 1, signals=signals)


def _read_parameters(parameters: dict[str, object]) -> tuple[int, float, int, str]:
    atr_window = int(parameters.get("atr_window", 14))
    atr_multiplier = float(parameters.get("atr_multiplier", 3))
    entry_ma_window = int(parameters.get("entry_ma_window", 20))
    direction = str(parameters.get("direction", "stop_only")).strip()
    if (
        atr_window <= 1
        or atr_multiplier <= 0
        or entry_ma_window <= 1
        or direction not in {"stop_only", "reentry_and_stop", "both"}
    ):
        raise StrategyConfigurationError("invalid_atr_trailing_stop_parameters")
    return atr_window, atr_multiplier, entry_ma_window, direction
