from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from .common import Market


class StrategyDefinitionCreate(BaseModel):
    code: str = Field(min_length=1)
    name: str = Field(min_length=1)
    description: str = ""
    default_parameters: dict[str, Any] = Field(default_factory=dict)


class StrategyDefinition(StrategyDefinitionCreate):
    id: str
    created_at: datetime
    updated_at: datetime


class SignalScanConfigCreate(BaseModel):
    strategy_code: str = Field(min_length=1)
    strategy_name: str = Field(min_length=1)
    parameters: dict[str, Any] = Field(default_factory=dict)
    enabled: bool = True
    push_candidate: bool = True
    sort_order: int = Field(default=0, ge=0)


class SignalScanConfigUpdate(BaseModel):
    strategy_name: str | None = Field(default=None, min_length=1)
    parameters: dict[str, Any] | None = None
    enabled: bool | None = None
    push_candidate: bool | None = None
    sort_order: int | None = Field(default=None, ge=0)


class SignalScanConfig(SignalScanConfigCreate):
    id: str
    created_at: datetime
    updated_at: datetime


class StrategyMonitorBase(BaseModel):
    position_id: str | None = Field(default=None, min_length=1)
    market: Market
    code: str = Field(min_length=1)
    name: str = Field(min_length=1)
    strategy_code: str = Field(min_length=1)
    strategy_name: str = Field(min_length=1)
    parameters: dict[str, Any] = Field(default_factory=dict)
    period: str = Field(default="day", min_length=1)
    scan_interval_minutes: int = Field(default=15, ge=1, le=1440)
    cooldown_minutes: int = Field(default=120, ge=0, le=1440)
    enabled: bool = True
    push_candidate: bool = True
    source_backtest_run_id: str | None = Field(default=None, min_length=1)


class StrategyMonitorCreate(StrategyMonitorBase):
    pass


class StrategyMonitorUpdate(BaseModel):
    position_id: str | None = Field(default=None, min_length=1)
    market: Market | None = None
    code: str | None = Field(default=None, min_length=1)
    name: str | None = Field(default=None, min_length=1)
    strategy_code: str | None = Field(default=None, min_length=1)
    strategy_name: str | None = Field(default=None, min_length=1)
    parameters: dict[str, Any] | None = None
    period: str | None = Field(default=None, min_length=1)
    scan_interval_minutes: int | None = Field(default=None, ge=1, le=1440)
    cooldown_minutes: int | None = Field(default=None, ge=0, le=1440)
    enabled: bool | None = None
    push_candidate: bool | None = None
    source_backtest_run_id: str | None = Field(default=None, min_length=1)


class StrategyMonitor(StrategyMonitorBase):
    id: str
    last_scanned_at: datetime | None = None
    last_triggered_at: datetime | None = None
    last_signal_event_id: str | None = None
    created_at: datetime
    updated_at: datetime
