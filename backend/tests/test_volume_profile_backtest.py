from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.main import app
from app.schemas import Candle


def test_volume_profile_backtest_uses_previous_day_profile(monkeypatch) -> None:
    candles = [
        _candle(datetime(2026, 5, 4, 9, 30, tzinfo=UTC), 100.0, 100.3, 99.8, 100.1, 1000),
        _candle(datetime(2026, 5, 4, 9, 31, tzinfo=UTC), 100.1, 100.4, 99.9, 100.2, 1400),
        _candle(datetime(2026, 5, 4, 9, 32, tzinfo=UTC), 100.2, 100.5, 100.0, 100.3, 900),
        _candle(datetime(2026, 5, 5, 9, 30, tzinfo=UTC), 101.0, 101.1, 100.6, 100.8, 700),
        _candle(datetime(2026, 5, 5, 9, 31, tzinfo=UTC), 100.8, 100.9, 100.2, 100.4, 900),
    ]

    monkeypatch.setattr(
        "app.backtest.volume_profile.request_history_klines_all",
        lambda **_: candles,
    )
    client = TestClient(app)

    response = client.post(
        "/api/v1/backtests/volume-profile",
        json={
            "stock_code": "US.TEST",
            "start_date": "2026-05-05",
            "end_date": "2026-05-05",
            "deviation_threshold": 5,
            "bucket_count": 40,
            "value_area_ratio": 0.68,
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["summary"]["total_days"] == 1
    assert body["summary"]["success_count"] == 1
    assert body["signals"][0]["direction"] == "short"
    assert body["signals"][0]["outcome"] == "success"
    assert body["chart_profile"]["poc"] > 0
    assert len(body["chart_profile"]["buckets"]) == 40
    assert len(body["chart_candles"]) == len(candles)


def _candle(
    timestamp: datetime,
    open_price: float,
    high: float,
    low: float,
    close: float,
    volume: float,
) -> Candle:
    return Candle(
        code="US.TEST",
        market="US",
        period="1m",
        time=timestamp,
        open=open_price,
        high=high,
        low=low,
        close=close,
        volume=volume,
        turnover=volume * close,
    )
