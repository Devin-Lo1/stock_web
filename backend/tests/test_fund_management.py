from datetime import date, datetime, timezone

from app.repositories.funds import (
    create_fund_position,
    create_fund_trade_record_for_position,
    create_fund_trade_for_position,
    delete_fund_trade_record,
    get_fund_position,
    list_fund_trade_records,
    list_fund_trades,
    materialize_pending_fund_trades,
    sync_fund_position_holding,
    upsert_fund_navs,
)
from app.repositories.fund_alert_scheduler import (
    get_fund_alert_scheduler_config,
    update_fund_alert_scheduler_config,
)
from app.schemas import (
    Candle,
    FundAlertSchedulerUpdate,
    FundNavPoint,
    FundPositionCreate,
    FundPositionHoldingSync,
    FundQuote,
    FundTradeCreate,
    FundTradeRecordCreate,
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


def test_fund_position_holding_sync_replaces_bad_import_trade() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="022365",
            name="Yongying Tech",
            fund_type="mixed",
            shares=10000,
            cost_nav=22,
            trade_date=date(2026, 5, 23),
        ),
    )
    create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="buy",
            shares=1000,
            nav=4.8,
            trade_date=date(2026, 5, 24),
        ),
    )

    synced = sync_fund_position_holding(
        get_fund_position(position.id) or position,
        FundPositionHoldingSync(
            shares=14139.33,
            cost_nav=4.864,
            trade_date=date(2026, 5, 25),
            note="sync current holding",
        ),
    )
    trades = list_fund_trades(position_id=position.id, limit=10)
    records = list_fund_trade_records(position_id=position.id, limit=10)

    assert round(synced.shares, 2) == 14139.33
    assert synced.avg_cost_nav == 4.864
    assert round(synced.invested_amount, 2) == round(14139.33 * 4.864, 2)
    assert synced.realized_profit == 0
    assert len(trades) == 1
    assert trades[0].nav == 4.864
    assert trades[0].note == "sync current holding"
    assert len(records) == 3
    assert records[0].action == "correct"
    assert records[0].note == "sync current holding"


def test_fund_strategy_reference_ignores_holding_correction() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="022365",
            name="Yongying Tech",
            fund_type="mixed",
            shares=10000,
            cost_nav=1.0,
            trade_date=date(2026, 6, 2),
            alert_threshold_percent=5,
        ),
    )

    synced = sync_fund_position_holding(
        get_fund_position(position.id) or position,
        FundPositionHoldingSync(
            shares=9000,
            cost_nav=1.2,
            trade_date=date(2026, 6, 12),
            note="correct current holding",
        ),
    )
    latest = FundNavPoint(
        fund_code="022365",
        nav_date=date(2026, 6, 15),
        unit_nav=1.12,
        daily_growth_rate=0,
        updated_at=_now(),
    )
    summary = _build_fund_summary(
        synced,
        latest,
        trades=list_fund_trades(position_id=position.id, limit=10),
        trade_records=list_fund_trade_records(position_id=position.id, limit=10),
    )

    assert summary.strategy_reference is not None
    assert summary.strategy_reference.source == "system_trade_record"
    assert summary.strategy_reference.trade_date == date(2026, 6, 2)
    assert summary.strategy_reference.nav == 1.0
    assert round(summary.strategy_reference.change_rate, 2) == 12
    assert summary.grid_recommendation is not None
    assert summary.grid_recommendation.baseline_nav == 1.0


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


def test_fund_trade_records_are_display_only() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="012415",
            name="Display Record Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=1.2,
            trade_date=date(2026, 5, 20),
        ),
    )
    before = get_fund_position(position.id)
    assert before is not None

    record = create_fund_trade_record_for_position(
        position,
        FundTradeRecordCreate(
            action="buy",
            shares=50,
            nav=1.5,
            trade_date=date(2026, 5, 22),
            note="display only",
        ),
    )
    after_create = get_fund_position(position.id)
    assert after_create is not None
    assert after_create.shares == before.shares
    assert after_create.avg_cost_nav == before.avg_cost_nav
    assert after_create.invested_amount == before.invested_amount

    assert delete_fund_trade_record(position.id, record.id) is True
    after_delete = get_fund_position(position.id)
    records = list_fund_trade_records(position_id=position.id, limit=10)
    assert after_delete is not None
    assert after_delete.shares == before.shares
    assert len(records) == 1


