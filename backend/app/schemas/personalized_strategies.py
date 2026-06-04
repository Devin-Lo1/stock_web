from datetime import date
from typing import Any, Literal

from pydantic import BaseModel, Field


PersonalizedDirectionMode = Literal["long_only", "long_short"]
PersonalizedRiskLevel = Literal["steady", "balanced", "aggressive"]
PersonalizedScanStatus = Literal["completed", "failed"]
PersonalizedPositionState = Literal["flat", "long", "short"]
PersonalizedSignalKind = Literal[
    "previous_close",
    "intraday_estimate",
    "strategy_signal",
]


class PersonalizedStrategySegment(BaseModel):
    label: str
    start_date: date
    end_date: date
    total_return: float
    max_drawdown: float
    win_rate: float
    round_trip_count: int


class PersonalizedStrategyTemplate(BaseModel):
    code: str = Field(min_length=1)
    symbol: str = Field(min_length=1)
    name: str = Field(min_length=1)
    description: str = ""
    benchmark_symbol: str = Field(default="US.QQQ", min_length=1)
    direction_mode: PersonalizedDirectionMode = "long_short"
    risk_level: PersonalizedRiskLevel = "balanced"
    position_ratio: float = Field(default=1.0, gt=0, le=1)
    max_hold_days: int | None = Field(default=None, gt=0)
    parameters: dict[str, Any] = Field(default_factory=dict)
    entry_rules: list[str] = Field(default_factory=list)
    exit_rules: list[str] = Field(default_factory=list)
    segments: list[PersonalizedStrategySegment] = Field(default_factory=list)


class PersonalizedStrategyDecision(BaseModel):
    kind: PersonalizedSignalKind
    title: str
    action: str
    action_label: str
    current_position: PersonalizedPositionState = "flat"
    latest_date: date | None = None
    latest_price: float | None = None
    signal_date: date | None = None
    reason: str = ""
    flat_decision: str = ""
    long_decision: str = ""
    short_decision: str = ""
    is_realtime: bool = False
    is_confirmed: bool = False
    detail: dict[str, Any] = Field(default_factory=dict)


class PersonalizedStrategyScanResult(BaseModel):
    template: PersonalizedStrategyTemplate
    status: PersonalizedScanStatus
    action: str
    action_label: str
    current_position: PersonalizedPositionState = "flat"
    latest_date: date | None = None
    latest_close: float | None = None
    signal_date: date | None = None
    reason: str = ""
    refresh_error: str | None = None
    today_signal: PersonalizedStrategyDecision | None = None
    previous_close_signal: PersonalizedStrategyDecision | None = None
    detail: dict[str, Any] = Field(default_factory=dict)
