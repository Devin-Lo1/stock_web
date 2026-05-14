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