def test_fund_opening_trade_uses_nav_trading_day_after_cutoff() -> None:
    upsert_fund_navs(
        [
            FundNavPoint(
                fund_code="000002",
                nav_date=date(2026, 5, 22),
                unit_nav=1.0,
                updated_at=_now(),
            ),
            FundNavPoint(
                fund_code="000002",
                nav_date=date(2026, 5, 25),
                unit_nav=1.25,
                updated_at=_now(),
            ),
        ],
    )

    position = create_fund_position(
        FundPositionCreate(
            fund_code="000002",
            name="History Fund",
            fund_type="mixed",
            amount=1000,
            auto_nav=True,
            operation_date=date(2026, 5, 22),
            operation_after_cutoff=True,
        ),
    )
    trades = list_fund_trades(position_id=position.id)

    assert round(position.shares, 2) == 800
    assert position.avg_cost_nav == 1.25
    assert trades[0].trade_date == date(2026, 5, 25)
    assert trades[0].operation_date == date(2026, 5, 22)
    assert trades[0].operation_after_cutoff is True


def test_fund_trade_amount_uses_historical_nav() -> None:
    upsert_fund_navs(
        [
            FundNavPoint(
                fund_code="000003",
                nav_date=date(2026, 5, 20),
                unit_nav=2.0,
                updated_at=_now(),
            ),
        ],
    )
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000003",
            name="Amount Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=1.0,
            trade_date=date(2026, 5, 19),
        ),
    )

    trade = create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="buy",
            amount=600,
            fee=2,
            auto_nav=True,
            operation_date=date(2026, 5, 20),
        ),
    )

    assert trade.trade_date == date(2026, 5, 20)
    assert trade.nav == 2.0
    assert round(trade.shares, 2) == 299


def test_fund_trade_waits_for_confirmation_nav(monkeypatch) -> None:
    monkeypatch.setattr("app.repositories.funds._refresh_navs_for_code", lambda fund_code: None)
    upsert_fund_navs(
        [
            FundNavPoint(
                fund_code="000033",
                nav_date=date(2026, 5, 26),
                unit_nav=2.5,
                updated_at=_now(),
            ),
        ],
    )
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000033",
            name="Pending Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=2.0,
            trade_date=date(2026, 5, 20),
        ),
    )

    pending = create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="buy",
            amount=1000,
            nav=9.9,
            auto_nav=True,
            operation_date=date(2026, 5, 27),
            operation_after_cutoff=False,
        ),
    )
    unchanged = get_fund_position(position.id)
    assert unchanged is not None
    assert unchanged.shares == 100
    assert pending.trade_date == date(2026, 5, 27)
    assert list_fund_trades(position_id=position.id, limit=10)[0].trade_date == date(2026, 5, 20)
    records = list_fund_trade_records(position_id=position.id, limit=10)
    assert records[0].source_trade_id is None
    assert records[0].is_system is True
    assert records[0].nav == 2.5

    upsert_fund_navs(
        [
            FundNavPoint(
                fund_code="000033",
                nav_date=date(2026, 5, 27),
                unit_nav=2.4,
                updated_at=_now(),
            ),
        ],
    )
    assert materialize_pending_fund_trades(position.id) == 1
    updated = get_fund_position(position.id)
    assert updated is not None
    assert round(updated.shares, 2) == round(100 + 1000 / 2.4, 2)
    records = list_fund_trade_records(position_id=position.id, limit=10)
    assert records[0].source_trade_id is not None
    assert records[0].nav == 2.4


