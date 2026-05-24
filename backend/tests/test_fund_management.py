from datetime import date, datetime, timezone

from app.repositories.funds import (
    create_fund_position,
    create_fund_trade_for_position,
    get_fund_position,
    list_fund_trades,
    upsert_fund_navs,
)
from app.repositories.fund_alert_scheduler import (
    get_fund_alert_scheduler_config,
    update_fund_alert_scheduler_config,
)
from app.schemas import (
    FundAlertSchedulerUpdate,
    FundNavPoint,
    FundPositionCreate,
    FundQuote,
    FundTradeCreate,
)
from app.services.fund_alert_scanner import scan_fund_alerts
from app.services import fund_provider
from app.services.fund_provider import EastmoneyFundProvider
from app.services.funds import _build_fund_summary, list_fund_position_summaries
from app.db.converters import _now


def test_fund_position_buy_sell_and_summary() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000001",
            name="Huaxia Growth",
            fund_type="mixed",
            shares=1000,
            cost_nav=1.2,
            fee=1,
            trade_date=date(2026, 5, 20),
        ),
    )

    assert position.shares == 1000
    assert round(position.invested_amount, 2) == 1201

    create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="sell",
            shares=200,
            nav=1.5,
            fee=1,
            trade_date=date(2026, 5, 22),
        ),
    )
    updated = get_fund_position(position.id)
    assert updated is not None
    assert updated.shares == 800
    assert updated.realized_profit > 0

    upsert_fund_navs(
        [
            FundNavPoint(
                fund_code="000001",
                nav_date=date(2026, 5, 22),
                unit_nav=1.4,
                accumulated_nav=2.1,
                daily_growth_rate=1.2,
                subscribe_status="open",
                redeem_status="open",
                updated_at=_now(),
            ),
        ],
    )

    summaries = list_fund_position_summaries(refresh=False)

    assert len(summaries) == 1
    assert summaries[0].position.id == position.id
    assert round(summaries[0].market_value, 2) == 1120
    assert summaries[0].latest_nav is not None
    assert summaries[0].latest_nav.unit_nav == 1.4


def test_fund_trades_can_be_listed_by_position() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="012414",
            name="招商中证白酒指数(LOF)C",
            fund_type="index",
            shares=500,
            cost_nav=0.8,
        ),
    )

    trades = list_fund_trades(position_id=position.id)

    assert len(trades) == 1
    assert trades[0].action == "buy"
    assert trades[0].fund_code == "012414"


def test_fund_summary_uses_estimate_until_official_nav_updates() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000001",
            name="Huaxia Growth",
            fund_type="mixed",
            shares=1000,
            cost_nav=1.2,
        ),
    )
    latest = FundNavPoint(
        fund_code="000001",
        nav_date=date(2026, 5, 21),
        unit_nav=1.2,
        accumulated_nav=2.1,
        daily_growth_rate=0.5,
        updated_at=_now(),
    )
    quote = FundQuote(
        fund_code="000001",
        name="Huaxia Growth",
        nav_date=date(2026, 5, 21),
        unit_nav=1.2,
        estimated_nav=1.26,
        estimated_change_rate=5,
        estimate_time=datetime(2026, 5, 22, 15, 0, tzinfo=timezone.utc),
    )

    summary = _build_fund_summary(position, latest, quote)

    assert summary.valuation_mode == "estimated"
    assert summary.display_nav == 1.26
    assert round(summary.day_profit, 2) == 60

    official = latest.model_copy(update={"nav_date": date(2026, 5, 22), "unit_nav": 1.25})
    final_summary = _build_fund_summary(position, official, quote)

    assert final_summary.valuation_mode == "official"
    assert final_summary.display_nav == 1.25


