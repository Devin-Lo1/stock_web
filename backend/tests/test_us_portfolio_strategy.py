from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app import database
from app.main import app
from app.schemas import PositionCreate, QuoteSnapshot
from app.services.us_portfolio_strategy import build_us_portfolio_strategy


def test_us_portfolio_strategy_uses_current_us_holdings() -> None:
    _seed_current_us_holdings()

    result = build_us_portfolio_strategy(cash=634.13)
    suggestion_codes = {item.reason_code for item in result.suggestions}

    assert result.total_market_value == pytest.approx(24044.4524)
    assert result.total_equity == pytest.approx(24678.5824)
    assert result.core_weight == pytest.approx(54.1287, rel=1e-4)
    assert result.leverage_weight == pytest.approx(9.5346, rel=1e-4)
    assert result.semiconductor_weight == pytest.approx(41.5766, rel=1e-4)
    assert "CORE_BELOW_MINIMUM" in suggestion_codes
    assert "LEVERAGE_OVER_HARD_LIMIT" in suggestion_codes
    assert "SEMICONDUCTOR_OVER_WARNING_LIMIT" in suggestion_codes
    assert "LEVERAGED_PROFIT_TAKE" in suggestion_codes
    assert all(item.requires_user_confirmation for item in result.suggestions)
    assert all(not item.auto_execute for item in result.suggestions)


def test_us_portfolio_strategy_endpoint() -> None:
    _seed_current_us_holdings()

    client = TestClient(app)
    response = client.get("/api/v1/portfolio-strategy/us?cash=634.13")
    payload = response.json()

    assert response.status_code == 200
    assert payload["market"] == "US"
    assert payload["currency"] == "USD"
    assert len(payload["assets"]) == 8
    assert {item["code"] for item in payload["assets"]} == {
        "US.GOOG",
        "US.LITE",
        "US.MU",
        "US.MUU",
        "US.QQQM",
        "US.SGOV",
        "US.VOO",
        "US.WDC",
    }
    assert any(
        item["reason_code"] == "LEVERAGE_OVER_HARD_LIMIT"
        for item in payload["suggestions"]
    )


def _seed_current_us_holdings() -> None:
    rows = [
        ("US.GOOG", "Alphabet", 3, 355.7199, 353.37),
        ("US.LITE", "Lumentum Holdings", 2, 878.3399, 840.135),
        ("US.MU", "Micron Technology", 4, 991.1255, 1181.675),
        ("US.MUU", "Direxion Daily MU", 2, 589.3464, 1176.51),
        ("US.QQQM", "Invesco NASDAQ 100 ETF", 12, 291.2513, 306.345),
        ("US.SGOV", "iShares 0-3 Month Treasury", 35, 100.479, 100.5995),
        ("US.VOO", "Vanguard S&P 500 ETF", 8, 671.4244, 690.84),
        ("US.WDC", "Western Digital Corp", 2, 778.3999, 750.255),
    ]
    for code, name, quantity, cost_price, current_price in rows:
        database.create_position(
            PositionCreate(
                market="US",
                code=code,
                name=name,
                quantity=quantity,
                cost_price=cost_price,
                currency="USD",
            ),
        )
        database.upsert_quote(
            QuoteSnapshot(
                code=code,
                market="US",
                currency="USD",
                current_price=current_price,
                previous_close=current_price,
                open=current_price,
                high=current_price,
                low=current_price,
                volume=1000,
                turnover=current_price * 1000,
                change=0,
                change_rate=0,
                quote_time=datetime(2026, 6, 22, tzinfo=timezone.utc),
            ),
        )
