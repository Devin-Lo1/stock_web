from datetime import datetime, timezone

import pytest
from app import database
from app.main import app
from app.schemas import (
    Candle,
    PositionCreate,
    PositionTradeCreate,
    PositionUpdate,
    QuoteSnapshot,
)
from fastapi.testclient import TestClient


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
    assert updated.avg_cost_price == 360
    assert updated.adjusted_cost_price == 360
    assert updated.updated_at >= created.updated_at

    assert database.delete_position(created.id) is True
    assert database.get_position(created.id) is None
    assert database.delete_position(created.id) is False


def test_position_trade_history_persists_after_position_delete() -> None:
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

    opening_trades = database.list_position_trades(position_id=created.id)
    assert len(opening_trades) == 1
    assert opening_trades[0].action == "open"
    assert opening_trades[0].quantity == 100
    assert opening_trades[0].price == 350

    added = database.create_position_trade_for_position(
        created,
        PositionTradeCreate(
            action="add",
            quantity=50,
            price=360,
            fee=1.2,
            trade_time=datetime(2026, 5, 20, tzinfo=timezone.utc),
            note="scale in",
        ),
    )

    rows_by_code = database.list_position_trades(code="hk.00700", limit=10)
    assert {row.id for row in rows_by_code} == {opening_trades[0].id, added.id}
    updated = database.get_position(created.id)
    assert updated is not None
    assert updated.quantity == 150
    expected_cost = (100 * 350 + 50 * 360 + 1.2) / 150
    assert updated.cost_price == pytest.approx(expected_cost)
    assert updated.avg_cost_price == pytest.approx(expected_cost)
    assert updated.adjusted_cost_price == pytest.approx(expected_cost)
    assert updated.realized_profit == 0

    assert database.delete_position(created.id) is True
    remaining = database.list_position_trades(position_id=created.id)
    assert {row.id for row in remaining} == {opening_trades[0].id, added.id}


def test_position_trade_endpoints() -> None:
    client = TestClient(app)
    position_response = client.post(
        "/api/v1/positions",
        json={
            "market": "US",
            "code": "US.MU",
            "name": "Micron",
            "quantity": 10,
            "cost_price": 100,
            "currency": "USD",
        },
    )
    position_id = position_response.json()["id"]

    create_trade_response = client.post(
        f"/api/v1/positions/{position_id}/trades",
        json={
            "action": "reduce",
            "quantity": 2,
            "price": 120,
            "fee": 0.5,
            "trade_time": "2026-05-20T00:00:00Z",
            "note": "trim",
        },
    )
    list_response = client.get(f"/api/v1/positions/{position_id}/trades")
    code_response = client.get("/api/v1/positions/trades?code=us.mu")

    assert position_response.status_code == 201
    assert create_trade_response.status_code == 201
    assert create_trade_response.json()["action"] == "reduce"
    assert create_trade_response.json()["code"] == "US.MU"
    assert len(list_response.json()) == 2
    assert {item["action"] for item in code_response.json()} == {"open", "reduce"}
    current_position = client.get("/api/v1/positions").json()[0]
    assert current_position["quantity"] == 8
    assert current_position["avg_cost_price"] == 100
    assert current_position["adjusted_cost_price"] == pytest.approx(95.0625)
    assert current_position["cost_price"] == pytest.approx(95.0625)
    assert current_position["realized_profit"] == pytest.approx(39.5)

    delete_response = client.delete(
        f"/api/v1/positions/{position_id}/trades/{create_trade_response.json()['id']}",
    )
    restored_position = client.get("/api/v1/positions").json()[0]
    restored_trades = client.get(f"/api/v1/positions/{position_id}/trades").json()

    assert delete_response.status_code == 204
    assert restored_position["quantity"] == 10
    assert restored_position["cost_price"] == 100
    assert restored_position["avg_cost_price"] == 100
    assert restored_position["adjusted_cost_price"] == 100
    assert restored_position["realized_profit"] == 0
    assert [item["action"] for item in restored_trades] == ["open"]


def test_position_trade_delete_replays_remaining_trades() -> None:
    created = database.create_position(
        PositionCreate(
            market="HK",
            code="HK.00700",
            name="Tencent",
            quantity=100,
            cost_price=10,
            currency="HKD",
        ),
    )
    opening = database.list_position_trades(position_id=created.id)[0]
    add = database.create_position_trade_for_position(
        database.get_position(created.id) or created,
        PositionTradeCreate(action="add", quantity=100, price=20, fee=0),
    )
    reduce = database.create_position_trade_for_position(
        database.get_position(created.id) or created,
        PositionTradeCreate(action="reduce", quantity=50, price=30, fee=0),
    )

    position_after_reduce = database.get_position(created.id)
    assert position_after_reduce is not None
    assert position_after_reduce.quantity == 150
    assert position_after_reduce.realized_profit == pytest.approx(750)

    deleted = database.delete_position_trade_for_position(
        position_after_reduce,
        reduce.id,
    )
    replayed = database.get_position(created.id)
    trades = database.list_position_trades(position_id=created.id)

    assert deleted is True
    assert replayed is not None
    assert replayed.quantity == 200
    assert replayed.avg_cost_price == pytest.approx(15)
    assert replayed.adjusted_cost_price == pytest.approx(15)
    assert replayed.realized_profit == 0
    assert {trade.id for trade in trades} == {opening.id, add.id}


