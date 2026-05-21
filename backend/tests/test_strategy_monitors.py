from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app import database
from app.main import app
from app.schemas import Candle, StrategyMonitorCreate, StrategyMonitorUpdate
from app.services.strategy_monitor_scanner import scan_strategy_monitors


def test_strategy_monitor_repository_create_update_list_delete() -> None:
    monitor = database.create_strategy_monitor(
        StrategyMonitorCreate(
            market="HK",
            code="hk.09988",
            name="Alibaba",
            strategy_code="ma_cross",
            strategy_name="MA Cross",
            parameters={"short_window": 3, "long_window": 7},
            scan_interval_minutes=15,
            cooldown_minutes=60,
            push_candidate=False,
        ),
        monitor_id="monitor-1",
    )

    rows = database.list_strategy_monitors(code="HK.09988")
    updated = database.update_strategy_monitor(
        monitor.id,
        StrategyMonitorUpdate(scan_interval_minutes=30, enabled=False),
    )

    assert rows[0].id == monitor.id
    assert rows[0].code == "HK.09988"
    assert rows[0].push_candidate is False
    assert updated is not None
    assert updated.scan_interval_minutes == 30
    assert updated.enabled is False
    assert database.list_strategy_monitors(enabled_only=True) == []
    assert database.delete_strategy_monitor(monitor.id) is True
    assert database.get_strategy_monitor(monitor.id) is None


def test_strategy_monitor_endpoints_create_update_scan_and_delete() -> None:
    client = TestClient(app)

    create_response = client.post(
        "/api/v1/strategies/monitors",
        json={
            "market": "HK",
            "code": "HK.09988",
            "name": "Alibaba",
            "strategy_code": "ma_cross",
            "strategy_name": "MA Cross",
            "parameters": {"short_window": 3, "long_window": 7},
            "period": "day",
            "scan_interval_minutes": 15,
            "cooldown_minutes": 60,
            "enabled": True,
            "push_candidate": True,
        },
    )
    monitor_id = create_response.json()["id"]
    update_response = client.put(
        f"/api/v1/strategies/monitors/{monitor_id}",
        json={"push_candidate": False, "cooldown_minutes": 0},
    )
    list_response = client.get("/api/v1/strategies/monitors?enabled_only=true")
    scan_response = client.post("/api/v1/strategies/monitors/scan?force=true")
    delete_response = client.delete(f"/api/v1/strategies/monitors/{monitor_id}")

    assert create_response.status_code == 201
    assert update_response.status_code == 200
    assert update_response.json()["push_candidate"] is False
    assert len(list_response.json()) == 1
    assert scan_response.status_code == 200
    assert delete_response.status_code == 204


def test_strategy_monitor_scan_creates_signal_event_and_updates_state() -> None:
    monitor = database.create_strategy_monitor(
        StrategyMonitorCreate(
            market="HK",
            code="HK.09988",
            name="Alibaba",
            strategy_code="ma_cross",
            strategy_name="MA Cross",
            parameters={"short_window": 3, "long_window": 7},
            cooldown_minutes=0,
            push_candidate=False,
        ),
        monitor_id="monitor-ma-cross",
    )
    start = datetime(2026, 5, 1, tzinfo=timezone.utc)
    closes = [10, 10, 10, 10, 10, 10, 10, 30]
    database.upsert_candles(
        [
            Candle(
                code="HK.09988",
                market="HK",
                period="day",
                time=start + timedelta(days=index),
                open=close,
                high=close,
                low=close,
                close=close,
                volume=1000,
                turnover=close * 1000,
            )
            for index, close in enumerate(closes)
        ],
    )

    result = scan_strategy_monitors(refresh=False, force=True)
    duplicate_result = scan_strategy_monitors(refresh=False, force=True)
    updated = database.get_strategy_monitor(monitor.id)
    events = database.list_signal_events(limit=10)

    assert result.scanned_count == 1
    assert result.created_count == 1
    assert duplicate_result.created_count == 0
    assert updated is not None
    assert updated.last_scanned_at is not None
    assert updated.last_signal_event_id == result.events[0].id
    assert events[0].source == "strategy_monitor"
    assert events[0].signal_type == "ma_cross_buy"
    assert events[0].payload["monitor_id"] == monitor.id
    assert events[0].payload["push_candidate"] is False
    assert events[0].payload["parameters"] == {"short_window": 3, "long_window": 7}


def test_strategy_monitor_create_rejects_unknown_strategy() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/v1/strategies/monitors",
        json={
            "market": "HK",
            "code": "HK.09988",
            "name": "Alibaba",
            "strategy_code": "unknown",
            "strategy_name": "Unknown",
            "parameters": {},
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "STRATEGY_NOT_SUPPORTED"
