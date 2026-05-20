from datetime import datetime, timedelta, timezone

from app import database
from app.main import app
from app.schemas import Candle, PositionCreate, SignalScanConfigCreate
from app.services.signal_scan_config import list_signal_scan_configs
from app.services.signal_scanner import scan_strategy_signals
from fastapi.testclient import TestClient


def test_default_signal_scan_configs_are_externalized() -> None:
    configs = list_signal_scan_configs()

    assert [config.strategy_code for config in configs] == [
        "price_break_ma",
        "price_break_ma",
        "price_break_ma",
        "ma_cross",
        "rsi_reversal",
        "macd_trend",
    ]
    assert configs[0].parameters == {"ma_window": 5, "direction": "both"}


def test_signal_scan_config_parameters_are_copied() -> None:
    configs = list_signal_scan_configs()
    configs[0].parameters["ma_window"] = 99

    assert list_signal_scan_configs()[0].parameters["ma_window"] == 5


def test_signal_scanner_can_use_persisted_ma_cross_config() -> None:
    database.create_signal_scan_config(
        SignalScanConfigCreate(
            strategy_code="ma_cross",
            strategy_name="MA Cross",
            parameters={"short_window": 3, "long_window": 7},
            sort_order=1,
        ),
    )
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

    result = scan_strategy_signals(refresh=False)

    assert result.created_count == 1
    event = result.events[0]
    assert event.signal_type == "ma_cross_buy"
    assert event.payload["parameters"] == {"short_window": 3, "long_window": 7}
    assert event.payload["condition_label"] == "MA3 上穿 MA7"


def test_signal_scan_config_endpoints_reset_update_and_create() -> None:
    client = TestClient(app)

    reset_response = client.post("/api/v1/signals/configs/reset-defaults")
    update_response = client.put(
        "/api/v1/signals/configs/ma_cross_5_20",
        json={
            "parameters": {"short_window": 3, "long_window": 7},
            "enabled": False,
        },
    )
    enabled_response = client.get("/api/v1/signals/configs?enabled_only=true")
    create_response = client.post(
        "/api/v1/signals/configs",
        json={
            "strategy_code": "ma_cross",
            "strategy_name": "MA Cross",
            "parameters": {"short_window": 3, "long_window": 7},
            "enabled": True,
            "push_candidate": False,
            "sort_order": 5,
        },
    )

    assert reset_response.status_code == 200
    assert len(reset_response.json()) == 6
    assert update_response.status_code == 200
    updated = update_response.json()
    assert updated["id"] == "ma_cross_5_20"
    assert updated["parameters"] == {"short_window": 3, "long_window": 7}
    assert updated["enabled"] is False
    enabled_ids = {item["id"] for item in enabled_response.json()}
    assert "ma_cross_5_20" not in enabled_ids
    assert create_response.status_code == 201
    created = create_response.json()
    assert created["parameters"] == {"short_window": 3, "long_window": 7}
    assert created["push_candidate"] is False