def test_fund_position_rebuilds_from_out_of_order_trades() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000004",
            name="Ledger Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=1.0,
            trade_date=date(2026, 5, 22),
        ),
    )
    create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="buy",
            shares=100,
            nav=2.0,
            trade_date=date(2026, 5, 20),
        ),
    )
    updated = get_fund_position(position.id)
    assert updated is not None
    create_fund_trade_for_position(
        updated,
        FundTradeCreate(
            action="sell",
            shares=50,
            nav=3.0,
            trade_date=date(2026, 5, 21),
        ),
    )

    rebuilt = get_fund_position(position.id)
    assert rebuilt is not None
    assert rebuilt.shares == 150
    assert round(rebuilt.invested_amount, 2) == 200
    assert round(rebuilt.avg_cost_nav, 4) == 1.3333
    assert round(rebuilt.realized_profit, 2) == 50


def test_fund_trade_duplicate_submission_is_idempotent() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000047",
            name="Duplicate Guard Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=1.0,
            trade_date=date(2026, 5, 20),
        ),
    )
    payload = FundTradeCreate(
        action="buy",
        amount=500,
        nav=2.0,
        trade_date=date(2026, 5, 27),
        operation_date=date(2026, 5, 27),
        note="same request",
    )

    first = create_fund_trade_for_position(position, payload)
    second = create_fund_trade_for_position(get_fund_position(position.id) or position, payload)
    updated = get_fund_position(position.id)
    trades = list_fund_trades(position_id=position.id, limit=10)
    records = list_fund_trade_records(position_id=position.id, limit=10)

    assert first.id == second.id
    assert updated is not None
    assert updated.shares == 350
    assert len(trades) == 2
    assert len(records) == 2


def test_fund_cashflow_at_current_nav_does_not_create_profit() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000005",
            name="Cashflow Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=1.0,
            trade_date=date(2026, 5, 20),
        ),
    )
    latest = FundNavPoint(
        fund_code="000005",
        nav_date=date(2026, 5, 25),
        unit_nav=1.2,
        daily_growth_rate=0,
        updated_at=_now(),
    )
    before = _build_fund_summary(position, latest)

    create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="buy",
            shares=50,
            nav=1.2,
            trade_date=date(2026, 5, 25),
        ),
    )
    after_buy = get_fund_position(position.id)
    assert after_buy is not None
    buy_summary = _build_fund_summary(after_buy, latest)

    assert round(before.total_profit, 2) == 20
    assert round(buy_summary.total_profit, 2) == round(before.total_profit, 2)
    assert round(buy_summary.holding_profit, 2) == round(before.holding_profit, 2)

    create_fund_trade_for_position(
        after_buy,
        FundTradeCreate(
            action="sell",
            shares=50,
            nav=1.2,
            trade_date=date(2026, 5, 25),
        ),
    )
    after_sell = get_fund_position(position.id)
    assert after_sell is not None
    sell_summary = _build_fund_summary(after_sell, latest)

    assert round(sell_summary.total_profit, 2) == round(before.total_profit, 2)
    assert round(
        sell_summary.holding_profit + sell_summary.position.realized_profit,
        2,
    ) == round(before.total_profit, 2)


def test_fund_day_profit_excludes_same_day_buy() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000044",
            name="Day Profit Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=1.0,
            trade_date=date(2026, 5, 20),
        ),
    )
    create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="buy",
            amount=110,
            nav=1.1,
            trade_date=date(2026, 5, 27),
        ),
    )
    updated = get_fund_position(position.id)
    assert updated is not None
    latest = FundNavPoint(
        fund_code="000044",
        nav_date=date(2026, 5, 27),
        unit_nav=1.1,
        daily_growth_rate=10,
        updated_at=_now(),
    )
    trades = list_fund_trades(position_id=position.id, limit=10)
    summary = _build_fund_summary(updated, latest, trades=trades)

    assert round(summary.day_profit, 2) == 10


