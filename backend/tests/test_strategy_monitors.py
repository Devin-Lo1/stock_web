from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app import database
from app.main import app
from app.schemas import (
    Candle,
    NotificationDeviceUpsert,
    StrategyMonitorCreate,
    StrategyMonitorScanLogCreate,
    StrategyMonitorSchedulerUpdate,
    StrategyMonitorUpdate,
)
from app.services.strategy_monitor_scheduler import (
    StrategyMonitorScheduler,
    configure_strategy_monitor_scheduler_from_env,
    get_strategy_monitor_scheduler,
)
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


def test_strategy_monitor_scan_log_repository_list_and_delete() -> None:
    log = database.create_strategy_monitor_scan_log(
        StrategyMonitorScanLogCreate(
            monitor_id="monitor-1",
            code="hk.09988",
            strategy_code="ma_cross",
            stage="evaluate",
            status="not_triggered",
            message="未触发信号。",
            detail={"latest_close": 88.8},
        ),
        log_id="scan-log-1",
    )

    by_code = database.list_strategy_monitor_scan_logs(
        code="HK.09988",
        status="not_triggered",
    )

    assert log.code == "HK.09988"
    assert by_code[0].id == "scan-log-1"
    assert by_code[0].detail["latest_close"] == 88.8
    assert database.delete_strategy_monitor_scan_log(log.id) is True
    assert database.list_strategy_monitor_scan_logs(monitor_id="monitor-1") == []


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
    logs_response = client.get(
        f"/api/v1/strategies/monitors/scan-logs?monitor_id={monitor_id}",
    )
    delete_response = client.delete(f"/api/v1/strategies/monitors/{monitor_id}")

    assert create_response.status_code == 201
    assert update_response.status_code == 200
    assert update_response.json()["push_candidate"] is False
    assert len(list_response.json()) == 1
    assert scan_response.status_code == 200
    assert logs_response.status_code == 200
    assert logs_response.json()[0]["monitor_id"] == monitor_id
    assert delete_response.status_code == 204


def test_strategy_monitor_scan_log_endpoint_delete() -> None:
    client = TestClient(app)
    log = database.create_strategy_monitor_scan_log(
        StrategyMonitorScanLogCreate(
            monitor_id="monitor-1",
            code="HK.09988",
            strategy_code="ma_cross",
            stage="evaluate",
            status="not_triggered",
            message="未触发信号。",
        ),
    )

    delete_response = client.delete(f"/api/v1/strategies/monitors/scan-logs/{log.id}")
    list_response = client.get("/api/v1/strategies/monitors/scan-logs?code=HK.09988")

    assert delete_response.status_code == 204
    assert list_response.json() == []


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
    logs = database.list_strategy_monitor_scan_logs(monitor_id=monitor.id)

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
    assert logs[0].status == "duplicate_signal"
    assert logs[1].status == "triggered"
    assert logs[1].detail["signal_event_id"] == result.events[0].id


