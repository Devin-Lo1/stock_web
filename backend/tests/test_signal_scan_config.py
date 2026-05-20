from datetime import datetime, timedelta, timezone

from app import database
from app.schemas import Candle, PositionCreate
from app.services import signal_scanner
from app.services.signal_scan_config import SignalScanConfig, list_signal_scan_configs


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


def test_signal_scanner_can_use_custom_ma_cross_config(monkeypatch) -> None:
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

    monkeypatch.setattr(
        signal_scanner,
        "list_signal_scan_configs",
        lambda: [
            SignalScanConfig(
                strategy_code="ma_cross",
                strategy_name="MA Cross",
                parameters={"short_window": 3, "long_window": 7},
            ),
        ],
    )

    result = signal_scanner.scan_strategy_signals(refresh=False)

    assert result.created_count == 1
    event = result.events[0]
    assert event.signal_type == "ma_cross_buy"
    assert event.payload["parameters"] == {"short_window": 3, "long_window": 7}
    assert event.payload["condition_label"] == "MA3 上穿 MA7"
