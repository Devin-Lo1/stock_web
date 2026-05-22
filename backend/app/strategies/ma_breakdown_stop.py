from ..schemas import Candle
from .base import StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .factors import moving_average


class MaBreakdownStopStrategy:
    code = "ma_breakdown_stop"

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        ma_window, _, _ = _read_parameters(parameters)
        return ma_window + 1

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        ma_window, stop_buffer_pct, direction = _read_parameters(parameters)
        closes = [candle.close for candle in candles]
        ma_values = moving_average(closes, ma_window)
        buffer_ratio = stop_buffer_pct / 100
        signals: list[StrategySignal] = []

        for index in range(ma_window, len(candles)):
            previous_ma = ma_values[index - 1]
            current_ma = ma_values[index]
            if previous_ma is None or current_ma is None:
                continue

            previous_stop = previous_ma * (1 - buffer_ratio)
            current_stop = current_ma * (1 - buffer_ratio)
            previous_close = closes[index - 1]
            current_close = closes[index]
            if (
                direction in {"recover_up", "both"}
                and previous_close <= previous_ma
                and current_close > current_ma
            ):
                signals.append(StrategySignal(index=index, side="buy"))
            elif (
                direction in {"break_down", "both"}
                and previous_close >= previous_stop
                and current_close < current_stop
            ):
                signals.append(StrategySignal(index=index, side="sell"))

        return StrategyEvaluation(warmup=ma_window - 1, signals=signals)


def _read_parameters(parameters: dict[str, object]) -> tuple[int, float, str]:
    ma_window = int(parameters.get("ma_window", 20))
    stop_buffer_pct = float(parameters.get("stop_buffer_pct", 0))
    direction = str(parameters.get("direction", "break_down")).strip()
    if (
        ma_window <= 1
        or stop_buffer_pct < 0
        or stop_buffer_pct >= 50
        or direction not in {"break_down", "recover_up", "both"}
    ):
        raise StrategyConfigurationError("invalid_ma_breakdown_stop_parameters")
    return ma_window, stop_buffer_pct, direction
