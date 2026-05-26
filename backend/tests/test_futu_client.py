from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.services.futu_client import (
    FutuOpenDError,
    _active_us_extended_session,
    _capital_bucket,
    _currency_from_code,
    _ensure_futu_port_available,
    _market_from_code,
    _row_to_capital_flow_point,
)


US_EASTERN = ZoneInfo("America/New_York")


@pytest.mark.parametrize(
    ("code", "market", "currency"),
    [
        ("HK.00700", "HK", "HKD"),
        ("US.AAPL", "US", "USD"),
        ("SH.510300", "SH", "CNY"),
        ("SZ.159919", "SZ", "CNY"),
    ],
)
def test_futu_market_and_currency_mapping(
    code: str,
    market: str,
    currency: str,
) -> None:
    assert _market_from_code(code) == market
    assert _currency_from_code(code) == currency


def test_futu_market_mapping_rejects_unknown_prefix() -> None:
    with pytest.raises(FutuOpenDError):
        _market_from_code("OF.000001")


def test_futu_port_precheck_fails_fast(monkeypatch) -> None:
    def fake_create_connection(*args, **kwargs):
        raise OSError("connection refused")

    monkeypatch.setattr("socket.create_connection", fake_create_connection)

    with pytest.raises(FutuOpenDError, match="FutuOpenD is not reachable"):
        _ensure_futu_port_available()


@pytest.mark.parametrize(
    ("hour", "minute", "session"),
    [
        (3, 59, "overnight"),
        (4, 0, "pre"),
        (9, 29, "pre"),
        (9, 30, ""),
        (15, 59, ""),
        (16, 0, "after"),
        (19, 59, "after"),
        (20, 0, "overnight"),
    ],
)
def test_active_us_extended_session(hour: int, minute: int, session: str) -> None:
    now = datetime(2026, 5, 26, hour, minute, tzinfo=US_EASTERN)
    assert _active_us_extended_session(now) == session


def test_active_us_extended_session_ignores_weekends() -> None:
    now = datetime(2026, 5, 30, 10, 0, tzinfo=US_EASTERN)
    assert _active_us_extended_session(now) == ""


def test_capital_flow_helpers_parse_futu_rows() -> None:
    bucket = _capital_bucket(
        {
            "capital_in_big": "1200.5",
            "capital_out_big": 300,
        },
        "big",
    )

    assert bucket.bucket == "big"
    assert bucket.inflow == 1200.5
    assert bucket.net_inflow == 900.5

    point = _row_to_capital_flow_point(
        {
            "capital_flow_item_time": "2026-05-22 16:00:00",
            "in_flow": 100,
            "super_in_flow": 60,
            "big_in_flow": 30,
            "mid_in_flow": 20,
            "sml_in_flow": -10,
        },
    )

    assert point.time.year == 2026
    assert point.net_inflow == 100
    assert point.small_net_inflow == -10
