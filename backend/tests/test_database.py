from datetime import datetime, timezone

from app import database
from app.schemas import Candle, PositionCreate, PositionUpdate, QuoteSnapshot


def test_position_crud() -> None:
    created = database.create_position(
        PositionCreate(
            market="HK",
            code="HK.00700",
            name="Tencent",
            quantity=100,
            cost_price=350,
            currency="HKD",
        ),
    )

    assert database.get_position(created.id) == created
    assert database.list_positions() == [created]

    updated = database.update_position(
        created.id,
        PositionUpdate(quantity=200, cost_price=360),
    )

    assert updated is not None
    assert updated.quantity == 200
    assert updated.cost_price == 360
    assert updated.updated_at >= created.updated_at

    assert database.delete_position(created.id) is True
    assert database.get_position(created.id) is None
    assert database.delete_position(created.id) is False


def test_quote_upsert_and_get() -> None:
    quote_time = datetime(2026, 5, 14, 1, 0, tzinfo=timezone.utc)
    quote = QuoteSnapshot(
        code="HK.02628",
        market="HK",
        currency="HKD",
        current_price=29.72,
        previous_close=30.58,
        open=30.52,
        high=30.74,
        low=29.48,
        volume=16860000,
        turnover=504000000,
        turnover_rate=0.23,
        pe_ratio=4.92,
        lot_size=1000,
        change=-0.86,
        change_rate=-2.81,
        quote_time=quote_time,
    )

    database.upsert_quote(quote)
    rows = database.get_quotes(["hk.02628"])

    assert rows == [quote]

    changed = quote.model_copy(update={"current_price": 30.0, "change": -0.58})
    database.upsert_quote(changed)

    assert database.get_quotes(["HK.02628"]) == [changed]


def test_candle_upsert_and_list() -> None:
    first = Candle(
        code="HK.02628",
        market="HK",
        period="day",
        time=datetime(2026, 5, 13, tzinfo=timezone.utc),
        open=30.52,
        high=30.74,
        low=29.48,
        close=29.72,
        volume=16860000,
        turnover=504000000,
    )
    second = Candle(
        code="HK.02628",
        market="HK",
        period="day",
        time=datetime(2026, 5, 14, tzinfo=timezone.utc),
        open=29.72,
        high=30.1,
        low=29.5,
        close=29.88,
        volume=12000000,
        turnover=360000000,
    )

    database.upsert_candles([second, first])
    rows = database.list_candles("hk.02628", "day", 10)

    assert rows == [first, second]

    revised_second = second.model_copy(update={"close": 30.0})
    database.upsert_candles([revised_second])

    assert database.list_candles("HK.02628", "day", 1) == [revised_second]
