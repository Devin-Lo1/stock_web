from ..schemas import Candle
from .base import StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .factors import moving_average, rolling_high, rolling_low


class VolumeBreakoutStrategy:
    code = "volume_breakout"

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        lookback_window, volume_window, _, _ = _read_parameters(parameters)
        return max(lookback_window, volume_window) + 1

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        lookback_window, volume_window, volume_multiplier, direction = _read_parameters(
            parameters,
        )
        closes = [candle.close for candle in candles]
        volumes = [candle.volume for candle in candles]
        previous_highs = rolling_high(closes, lookback_window)
        previous_lows = rolling_low(closes, lookback_window)
        volume_ma = moving_average(volumes, volume_window)
        signals: list[StrategySignal] = []

        start_index = max(lookback_window, volume_window)
        for index in range(start_index, len(candles)):
            prior_high = previous_highs[index - 1]
            prior_low = previous_lows[index - 1]
            average_volume = volume_ma[index]
            if prior_high is None or prior_low is None or average_volume is None:
                continue
            has_volume = volumes[index] >= average_volume * volume_multiplier
            if (
                has_volume
                and direction in {"break_up", "both"}
                and closes[index] > prior_high
            ):
                signals.append(StrategySignal(index=index, side="buy"))
            elif (
                has_volume
                and direction in {"break_down", "both"}
                and closes[index] < prior_low
            ):
                signals.append(StrategySignal(index=index, side="sell"))

        return StrategyEvaluation(warmup=start_index - 1, signals=signals)


def _read_parameters(parameters: dict[str, object]) -> tuple[int, int, float, str]:
    lookback_window = int(parameters.get("lookback_window", 20))
    volume_window = int(parameters.get("volume_window", 20))
    volume_multiplier = float(parameters.get("volume_multiplier", 1.5))
    direction = str(parameters.get("direction", "both")).strip()
    if (
        lookback_window <= 1
        or volume_window <= 1
        or volume_multiplier <= 0
        or direction not in {"break_up", "break_down", "both"}
    ):
        raise StrategyConfigurationError("invalid_volume_breakout_parameters")
    return lookback_window, volume_window, volume_multiplier, direction
