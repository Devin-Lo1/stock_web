from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.main import app
from app.schemas import BacktestResult


def test_batch_backtest_runs_each_item(monkeypatch) -> None:
    def fake_run_backtest(run):
        completed = run.model_copy(
            update={
                "status": "completed",
                "summary": {"total_return": 0.12, "max_drawdown": -0.03},
                "updated_at": datetime.now(UTC),
            }
        )
        return BacktestResult(run=completed, equity_curve=[], trades=[])

    monkeypatch.setattr("app.routers.backtests.run_backtest", fake_run_backtest)
    client = TestClient(app)

    response = client.post(
        "/api/v1/backtests/batch",
        json={
            "items": [
                _payload("HK.02628", 5, 20),
                _payload("US.NVDA", 8, 30),
            ],
            "continue_on_error": True,
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["total_count"] == 2
    assert body["completed_count"] == 2
    assert body["failed_count"] == 0
    assert body["results"][0]["run"]["stock_code"] == "HK.02628"
    assert body["results"][1]["run"]["parameters"] == {
        "short_window": 8,
        "long_window": 30,
    }


def test_batch_backtest_accepts_at_most_50_items() -> None:
    client = TestClient(app)
    response = client.post(
        "/api/v1/backtests/batch",
        json={"items": [_payload("HK.02628", 5, 20) for _ in range(51)]},
    )

    assert response.status_code == 422


def _payload(stock_code: str, short_window: int, long_window: int) -> dict:
    return {
        "strategy_code": "ma_cross",
        "stock_code": stock_code,
        "period": "day",
        "start_date": "2025-01-01",
        "end_date": "2026-05-27",
        "initial_cash": 100000,
        "fee_rate": 0.0003,
        "slippage_rate": 0.0005,
        "parameters": {
            "short_window": short_window,
            "long_window": long_window,
        },
    }
