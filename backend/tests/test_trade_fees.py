import pytest

from app import database
from app.schemas import PositionCreate, PositionTradeCreate
from app.services.trade_fees import calculate_default_position_trade_fee


def test_hk_default_trade_fee_uses_full_fee_schedule() -> None:
    fee = calculate_default_position_trade_fee(
        market="HK",
        code="HK.01398",
        action="add",
        quantity=2000,
        price=6.78,
    )

    assert fee == pytest.approx(105.15)


def test_us_default_trade_fee_uses_brokerage_minimum_on_buy() -> None:
    fee = calculate_default_position_trade_fee(
        market="US",
        code="US.NVDA",
        action="add",
        quantity=1,
        price=215.33,
    )

    assert fee == pytest.approx(18)


def test_us_default_trade_fee_adds_sec_and_taf_on_sell() -> None:
    fee = calculate_default_position_trade_fee(
        market="US",
        code="US.MU",
        action="reduce",
        quantity=1000,
        price=100,
    )

    assert fee == pytest.approx(140.26)


def test_position_trade_omitted_fee_uses_default_schedule() -> None:
    position = database.create_position(
        PositionCreate(
            market="US",
            code="US.MU",
            name="Micron",
            quantity=10,
            cost_price=100,
            currency="USD",
        ),
    )

    trade = database.create_position_trade_for_position(
        position,
        PositionTradeCreate(action="reduce", quantity=2, price=120),
    )

    assert trade.fee == pytest.approx(18.01)


def test_position_trade_explicit_zero_fee_overrides_default_schedule() -> None:
    position = database.create_position(
        PositionCreate(
            market="US",
            code="US.MU",
            name="Micron",
            quantity=10,
            cost_price=100,
            currency="USD",
        ),
    )

    trade = database.create_position_trade_for_position(
        position,
        PositionTradeCreate(action="reduce", quantity=2, price=120, fee=0),
    )

    assert trade.fee == 0