def test_fund_strategy_reference_zeroes_same_day_confirmed_trade() -> None:
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000045",
            name="Same Day Reference Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=1.0,
            trade_date=date(2026, 5, 20),
            alert_threshold_percent=1,
        ),
    )
    create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="buy",
            amount=110,
            nav=1.1,
            trade_date=date(2026, 5, 27),
        ),
    )
    updated = get_fund_position(position.id)
    assert updated is not None
    latest = FundNavPoint(
        fund_code="000045",
        nav_date=date(2026, 5, 27),
        unit_nav=1.08,
        daily_growth_rate=-2,
        updated_at=_now(),
    )
    summary = _build_fund_summary(
        updated,
        latest,
        trades=list_fund_trades(position_id=position.id, limit=10),
        trade_records=list_fund_trade_records(position_id=position.id, limit=10),
    )

    assert summary.strategy_reference is not None
    assert summary.strategy_reference.trade_date == date(2026, 5, 27)
    assert summary.strategy_reference.nav == 1.1
    assert summary.strategy_reference.change_rate == 0
    assert summary.grid_recommendation is None


def test_fund_strategy_reference_uses_pending_record_for_same_day_estimate(
    monkeypatch,
) -> None:
    monkeypatch.setattr(
        "app.repositories.funds._refresh_navs_for_code",
        lambda fund_code: None,
    )
    upsert_fund_navs(
        [
            FundNavPoint(
                fund_code="000046",
                nav_date=date(2026, 5, 26),
                unit_nav=2.5,
                updated_at=_now(),
            ),
        ],
    )
    position = create_fund_position(
        FundPositionCreate(
            fund_code="000046",
            name="Pending Strategy Fund",
            fund_type="mixed",
            shares=100,
            cost_nav=2.0,
            trade_date=date(2026, 5, 20),
            alert_threshold_percent=1,
        ),
    )
    create_fund_trade_for_position(
        position,
        FundTradeCreate(
            action="buy",
            amount=1000,
            nav=9.9,
            auto_nav=True,
            operation_date=date(2026, 5, 27),
            operation_after_cutoff=False,
        ),
    )
    unchanged = get_fund_position(position.id)
    assert unchanged is not None
    latest = FundNavPoint(
        fund_code="000046",
        nav_date=date(2026, 5, 26),
        unit_nav=2.5,
        daily_growth_rate=0,
        updated_at=_now(),
    )
    quote = FundQuote(
        fund_code="000046",
        name="Pending Strategy Fund",
        nav_date=date(2026, 5, 26),
        unit_nav=2.5,
        estimated_nav=2.4,
        estimated_change_rate=-4,
        estimate_time=datetime(2026, 5, 27, 7, 0, tzinfo=timezone.utc),
    )
    summary = _build_fund_summary(
        unchanged,
        latest,
        quote,
        trades=list_fund_trades(position_id=position.id, limit=10),
        trade_records=list_fund_trade_records(position_id=position.id, limit=10),
    )

    assert summary.valuation_mode == "estimated"
    assert summary.strategy_reference is not None
    assert summary.strategy_reference.source == "pending_trade_record"
    assert summary.strategy_reference.trade_date == date(2026, 5, 27)
    assert summary.strategy_reference.nav == 2.5
    assert summary.strategy_reference.change_rate == 0
    assert summary.grid_recommendation is None


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
    assert round(summary.market_value, 2) == 1200

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
            trade_date=date(2026, 5, 20),
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
    assert summary.grid_recommendation.action_label == "上涨提醒"
    assert summary.grid_recommendation.recommended_shares == 0
    assert summary.strategy_reference is not None
    assert summary.strategy_reference.nav == 1.0
    assert summary.strategy_reference.trade_date == date(2026, 5, 20)
    assert round(summary.strategy_reference.change_rate, 2) == 6

    buy_summary = _build_fund_summary(
        position,
        latest.model_copy(update={"unit_nav": 0.94}),
        last_trade=list_fund_trades(position_id=position.id, limit=1)[0],
    )

    assert buy_summary.grid_recommendation is not None
    assert buy_summary.grid_recommendation.action == "buy"
    assert buy_summary.grid_recommendation.action_label == "下跌提醒"
    assert buy_summary.grid_recommendation.recommended_amount == 0


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
            trade_date=date(2026, 5, 20),
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


