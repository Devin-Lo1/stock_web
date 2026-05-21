from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from .common import Market

PositionTradeAction = Literal["open", "add", "reduce", "close"]


class PositionBase(BaseModel):
    market: Market
    code: str = Field(min_length=1)
    name: str = Field(min_length=1)
    quantity: float = Field(ge=0)
    cost_price: float = Field(ge=0)
    currency: str


class PositionCreate(PositionBase):
    pass


class PositionUpdate(BaseModel):
    market: Market | None = None
    code: str | None = Field(default=None, min_length=1)
    name: str | None = Field(default=None, min_length=1)
    quantity: float | None = Field(default=None, ge=0)
    cost_price: float | None = Field(default=None, ge=0)
    currency: str | None = None


class Position(PositionBase):
    id: str
    created_at: datetime
    updated_at: datetime


class PositionTradeCreate(BaseModel):
    action: PositionTradeAction
    quantity: float = Field(gt=0)
    price: float = Field(ge=0)
    fee: float = Field(default=0, ge=0)
    trade_time: datetime | None = None
    note: str = Field(default="", max_length=500)


class PositionTrade(BaseModel):
    id: str
    position_id: str
    market: Market
    code: str
    name: str
    currency: str
    action: PositionTradeAction
    quantity: float
    price: float
    fee: float
    trade_time: datetime
    note: str = ""
    created_at: datetime
    updated_at: datetime
