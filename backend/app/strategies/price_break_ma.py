from ..schemas import Candle
from .base import StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .factors import moving_average


class PriceBreakMaStrategy:
    code = "price_break_ma"

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        ma_window, _ = _read_parameters(parameters)
        return ma_window + 1

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        ma_window, direction = _read_parameters(parameters)
        closes = [candle.close for candle in candles]
        ma_values = moving_average(closes, ma_window)
        signals: list[StrategySignal] = []

        for index in range(ma_window, len(candles)):
            previous_ma = ma_values[index - 1]
            current_ma = ma_values[index]
            if previous_ma is None or current_ma is None:
                continue

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
                and previous_close >= previous_ma
                and current_close < current_ma
            ):
                signals.append(StrategySignal(index=index, side="sell"))

        return StrategyEvaluation(warmup=ma_window - 1, signals=signals)


def _read_parameters(parameters: dict[str, object]) -> tuple[int, str]:
    ma_window = int(parameters.get("ma_window", 10))
    direction = str(parameters.get("direction", "both")).strip()
    if ma_window <= 1 or direction not in {"break_down", "recover_up", "both"}:
        raise StrategyConfigurationError("invalid_price_break_ma_parameters")
    return ma_window, direction
