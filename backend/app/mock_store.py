from datetime import datetime, timedelta, timezone
from uuid import uuid4

from .database import (
    create_position,
    delete_position,
    get_quotes,
    update_position,
)
from .schemas import Candle, Signal


UTC = timezone.utc


def _now() -> datetime:
    return datetime.now(UTC)


def get_candles(code: str, period: str, limit: int) -> list[Candle]:
    quotes = get_quotes([code])
    if not quotes:
        return []
    quote = quotes[0]

    count = max(1, min(limit, 240))
    base_time = _now().replace(hour=0, minute=0, second=0, microsecond=0)
    candles: list[Candle] = []
    price = quote.current_price

    for index in range(count):
        offset = count - index
        open_price = price - offset * 0.25
        close_price = open_price + (0.4 if index % 2 == 0 else -0.25)
        high = max(open_price, close_price) + 0.5
        low = min(open_price, close_price) - 0.4
        candles.append(
            Candle(
                code=quote.code,
                market=quote.market,
                period=period,
                time=base_time - timedelta(days=offset),
                open=round(open_price, 2),
                high=round(high, 2),
                low=round(low, 2),
                close=round(close_price, 2),
                volume=quote.volume * (0.8 + index / count * 0.4),
                turnover=quote.turnover * (0.8 + index / count * 0.4),
            ),
        )

    return candles


def list_signals() -> list[Signal]:
    now = _now()
    signals: list[Signal] = []
    for quote in get_quotes([]):
        if quote.change_rate >= 1.5:
            signals.append(
                Signal(
                    id=str(uuid4()),
                    code=quote.code,
                    signal_type="DAILY_SURGE",
                    level="观察",
                    message=f"{quote.code} 当日上涨 {quote.change_rate:.2f}%",
                    trigger_value=quote.change_rate,
                    threshold_value=1.5,
                    created_at=now,
                ),
            )
        if quote.change_rate <= -2:
            signals.append(
                Signal(
                    id=str(uuid4()),
                    code=quote.code,
                    signal_type="DAILY_DROP",
                    level="提醒",
                    message=f"{quote.code} 当日下跌 {quote.change_rate:.2f}%",
                    trigger_value=quote.change_rate,
                    threshold_value=-2,
                    created_at=now,
                ),
            )
    return signals
