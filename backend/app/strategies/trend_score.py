from ..schemas import Candle
from .base import StrategyConfigurationError, StrategyEvaluation, StrategySignal
from .factors import moving_average


class TrendScoreStrategy:
    code = "trend_score"

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        ma_window, momentum_window, volume_window, _, _ = _read_parameters(parameters)
        return max(ma_window + 1, momentum_window + 1, volume_window)

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        ma_window, momentum_window, volume_window, buy_score, sell_score = (
            _read_parameters(parameters)
        )
        closes = [candle.close for candle in candles]
        volumes = [candle.volume for candle in candles]
        ma_values = moving_average(closes, ma_window)
        volume_ma = moving_average(volumes, volume_window)
        start_index = max(ma_window + 1, momentum_window + 1, volume_window)
        scores = [_score(index, closes, volumes, ma_values, volume_ma, momentum_window) for index in range(len(candles))]
        signals: list[StrategySignal] = []

        for index in range(start_index, len(candles)):
            previous_score = scores[index - 1]
            current_score = scores[index]
            if previous_score < buy_score <= current_score:
                signals.append(StrategySignal(index=index, side="buy"))
            elif previous_score > sell_score >= current_score:
                signals.append(StrategySignal(index=index, side="sell"))

        return StrategyEvaluation(warmup=start_index - 1, signals=signals)


def _score(
    index: int,
    closes: list[float],
    volumes: list[float],
    ma_values: list[float | None],
    volume_ma: list[float | None],
    momentum_window: int,
) -> int:
    if index <= 0:
        return 0
    score = 0
    current_ma = ma_values[index]
    previous_ma = ma_values[index - 1]
    average_volume = volume_ma[index]
    if current_ma is not None and closes[index] > current_ma:
        score += 1
    if current_ma is not None and previous_ma is not None and current_ma > previous_ma:
        score += 1
    if index >= momentum_window and closes[index] > closes[index - momentum_window]:
        score += 1
    if average_volume is not None and volumes[index] >= average_volume:
        score += 1
    return score


def _read_parameters(parameters: dict[str, object]) -> tuple[int, int, int, int, int]:
    ma_window = int(parameters.get("ma_window", 20))
    momentum_window = int(parameters.get("momentum_window", 20))
    volume_window = int(parameters.get("volume_window", 20))
    buy_score = int(parameters.get("buy_score", 3))
    sell_score = int(parameters.get("sell_score", 1))
    if (
        ma_window <= 1
        or momentum_window <= 1
        or volume_window <= 1
        or not 0 <= sell_score < buy_score <= 4
    ):
        raise StrategyConfigurationError("invalid_trend_score_parameters")
    return ma_window, momentum_window, volume_window, buy_score, sell_score
