from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field

FundTradeAction = Literal["buy", "sell"]
FundValuationMode = Literal["official", "estimated", "none"]
FundGridAction = Literal["buy", "sell"]


class FundSearchResult(BaseModel):
    code: str
    name: str
    fund_type: str = ""
    company: str = ""
    manager: str = ""
    source: str = "eastmoney"


class FundNavPoint(BaseModel):
    fund_code: str
    nav_date: date
    unit_nav: float
    accumulated_nav: float = 0
    daily_growth_rate: float = 0
    subscribe_status: str = ""
    redeem_status: str = ""
    source: str = "eastmoney"
    updated_at: datetime


class FundQuote(BaseModel):
    fund_code: str
    name: str
    nav_date: date | None = None
    unit_nav: float = 0
    accumulated_nav: float = 0
    daily_growth_rate: float = 0
    estimated_nav: float = 0
    estimated_change_rate: float = 0
    estimate_time: datetime | None = None
    source: str = "eastmoney"


class FundPositionCreate(BaseModel):
    fund_code: str = Field(min_length=1, max_length=20)
    name: str = Field(min_length=1)
    fund_type: str = ""
    shares: float = Field(ge=0)
    cost_nav: float = Field(ge=0)
    fee: float = Field(default=0, ge=0)
    trade_date: date | None = None
    note: str = Field(default="", max_length=500)


class FundPositionUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1)
    fund_type: str | None = None


class FundPosition(BaseModel):
    id: str
    fund_code: str
    name: str
    fund_type: str = ""
    shares: float
    avg_cost_nav: float
    invested_amount: float
    realized_profit: float
    currency: str = "CNY"
    created_at: datetime
    updated_at: datetime


class FundTradeCreate(BaseModel):
    action: FundTradeAction
    shares: float = Field(gt=0)
    nav: float = Field(ge=0)
    fee: float = Field(default=0, ge=0)
    trade_date: date | None = None
    note: str = Field(default="", max_length=500)


class FundTrade(BaseModel):
    id: str
    fund_position_id: str
    fund_code: str
    name: str
    action: FundTradeAction
    shares: float
    nav: float
    fee: float
    trade_date: date
    note: str = ""
    created_at: datetime
    updated_at: datetime


class FundGridRecommendation(BaseModel):
    position_id: str
    fund_code: str
    name: str
    action: FundGridAction
    action_label: str
    reason: str
    baseline_nav: float
    current_nav: float
    change_rate: float
    threshold_percent: float = 5
    recommended_amount: float = 0
    recommended_shares: float = 0
    valuation_mode: FundValuationMode = "none"
    valuation_time: datetime | None = None


class FundPositionSummary(BaseModel):
    position: FundPosition
    latest_nav: FundNavPoint | None = None
    quote: FundQuote | None = None
    grid_recommendation: FundGridRecommendation | None = None
    valuation_mode: FundValuationMode = "none"
    display_nav: float = 0
    display_change_rate: float = 0
    display_time: datetime | None = None
    day_profit: float = 0
    day_profit_rate: float = 0
    market_value: float = 0
    holding_profit: float = 0
    holding_profit_rate: float = 0
    total_profit: float = 0
    total_profit_rate: float = 0
