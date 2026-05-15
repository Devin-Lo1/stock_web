from dataclasses import dataclass
from typing import Protocol

from ..schemas import Candle


@dataclass(frozen=True)
class StrategySignal:
    index: int
    side: str


@dataclass(frozen=True)
class StrategyEvaluation:
    warmup: int
    signals: list[StrategySignal]


class StrategyConfigurationError(ValueError):
    def __init__(self, reason: str) -> None:
        self.reason = reason
        super().__init__(reason)


class BacktestStrategy(Protocol):
    code: str

    def minimum_candles(self, parameters: dict[str, object]) -> int:
        ...

    def evaluate(
        self,
        candles: list[Candle],
        parameters: dict[str, object],
    ) -> StrategyEvaluation:
        ...
