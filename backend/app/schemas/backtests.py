from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


BacktestStatus = Literal["created", "running", "completed", "failed"]
TradeSide = Literal["buy", "sell"]


class BacktestCreate(BaseModel):
    strategy_code: str = Field(min_length=1)
    stock_code: str = Field(min_length=1)
    period: str = Field(default="day", min_length=1)
    start_date: date
    end_date: date
    initial_cash: float = Field(gt=0)
    fee_rate: float = Field(default=0, ge=0)
    slippage_rate: float = Field(default=0, ge=0)
    parameters: dict[str, Any] = Field(default_factory=dict)


class BacktestRun(BacktestCreate):
    id: str
    status: BacktestStatus
    summary: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime


class BacktestEquityPoint(BaseModel):
    run_id: str
    time: datetime
    equity: float
    cash: float
    position_quantity: float
    market_value: float
    drawdown: float


class BacktestTrade(BaseModel):
    run_id: str
    time: datetime
    side: TradeSide
    price: float
    quantity: float
    fee: float
    slippage: float
    cash_after: float
    position_after: float


class BacktestResult(BaseModel):
    run: BacktestRun
    equity_curve: list[BacktestEquityPoint] = Field(default_factory=list)
    trades: list[BacktestTrade] = Field(default_factory=list)
