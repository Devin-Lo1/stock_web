from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


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