def test_fund_provider_reads_long_nav_trend_and_merges_latest(monkeypatch) -> None:
    EastmoneyFundProvider._nav_cache.clear()
    calls: list[str] = []

    class FakeResponse:
        def __init__(self, content: bytes) -> None:
            self.content = content

        def raise_for_status(self) -> None:
            return None

    def fake_get(url, *args, **kwargs):
        calls.append(str(url))
        if "pingzhongdata" in str(url):
            return FakeResponse(
                b'var Data_netWorthTrend = ['
                b'{"x":1747958400000,"y":1.1688,"equityReturn":0},'
                b'{"x":1779408000000,"y":5.4687,"equityReturn":6.36}'
                b'];'
                b'var Data_ACWorthTrend = ['
                b'[1747958400000,1.1688],[1779408000000,5.4687]'
                b'];'
            )
        return FakeResponse(
            (
                'var apidata={ content:"<table><tbody>'
                '<tr><td>2026-05-25</td><td>5.7114</td><td>5.7114</td>'
                '<td>4.44%</td><td>限制大额申购</td><td>开放赎回</td><td></td></tr>'
                '</tbody></table>"};'
            ).encode("utf-8")
        )

    monkeypatch.setattr(fund_provider.httpx, "get", fake_get)

    provider = EastmoneyFundProvider()
    points = provider.nav_history("022365", limit=370)

    assert points[0].nav_date == date(2026, 5, 25)
    assert points[0].unit_nav == 5.7114
    assert points[1].nav_date == date(2026, 5, 22)
    assert points[-1].nav_date == date(2025, 5, 23)
    assert round((points[0].unit_nav / points[-1].unit_nav - 1) * 100, 2) == 388.66
    assert any("pingzhongdata" in call for call in calls)


def test_fund_provider_reads_hs300_benchmark_history(monkeypatch) -> None:
    EastmoneyFundProvider._benchmark_cache.clear()
    calls: list[dict[str, object]] = []

    class FakeResponse:
        content = (
            b'{"data":{"klines":["2026-05-20,1,3900,1,1,0,0,0,1.25,0,0",'
            b'"2026-05-21,1,3939,1,1,0,0,0,1.00,0,0"]}}'
        )

        def raise_for_status(self) -> None:
            return None

    def fake_get(*args, **kwargs):
        calls.append(kwargs)
        return FakeResponse()

    monkeypatch.setattr(fund_provider.httpx, "get", fake_get)

    provider = EastmoneyFundProvider()
    points = provider.benchmark_history("hs300", limit=10)
    cached = provider.benchmark_history("000300", limit=10)

    assert len(points) == 2
    assert points[-1].name == "沪深300"
    assert points[-1].close == 3939
    assert points[-1].daily_growth_rate == 1.0
    assert len(cached) == 2
    assert len(calls) == 1
    assert calls[0]["trust_env"] is False


def test_fund_provider_uses_futu_hs300_fallback(monkeypatch) -> None:
    EastmoneyFundProvider._benchmark_cache.clear()
    calls: list[dict[str, object]] = []

    def fail_get(*args, **kwargs):
        raise fund_provider.FundProviderError("eastmoney disconnected")

    def fake_request_history_klines(**kwargs):
        calls.append(kwargs)
        return [
            Candle(
                code="SH.000300",
                market="SH",
                period="day",
                time=datetime(2026, 5, 20, tzinfo=timezone.utc),
                open=3900,
                high=3910,
                low=3890,
                close=3900,
                volume=1,
                turnover=1,
            ),
            Candle(
                code="SH.000300",
                market="SH",
                period="day",
                time=datetime(2026, 5, 21, tzinfo=timezone.utc),
                open=3900,
                high=3940,
                low=3890,
                close=3939,
                volume=1,
                turnover=1,
            ),
        ]

    monkeypatch.setattr(fund_provider.httpx, "get", fail_get)
    monkeypatch.setattr(
        "app.services.futu_client.request_history_klines",
        fake_request_history_klines,
    )

    provider = EastmoneyFundProvider()
    points = provider.benchmark_history("hs300", limit=10)

    assert len(points) == 2
    assert points[-1].close == 3939
    assert points[-1].daily_growth_rate == 1.0
    assert points[-1].source == "futu"
    assert calls[0]["code"] == "SH.000300"
