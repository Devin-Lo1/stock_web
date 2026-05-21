from app import database
from app.main import app
from datetime import datetime, timedelta, timezone

from app.schemas import (
    Candle,
    NotificationDeviceUpsert,
    PositionCreate,
    PushRecordCreate,
    SignalEventCreate,
)
from app.services import push_service
from fastapi.testclient import TestClient


def test_signal_event_create_list_and_mark_read() -> None:
    event = database.create_signal_event(
        SignalEventCreate(
            source="scanner",
            code="HK.02628",
            signal_type="stop_loss_watch",
            level="warning",
            title="中国人寿触发观察信号",
            message="价格接近止损线，请打开 App 查看。",
            trigger_value=12.34,
            threshold_value=12.5,
            dedupe_key="HK.02628:stop_loss_watch:2026-05-17",
            payload={"position_id": "position-1"},
        ),
    )

    assert event.read_status == "unread"
    assert event.read_at is None
    assert event.payload["position_id"] == "position-1"

    rows = database.list_signal_events(code="hk.02628")
    assert [row.id for row in rows] == [event.id]

    read = database.mark_signal_event_read(event.id)
    assert read is not None
    assert read.read_status == "read"
    assert read.read_at is not None


def test_notification_device_upsert_refreshes_existing_token() -> None:
    first = database.upsert_notification_device(
        NotificationDeviceUpsert(
            platform="android",
            push_provider="fcm",
            push_token="token-1",
            device_name="test phone",
            app_version="1.0.0",
        ),
    )
    second = database.upsert_notification_device(
        NotificationDeviceUpsert(
            platform="android",
            push_provider="fcm",
            push_token="token-1",
            device_name="test phone new",
            app_version="1.0.1",
            enabled=False,
        ),
    )

    assert second.id == first.id
    assert second.device_name == "test phone new"
    assert second.app_version == "1.0.1"
    assert second.enabled is False

    devices = database.list_notification_devices()
    assert [device.id for device in devices] == [first.id]
    assert database.list_notification_devices(enabled_only=True) == []


def test_push_record_create_and_list() -> None:
    event = database.create_signal_event(
        SignalEventCreate(
            code="HK.09988",
            signal_type="strategy_buy",
            level="important",
            title="阿里巴巴触发买入观察",
            message="策略信号由无变为买入观察。",
            dedupe_key="HK.09988:strategy_buy:2026-05-17",
        ),
    )
    device = database.upsert_notification_device(
        NotificationDeviceUpsert(
            platform="android",
            push_provider="fcm",
            push_token="token-2",
        ),
    )

    record = database.create_push_record(
        PushRecordCreate(
            signal_event_id=event.id,
            device_id=device.id,
            provider="fcm",
            status="queued",
            request_payload={"message": {"token": "token-2"}},
        ),
    )

    rows = database.list_push_records(signal_event_id=event.id)
    assert [row.id for row in rows] == [record.id]
    assert rows[0].device_id == device.id
    assert rows[0].request_payload["message"]["token"] == "token-2"


