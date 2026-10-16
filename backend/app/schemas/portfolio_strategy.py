from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

PortfolioStrategyStatus = Literal["ok", "watch", "warning", "breach"]
PortfolioStrategyAction = Literal[
    "hold",
    "buy",
    "sell",
    "rebalance",
    "alert",
    "freeze",
]
PortfolioStrategyPriority = Literal["low", "medium", "high"]


class PortfolioStrategyMetric(BaseModel):
    key: str
    label: str
    value: float
    unit: str = "%"
    target: float | None = None
    lower_bound: float | None = None
    upper_bound: float | None = None
    status: PortfolioStrategyStatus = "ok"
    detail: str = ""


class PortfolioStrategyAsset(BaseModel):
    code: str
    name: str
    category: str
    quantity: float
    current_price: float
    cost_price: float
    market_value: float
    cost_value: float
    holding_profit: float
    holding_profit_rate: float
    weight: float


class PortfolioStrategySuggestion(BaseModel):
    action: PortfolioStrategyAction
    code: str = ""
    amount: float = 0
    percent_of_equity: float = 0
    reason_code: str
    reason: str
    priority: PortfolioStrategyPriority = "medium"
    allocation: dict[str, float] = Field(default_factory=dict)
    requires_user_confirmation: bool = True
    auto_execute: bool = False


class PortfolioStrategyResult(BaseModel):
    market: str
    currency: str
    cash: float = 0
    total_market_value: float = 0
    total_equity: float = 0
    holding_profit: float = 0
    holding_profit_rate: float = 0
    core_weight: float = 0
    growth_weight: float = 0
    cash_like_weight: float = 0
    leverage_weight: float = 0
    semiconductor_weight: float = 0
    assets: list[PortfolioStrategyAsset] = Field(default_factory=list)
    metrics: list[PortfolioStrategyMetric] = Field(default_factory=list)
    suggestions: list[PortfolioStrategySuggestion] = Field(default_factory=list)
    limitations: list[str] = Field(default_factory=list)
    generated_at: datetime
