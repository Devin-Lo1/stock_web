from datetime import datetime

from pydantic import BaseModel

from .common import Market


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
