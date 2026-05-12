from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


Market = Literal["HK", "US", "SH", "SZ"]


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


class QuoteSnapshot(BaseModel):
    code: str
    market: Market
    currency: str
    current_price: float
    previous_close: float
    open: float
    high: float
    low: float
    volume: float
    turnover: float
    turnover_rate: float = 0
    pe_ratio: float = 0
    lot_size: float = 0
    change: float
    change_rate: float
    quote_time: datetime


class Candle(BaseModel):
    code: str
    market: Market
    period: str
    time: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float
    turnover: float


class Signal(BaseModel):
    id: str
    code: str
    signal_type: str
    level: str
    message: str
    trigger_value: float
    threshold_value: float
    created_at: datetime


class StockSearchResult(BaseModel):
    code: str
    name: str
    market: str
    stock_type: str
    lot_size: float = 0