def test_notification_device_and_test_endpoints() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/v1/notifications/devices",
        json={
            "platform": "android",
            "push_provider": "unknown",
            "push_token": "local-token",
            "device_name": "test phone",
            "app_version": "0.1.0",
            "enabled": True,
            "important_enabled": True,
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["device"]["push_token"] == "local-token"

    test_response = client.post(
        "/api/v1/notifications/test",
        json={"device_id": body["device"]["id"]},
    )

    assert test_response.status_code == 201
    record = test_response.json()
    assert record["status"] == "skipped"
    assert record["error_message"] == "真实推送通道尚未配置"


def test_notification_test_endpoint_sends_fcm_when_provider_is_configured(
    monkeypatch,
) -> None:
    client = TestClient(app)

    def fake_send_fcm_message(**kwargs):
        assert kwargs["token"] == "fcm-token"
        assert kwargs["data"]["source"] == "notification_test"
        return {"message_id": "projects/test/messages/1"}

    monkeypatch.setattr(push_service, "send_fcm_message", fake_send_fcm_message)

    response = client.post(
        "/api/v1/notifications/devices",
        json={
            "platform": "android",
            "push_provider": "fcm",
            "push_token": "fcm-token",
            "device_name": "test phone",
            "app_version": "0.1.0",
            "enabled": True,
            "important_enabled": True,
        },
    )

    assert response.status_code == 201
    device_id = response.json()["device"]["id"]

    test_response = client.post(
        "/api/v1/notifications/test",
        json={"device_id": device_id},
    )

    assert test_response.status_code == 201
    record = test_response.json()
    assert record["status"] == "sent"
    assert record["provider"] == "fcm"
    assert record["attempt_count"] == 1
    assert record["response_payload"]["message_id"] == "projects/test/messages/1"
    assert "token" not in str(record["request_payload"]).lower()


def test_notification_test_endpoint_sends_huawei_when_provider_is_configured(
    monkeypatch,
) -> None:
    client = TestClient(app)

    def fake_send_huawei_message(**kwargs):
        assert kwargs["token"] == "huawei-token"
        assert kwargs["data"]["source"] == "notification_test"
        return {"code": "80000000", "msg": "Success"}

    monkeypatch.setattr(push_service, "send_huawei_message", fake_send_huawei_message)

    response = client.post(
        "/api/v1/notifications/devices",
        json={
            "platform": "android",
            "push_provider": "huawei",
            "push_token": "huawei-token",
            "device_name": "test phone",
            "app_version": "0.1.0",
            "enabled": True,
            "important_enabled": True,
        },
    )

    assert response.status_code == 201
    device_id = response.json()["device"]["id"]

    test_response = client.post(
        "/api/v1/notifications/test",
        json={"device_id": device_id},
    )

    assert test_response.status_code == 201
    record = test_response.json()
    assert record["status"] == "sent"
    assert record["provider"] == "huawei"
    assert record["attempt_count"] == 1
    assert record["response_payload"]["code"] == "80000000"
    assert "token" not in str(record["request_payload"]).lower()


def test_dispatch_signal_event_endpoint_sends_push_candidate_once(monkeypatch) -> None:
    client = TestClient(app)
    calls: list[dict[str, object]] = []

    def fake_send_fcm_message(**kwargs):
        calls.append(kwargs)
        assert kwargs["token"] == "fcm-token"
        data = kwargs["data"]
        assert data["signal_event_id"]
        assert data["code"] == "HK.09988"
        assert data["signal_type"] == "ma_cross_buy"
        assert data["strategy_code"] == "ma_cross"
        assert data["monitor_id"] == "monitor-1"
        assert "position_id" not in data
        assert "parameters" not in data
        return {"message_id": "projects/test/messages/strategy-1"}

    monkeypatch.setattr(push_service, "send_fcm_message", fake_send_fcm_message)
    database.upsert_notification_device(
        NotificationDeviceUpsert(
            platform="android",
            push_provider="fcm",
            push_token="fcm-token",
            important_enabled=True,
        ),
    )
    event = database.create_signal_event(
        SignalEventCreate(
            source="strategy_monitor",
            code="HK.09988",
            signal_type="ma_cross_buy",
            level="important",
            title="Alibaba MA Cross observation",
            message="MA3 crossed above MA7.",
            dedupe_key="strategy_monitor:monitor-1:ma_cross:buy:2026-05-21",
            payload={
                "source_category": "strategy",
                "strategy_code": "ma_cross",
                "monitor_id": "monitor-1",
                "position_id": "position-1",
                "parameters": {"short_window": 3, "long_window": 7},
                "push_candidate": True,
            },
        ),
    )

    response = client.post(f"/api/v1/notifications/signals/{event.id}/dispatch")
    duplicate_response = client.post(f"/api/v1/notifications/signals/{event.id}/dispatch")

    assert response.status_code == 200
    body = response.json()
    assert body["attempted_count"] == 1
    assert body["created_count"] == 1
    assert body["sent_count"] == 1
    assert body["records"][0]["status"] == "sent"
    assert duplicate_response.json()["created_count"] == 0
    assert duplicate_response.json()["sent_count"] == 1
    assert len(calls) == 1


def test_dispatch_signal_event_skips_when_candidate_disabled() -> None:
    client = TestClient(app)
    database.upsert_notification_device(
        NotificationDeviceUpsert(
            platform="android",
            push_provider="unknown",
            push_token="local-token",
        ),
    )
    event = database.create_signal_event(
        SignalEventCreate(
            source="strategy_monitor",
            code="HK.09988",
            signal_type="ma_cross_buy",
            level="important",
            title="Alibaba MA Cross observation",
            message="MA3 crossed above MA7.",
            dedupe_key="strategy_monitor:monitor-1:ma_cross:buy:disabled",
            payload={"push_candidate": False},
        ),
    )

    response = client.post(f"/api/v1/notifications/signals/{event.id}/dispatch")

    assert response.status_code == 200
    assert response.json()["reason"] == "push_candidate_disabled"
    assert response.json()["attempted_count"] == 0
    assert database.list_push_records(signal_event_id=event.id) == []


def test_dispatch_signal_event_respects_device_important_switch(monkeypatch) -> None:
    client = TestClient(app)

    def fake_send_fcm_message(**kwargs):
        raise AssertionError("provider should not be called when important switch is off")

    monkeypatch.setattr(push_service, "send_fcm_message", fake_send_fcm_message)
    device = database.upsert_notification_device(
        NotificationDeviceUpsert(
            platform="android",
            push_provider="fcm",
            push_token="fcm-token",
            important_enabled=False,
        ),
    )
    event = database.create_signal_event(
        SignalEventCreate(
            source="strategy_monitor",
            code="HK.09988",
            signal_type="ma_cross_sell",
            level="important",
            title="Alibaba MA Cross observation",
            message="MA3 crossed below MA7.",
            dedupe_key="strategy_monitor:monitor-1:ma_cross:sell:2026-05-21",
            payload={"push_candidate": True},
        ),
    )

    response = client.post(f"/api/v1/notifications/signals/{event.id}/dispatch")

    assert response.status_code == 200
    body = response.json()
    assert body["attempted_count"] == 1
    assert body["created_count"] == 1
    assert body["skipped_count"] == 1
    assert body["records"][0]["device_id"] == device.id
    assert body["records"][0]["error_message"] == "important_notifications_disabled"


def test_notification_test_endpoint_skips_reserved_vendor_provider() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/v1/notifications/devices",
        json={
            "platform": "android",
            "push_provider": "xiaomi",
            "push_token": "xiaomi-token",
            "device_name": "test phone",
            "app_version": "0.1.0",
            "enabled": True,
            "important_enabled": True,
        },
    )

    assert response.status_code == 201
    device_id = response.json()["device"]["id"]

    test_response = client.post(
        "/api/v1/notifications/test",
        json={"device_id": device_id},
    )

    assert test_response.status_code == 201
    record = test_response.json()
    assert record["status"] == "skipped"
    assert record["provider"] == "xiaomi"
    assert record["error_message"] == "真实推送通道尚未配置: xiaomi"


