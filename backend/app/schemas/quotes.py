from datetime import datetime

from pydantic import BaseModel

from .common import Market


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
    extended_session: str = ""
    extended_price: float = 0
    extended_change: float = 0
    extended_change_rate: float = 0
    extended_volume: float = 0
    extended_turnover: float = 0


class CapitalFlowBucket(BaseModel):
    bucket: str
    inflow: float
    outflow: float
    net_inflow: float


class CapitalFlowPoint(BaseModel):
    time: datetime
    net_inflow: float
    super_net_inflow: float
    big_net_inflow: float
    mid_net_inflow: float
    small_net_inflow: float


class CapitalFlowSnapshot(BaseModel):
    code: str
    market: Market
    currency: str
    update_time: datetime | None = None
    total_inflow: float
    total_outflow: float
    net_inflow: float
    buckets: list[CapitalFlowBucket]
    points: list[CapitalFlowPoint]