def test_fund_summary_recommends_grid_action_from_last_trade_nav() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000001",
            name="Huaxia Growth",
            fund_type="mixed",
            shares=1000,
            cost_nav=1.0,
        ),
    )
    latest = FundNavPoint(
        fund_code="000001",
        nav_date=date(2026, 5, 22),
        unit_nav=1.06,
        accumulated_nav=2.1,
        daily_growth_rate=1,
        updated_at=_now(),
    )

    summary = _build_fund_summary(
        position,
        latest,
        last_trade=list_fund_trades(position_id=position.id, limit=1)[0],
    )

    assert summary.grid_recommendation is not None
    assert summary.grid_recommendation.action == "sell"
    assert summary.grid_recommendation.action_label == "减仓 1/4"
    assert summary.grid_recommendation.recommended_shares == 250

    buy_summary = _build_fund_summary(
        position,
        latest.model_copy(update={"unit_nav": 0.94}),
        last_trade=list_fund_trades(position_id=position.id, limit=1)[0],
    )

    assert buy_summary.grid_recommendation is not None
    assert buy_summary.grid_recommendation.action == "buy"
    assert buy_summary.grid_recommendation.recommended_amount == 5000


def test_fund_alert_scheduler_config_accepts_multiple_times() -> None:
    config = update_fund_alert_scheduler_config(
        FundAlertSchedulerUpdate(
            enabled=True,
            reminder_times=["14:30", "14:50", "bad", "9:25"],
            due_window_minutes=15,
        ),
    )

    assert config.enabled is True
    assert config.reminder_times == ["09:25", "14:30", "14:50"]
    assert config.due_window_minutes == 15

    stored = get_fund_alert_scheduler_config()
    assert stored.reminder_times == ["09:25", "14:30", "14:50"]


def test_scan_fund_alerts_creates_signal_event_from_grid_recommendation() -> None:
    create_fund_position(
        FundPositionCreate(
            fund_code="000001",
            name="Huaxia Growth",
            fund_type="mixed",
            shares=1000,
            cost_nav=1.0,
            alert_enabled=True,
            alert_threshold_percent=5,
            alert_sell_ratio=0.25,
        ),
    )
    upsert_fund_navs(
        [
            FundNavPoint(
                fund_code="000001",
                nav_date=date(2026, 5, 22),
                unit_nav=1.06,
                accumulated_nav=2.1,
                daily_growth_rate=6,
                updated_at=_now(),
            ),
        ],
    )

    result = scan_fund_alerts(
        refresh=False,
        scan_key="2026-05-23:14:30",
        dispatch_push=False,
    )
    duplicate = scan_fund_alerts(
        refresh=False,
        scan_key="2026-05-23:14:30",
        dispatch_push=False,
    )

    assert result.scanned_count == 1
    assert result.created_count == 1
    assert result.events[0].signal_type == "fund_grid_sell"
    assert result.events[0].payload["source_category"] == "fund"
    assert result.events[0].payload["strategy_name"] == "基金涨跌提醒"
    assert duplicate.created_count == 0


def test_fund_provider_search_ignores_system_proxy_and_caches(monkeypatch) -> None:
    EastmoneyFundProvider._search_cache.clear()
    EastmoneyFundProvider._nav_cache.clear()
    EastmoneyFundProvider._quote_cache.clear()
    calls: list[dict[str, object]] = []

    class FakeResponse:
        content = (
            b'{"Datas":[{"CODE":"000001","NAME":"Fake Fund",'
            b'"FundBaseInfo":{"FTYPE":"mixed","JJGS":"Fake Co","JJJL":"Fake Manager"}}]}'
        )

        def raise_for_status(self) -> None:
            return None

    def fake_get(*args, **kwargs):
        calls.append(kwargs)
        return FakeResponse()

    monkeypatch.setattr(fund_provider.httpx, "get", fake_get)

    provider = EastmoneyFundProvider()
    first = provider.search("000001", limit=20)
    second = provider.search("000001", limit=20)

    assert len(first) == 1
    assert len(second) == 1
    assert len(calls) == 1
    assert calls[0]["trust_env"] is False
