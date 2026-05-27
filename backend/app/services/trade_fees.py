from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP
from math import ceil

from ..schemas import PositionTradeAction


SELL_ACTIONS = {"reduce", "close"}

HK_BROKERAGE_RATE = 0.001
HK_BROKERAGE_MIN = 88.0
HK_STAMP_DUTY_RATE = 0.001
HK_TRADING_FEE_RATE = 0.0000565
HK_TRANSACTION_LEVY_RATE = 0.000027
HK_SETTLEMENT_FEE_RATE = 0.00002
HK_SETTLEMENT_FEE_MIN = 2.0
HK_SETTLEMENT_FEE_MAX = 100.0
HK_FRC_TRANSACTION_LEVY_RATE = 0.0000015

US_BROKERAGE_RATE = 0.00138
US_BROKERAGE_MIN = 18.0
US_SEC_FEE_RATE = 20.60 / 1_000_000
US_TAF_RATE_PER_SHARE = 0.000195
US_TAF_MAX = 9.79


def calculate_default_position_trade_fee(
    *,
    market: str,
    code: str,
    action: PositionTradeAction,
    quantity: float,
    price: float,
) -> float:
    if quantity <= 0 or price <= 0:
        return 0
    normalized_market = _market_for(market, code)
    if normalized_market == "HK":
        return _round_fee(_calculate_hk_fee(quantity * price))
    if normalized_market == "US":
        return _round_fee(_calculate_us_fee(action, quantity, quantity * price))
    return 0


def _calculate_hk_fee(turnover: float) -> float:
    brokerage = max(turnover * HK_BROKERAGE_RATE, HK_BROKERAGE_MIN)
    stamp_duty = ceil(turnover * HK_STAMP_DUTY_RATE)
    settlement_fee = min(
        max(turnover * HK_SETTLEMENT_FEE_RATE, HK_SETTLEMENT_FEE_MIN),
        HK_SETTLEMENT_FEE_MAX,
    )
    return (
        brokerage
        + stamp_duty
        + turnover * HK_TRADING_FEE_RATE
        + turnover * HK_TRANSACTION_LEVY_RATE
        + settlement_fee
        + turnover * HK_FRC_TRANSACTION_LEVY_RATE
    )


def _calculate_us_fee(
    action: PositionTradeAction,
    quantity: float,
    turnover: float,
) -> float:
    brokerage = max(turnover * US_BROKERAGE_RATE, US_BROKERAGE_MIN)
    regulatory_fee = 0.0
    if action in SELL_ACTIONS:
        regulatory_fee = turnover * US_SEC_FEE_RATE
        regulatory_fee += min(quantity * US_TAF_RATE_PER_SHARE, US_TAF_MAX)
    return brokerage + regulatory_fee


def _market_for(market: str, code: str) -> str:
    normalized_market = market.strip().upper()
    normalized_code = code.strip().upper()
    if normalized_code.startswith("HK."):
        return "HK"
    if normalized_code.startswith("US."):
        return "US"
    return normalized_market


def _round_fee(value: float) -> float:
    rounded = Decimal(str(max(value, 0))).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )
    return float(rounded)
