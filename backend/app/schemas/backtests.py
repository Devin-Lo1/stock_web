from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator


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

    @model_validator(mode="after")
    def validate_date_range(self) -> "BacktestCreate":
        if self.start_date > self.end_date:
            raise ValueError("start_date must be earlier than or equal to end_date")
        return self


class BacktestRun(BacktestCreate):
    id: str
    name: str = ""
    status: BacktestStatus
    summary: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime


class BacktestRename(BaseModel):
    name: str = Field(default="", max_length=80)


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


class BacktestBatchCreate(BaseModel):
    items: list[BacktestCreate] = Field(min_length=1, max_length=50)
    continue_on_error: bool = True


class BacktestBatchItemResult(BaseModel):
    index: int
    request: BacktestCreate
    run: BacktestRun | None = None
    error: str | None = None


class BacktestBatchResult(BaseModel):
    total_count: int
    completed_count: int
    failed_count: int
    results: list[BacktestBatchItemResult] = Field(default_factory=list)
