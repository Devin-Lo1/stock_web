from datetime import date

from app.repositories.funds import (
    create_fund_position,
    create_fund_trade_for_position,
    get_fund_position,
    list_fund_trades,
    upsert_fund_navs,
)
from app.schemas import FundNavPoint, FundPositionCreate, FundTradeCreate
from app.services.funds import list_fund_position_summaries
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