def test_position_trade_close_updates_position_snapshot() -> None:
    client = TestClient(app)
    position_response = client.post(
        "/api/v1/positions",
        json={
            "market": "HK",
            "code": "HK.09988",
            "name": "Alibaba",
            "quantity": 100,
            "cost_price": 90,
            "currency": "HKD",
        },
    )
    position_id = position_response.json()["id"]

    close_response = client.post(
        f"/api/v1/positions/{position_id}/trades",
        json={
            "action": "close",
            "quantity": 100,
            "price": 95,
            "fee": 0,
        },
    )
    current_position = client.get("/api/v1/positions").json()[0]

    assert close_response.status_code == 201
    assert current_position["quantity"] == 0
    assert current_position["cost_price"] == 0
    assert current_position["avg_cost_price"] == 0
    assert current_position["adjusted_cost_price"] == 0
    assert current_position["realized_profit"] == pytest.approx(500)


def test_position_trade_rejects_over_reduce() -> None:
    client = TestClient(app)
    position_response = client.post(
        "/api/v1/positions",
        json={
            "market": "US",
            "code": "US.MU",
            "name": "Micron",
            "quantity": 10,
            "cost_price": 100,
            "currency": "USD",
        },
    )
    position_id = position_response.json()["id"]

    response = client.post(
        f"/api/v1/positions/{position_id}/trades",
        json={
            "action": "reduce",
            "quantity": 20,
            "price": 120,
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "POSITION_TRADE_INVALID"


def test_position_snapshot_capture_and_latest_endpoint() -> None:
    client = TestClient(app)
    position_response = client.post(
        "/api/v1/positions",
        json={
            "market": "HK",
            "code": "HK.00700",
            "name": "Tencent",
            "quantity": 100,
            "cost_price": 10,
            "currency": "HKD",
        },
    )
    database.upsert_quote(
        QuoteSnapshot(
            code="HK.00700",
            market="HK",
            currency="HKD",
            current_price=15,
            previous_close=14,
            open=14.2,
            high=15.5,
            low=13.8,
            volume=1000,
            turnover=15000,
            change=1,
            change_rate=7.14,
            quote_time=datetime(2026, 5, 21, tzinfo=timezone.utc),
        ),
    )

    capture_response = client.post("/api/v1/positions/snapshots/capture")
    latest_response = client.get("/api/v1/positions/snapshots/latest")
    by_position_response = client.get(
        f"/api/v1/positions/{position_response.json()['id']}/snapshots",
    )

    assert capture_response.status_code == 200
    snapshot = capture_response.json()[0]
    assert snapshot["market_value"] == 1500
    assert snapshot["day_profit"] == 100
    assert snapshot["day_profit_rate"] == pytest.approx(7.142857142857142)
    assert snapshot["holding_profit"] == 500
    assert snapshot["holding_profit_rate"] == 50
    assert snapshot["total_profit"] == 500
    assert snapshot["position_weight"] == 100
    assert latest_response.json()[0]["id"] == snapshot["id"]
    assert by_position_response.json()[0]["id"] == snapshot["id"]


def test_position_snapshot_uses_adjusted_cost_and_realized_profit() -> None:
    client = TestClient(app)
    position_response = client.post(
        "/api/v1/positions",
        json={
            "market": "US",
            "code": "US.MU",
            "name": "Micron",
            "quantity": 100,
            "cost_price": 10,
            "currency": "USD",
        },
    )
    position_id = position_response.json()["id"]
    client.post(
        f"/api/v1/positions/{position_id}/trades",
        json={
            "action": "reduce",
            "quantity": 50,
            "price": 15,
            "fee": 0,
        },
    )
    database.upsert_quote(
        QuoteSnapshot(
            code="US.MU",
            market="US",
            currency="USD",
            current_price=16,
            previous_close=15,
            open=15,
            high=16.2,
            low=14.8,
            volume=1000,
            turnover=16000,
            change=1,
            change_rate=6.67,
            quote_time=datetime(2026, 5, 21, tzinfo=timezone.utc),
        ),
    )

    snapshot = client.post("/api/v1/positions/snapshots/capture").json()[0]

    assert snapshot["quantity"] == 50
    assert snapshot["avg_cost_price"] == 10
    assert snapshot["adjusted_cost_price"] == 5
    assert snapshot["realized_profit"] == 250
    assert snapshot["market_value"] == 800
    assert snapshot["holding_profit"] == 550
    assert snapshot["total_profit"] == 800


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
        extended_session="after",
        extended_price=29.6,
        extended_change=-0.12,
        extended_change_rate=-0.4,
        extended_volume=120000,
        extended_turnover=3552000,
    )

    database.upsert_quote(quote)
    rows = database.get_quotes(["hk.02628"])

    assert rows == [quote]

    changed = quote.model_copy(
        update={
            "current_price": 30.0,
            "change": -0.58,
            "extended_session": "",
            "extended_price": 0,
            "extended_change": 0,
            "extended_change_rate": 0,
            "extended_volume": 0,
            "extended_turnover": 0,
        }
    )
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