def test_strategy_monitor_scan_dispatches_push_candidate_records() -> None:
    device = database.upsert_notification_device(
        NotificationDeviceUpsert(
            platform="android",
            push_provider="unknown",
            push_token="local-token",
            important_enabled=True,
        ),
    )
    database.create_strategy_monitor(
        StrategyMonitorCreate(
            market="HK",
            code="HK.09988",
            name="Alibaba",
            strategy_code="ma_cross",
            strategy_name="MA Cross",
            parameters={"short_window": 3, "long_window": 7},
            cooldown_minutes=0,
            push_candidate=True,
        ),
        monitor_id="monitor-push",
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
    records = database.list_push_records(signal_event_id=result.events[0].id)

    assert result.created_count == 1
    assert len(records) == 1
    assert records[0].device_id == device.id
    assert records[0].status == "skipped"
    assert records[0].provider == "unknown"


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


def test_strategy_monitor_scheduler_run_once_records_result(monkeypatch) -> None:
    scheduler = StrategyMonitorScheduler(
        enabled_by_env=False,
        poll_interval_seconds=10,
        refresh=False,
    )

    def fake_scan_strategy_monitors(*, refresh: bool, force: bool):
        assert refresh is False
        assert force is True
        return scan_strategy_monitors(refresh=False, force=True)

    monkeypatch.setattr(
        "app.services.strategy_monitor_scheduler.scan_strategy_monitors",
        fake_scan_strategy_monitors,
    )

    import asyncio

    result = asyncio.run(scheduler.run_once(force=True))
    status = scheduler.status()

    assert result is not None
    assert status.last_run_at is not None
    assert status.last_error is None
    assert status.last_result["scanned_count"] == 0
    assert status.running is False


def test_strategy_monitor_scheduler_reads_environment(monkeypatch) -> None:
    scheduler = get_strategy_monitor_scheduler()
    original = scheduler.status()
    monkeypatch.setenv("STRATEGY_MONITOR_SCHEDULER_ENABLED", "true")
    monkeypatch.setenv("STRATEGY_MONITOR_SCHEDULER_INTERVAL_SECONDS", "5")
    monkeypatch.setenv("STRATEGY_MONITOR_SCHEDULER_REFRESH", "true")

    configure_strategy_monitor_scheduler_from_env()
    status = scheduler.status()

    assert status.enabled_by_env is True
    assert status.poll_interval_seconds == 10
    assert status.refresh is True

    scheduler.enabled_by_env = original.enabled_by_env
    scheduler.poll_interval_seconds = original.poll_interval_seconds
    scheduler.refresh = original.refresh


def test_strategy_monitor_scheduler_endpoints_start_stop() -> None:
    client = TestClient(app)

    try:
        start_response = client.post(
            "/api/v1/strategies/monitors/scheduler/start",
            json={"poll_interval_seconds": 10, "refresh": False},
        )
        status_response = client.get("/api/v1/strategies/monitors/scheduler/status")
    finally:
        stop_response = client.post("/api/v1/strategies/monitors/scheduler/stop")

    assert start_response.status_code == 200
    assert start_response.json()["running"] is True
    assert status_response.status_code == 200
    assert status_response.json()["poll_interval_seconds"] == 10
    assert stop_response.status_code == 200
    assert stop_response.json()["running"] is False


def test_strategy_monitor_scheduler_status_reports_monitor_health() -> None:
    client = TestClient(app)
    database.create_strategy_monitor(
        StrategyMonitorCreate(
            market="HK",
            code="HK.09988",
            name="Alibaba",
            strategy_code="ma_cross",
            strategy_name="MA Cross",
            parameters={"short_window": 3, "long_window": 7},
            enabled=True,
            scan_interval_minutes=15,
        ),
    )

    response = client.get("/api/v1/strategies/monitors/scheduler/status")

    assert response.status_code == 200
    body = response.json()
    assert body["enabled_monitor_count"] == 1
    assert body["due_monitor_count"] == 1
    assert body["next_run_at"] is not None


def test_strategy_monitor_scheduler_run_once_endpoint_updates_status() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/v1/strategies/monitors/scheduler/run-once?force=true",
        json={"poll_interval_seconds": 10, "refresh": False},
    )

    assert response.status_code == 200
    assert response.json()["last_run_at"] is not None
    assert response.json()["last_result"]["scanned_count"] == 0


def test_strategy_monitor_scheduler_can_be_configured_without_starting() -> None:
    scheduler = StrategyMonitorScheduler(
        enabled_by_env=False,
        poll_interval_seconds=60,
        refresh=False,
    )

    scheduler.configure(
        StrategyMonitorSchedulerUpdate(
            poll_interval_seconds=30,
            refresh=True,
        ),
    )

    status = scheduler.status()
    assert status.running is False
    assert status.poll_interval_seconds == 30
    assert status.refresh is True
