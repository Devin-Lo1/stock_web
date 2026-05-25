from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

from .notifications import SignalEvent

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


class FundBenchmarkPoint(BaseModel):
    code: str
    name: str
    trade_date: date
    close: float
    daily_growth_rate: float = 0
    source: str = "eastmoney"


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
    shares: float = Field(default=0, ge=0)
    cost_nav: float = Field(default=0, ge=0)
    amount: float = Field(default=0, ge=0)
    fee: float = Field(default=0, ge=0)
    auto_nav: bool = False
    alert_enabled: bool = True
    alert_threshold_percent: float = Field(default=5, gt=0)
    alert_buy_amount: float = Field(default=5000, ge=0)
    alert_sell_ratio: float = Field(default=0.25, gt=0, le=1)
    trade_date: date | None = None
    operation_date: date | None = None
    operation_after_cutoff: bool = False
    note: str = Field(default="", max_length=500)


class FundPositionUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1)
    fund_type: str | None = None
    alert_enabled: bool | None = None
    alert_threshold_percent: float | None = Field(default=None, gt=0)
    alert_buy_amount: float | None = Field(default=None, ge=0)
    alert_sell_ratio: float | None = Field(default=None, gt=0, le=1)


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
    alert_enabled: bool = True
    alert_threshold_percent: float = 5
    alert_buy_amount: float = 5000
    alert_sell_ratio: float = 0.25
    created_at: datetime
    updated_at: datetime


class FundTradeCreate(BaseModel):
    action: FundTradeAction
    shares: float = Field(default=0, ge=0)
    nav: float = Field(default=0, ge=0)
    amount: float = Field(default=0, ge=0)
    fee: float = Field(default=0, ge=0)
    auto_nav: bool = False
    trade_date: date | None = None
    operation_date: date | None = None
    operation_after_cutoff: bool = False
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
    operation_date: date | None = None
    operation_after_cutoff: bool = False
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


class FundAlertSchedulerUpdate(BaseModel):
    enabled: bool | None = None
    reminder_times: list[str] | None = None
    due_window_minutes: int | None = Field(default=None, ge=1, le=60)


class FundAlertSchedulerStatus(BaseModel):
    enabled: bool = False
    running: bool = False
    scanning: bool = False
    poll_interval_seconds: int = 60
    reminder_times: list[str] = Field(default_factory=lambda: ["14:30"])
    due_window_minutes: int = 10
    next_run_at: datetime | None = None
    last_started_at: datetime | None = None
    last_stopped_at: datetime | None = None
    last_scan_at: datetime | None = None
    last_scan_key: str = ""
    last_error: str = ""
    last_result: dict[str, Any] = Field(default_factory=dict)


class FundAlertScanResult(BaseModel):
    scanned_count: int = 0
    created_count: int = 0
    skipped_count: int = 0
    events: list[SignalEvent] = Field(default_factory=list)
    errors: list[dict[str, Any]] = Field(default_factory=list)
    scanned_at: datetime
    scan_key: str = ""


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