def test_signal_scan_endpoint_creates_explainable_strategy_event() -> None:
    client = TestClient(app)
    database.create_position(
        PositionCreate(
            market="HK",
            code="HK.09988",
            name="阿里巴巴",
            quantity=100,
            cost_price=90,
            currency="HKD",
        ),
    )
    start = datetime(2026, 5, 1, tzinfo=timezone.utc)
    closes = [10, 10, 10, 10, 10, 8]
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

    response = client.post("/api/v1/signals/scan?refresh=false")
    second_response = client.post("/api/v1/signals/scan?refresh=false")
    events_response = client.get("/api/v1/signals/events")

    assert response.status_code == 200
    body = response.json()
    assert body["created_count"] == 1
    event = body["events"][0]
    assert event["source"] == "strategy_scanner"
    assert event["signal_type"] == "price_break_ma_sell"
    assert event["payload"]["strategy_code"] == "price_break_ma"
    assert event["payload"]["condition_label"] == "收盘价跌破 MA5"
    assert event["trigger_value"] == 8
    assert event["threshold_value"] > 0
    assert second_response.json()["created_count"] == 0
    assert events_response.json()[0]["id"] == event["id"]


def test_signal_events_endpoint_filters_categories_and_ignored_status() -> None:
    client = TestClient(app)
    strategy = database.create_signal_event(
        SignalEventCreate(
            source="strategy_scanner",
            code="HK.09988",
            signal_type="ma_cross_buy",
            level="important",
            title="阿里巴巴触发 MA Cross 观察",
            message="MA3 上穿 MA7",
            trigger_value=12,
            threshold_value=11,
            dedupe_key="HK.09988:ma_cross:buy:2026-05-20",
            payload={
                "source_category": "strategy",
                "strategy_code": "ma_cross",
                "push_candidate": True,
            },
            triggered_at=datetime(2026, 5, 20, tzinfo=timezone.utc),
        ),
    )
    risk = database.create_signal_event(
        SignalEventCreate(
            source="risk",
            code="HK.00700",
            signal_type="stop_loss_watch",
            level="warning",
            title="腾讯控股触发风控观察",
            message="接近止损线",
            dedupe_key="HK.00700:risk:2026-05-20",
            payload={"source_category": "risk", "push_candidate": False},
            triggered_at=datetime(2026, 5, 20, tzinfo=timezone.utc),
        ),
    )
    system = database.create_signal_event(
        SignalEventCreate(
            source="test",
            code="TEST",
            signal_type="notification_test",
            level="info",
            title="测试提醒",
            message="通知链路测试",
            dedupe_key="TEST:system:2026-05-20",
            payload={"source_category": "system", "push_candidate": False},
            triggered_at=datetime(2026, 5, 20, tzinfo=timezone.utc),
        ),
    )

    ignored_response = client.put(f"/api/v1/signals/events/{risk.id}/ignore")
    strategy_response = client.get(
        "/api/v1/signals/events?source_category=strategy&strategy_code=ma_cross",
    )
    signal_type_response = client.get(
        "/api/v1/signals/events?signal_type=ma_cross_buy",
    )
    important_response = client.get("/api/v1/signals/events?level=important")
    push_response = client.get("/api/v1/signals/events?push_candidate=true")
    system_response = client.get("/api/v1/signals/events?source_category=system")
    ignored_list_response = client.get("/api/v1/signals/events?read_status=ignored")

    assert ignored_response.status_code == 200
    assert ignored_response.json()["read_status"] == "ignored"
    assert [item["id"] for item in strategy_response.json()] == [strategy.id]
    assert [item["id"] for item in signal_type_response.json()] == [strategy.id]
    assert [item["id"] for item in important_response.json()] == [strategy.id]
    assert [item["id"] for item in push_response.json()] == [strategy.id]
    assert [item["id"] for item in system_response.json()] == [system.id]
    assert [item["id"] for item in ignored_list_response.json()] == [risk.id]
