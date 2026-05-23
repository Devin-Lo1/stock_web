from datetime import date

from ..db.converters import UTC
from ..repositories.funds import (
    get_latest_fund_nav,
    list_fund_positions,
    upsert_fund_navs,
)
from ..schemas import FundNavPoint, FundPosition, FundPositionSummary, FundQuote
from .fund_provider import EastmoneyFundProvider, FundProviderError


def refresh_fund_navs(fund_code: str, *, limit: int = 90):
    provider = EastmoneyFundProvider()
    points = provider.nav_history(fund_code, limit=limit)
    upsert_fund_navs(points)
    return points


def list_fund_position_summaries(*, refresh: bool = True) -> list[FundPositionSummary]:
    positions = list_fund_positions()
    quotes: dict[str, FundQuote] = {}
    if refresh:
        provider = EastmoneyFundProvider()
        for position in positions:
            try:
                points = provider.nav_history(position.fund_code, limit=3)
            except (FundProviderError, Exception):
                continue
            upsert_fund_navs(points)
            try:
                latest = points[0] if points else None
                quotes[position.fund_code] = provider.quote(
                    position.fund_code,
                    latest=latest,
                )
            except (FundProviderError, Exception):
                continue
    summaries: list[FundPositionSummary] = []
    for position in positions:
        latest = get_latest_fund_nav(position.fund_code)
        summaries.append(
            _build_fund_summary(position, latest, quotes.get(position.fund_code)),
        )
    return summaries


def _build_fund_summary(
    position: FundPosition,
    latest: FundNavPoint | None,
    quote: FundQuote | None = None,
) -> FundPositionSummary:
    display_nav = latest.unit_nav if latest is not None else 0
    display_change_rate = latest.daily_growth_rate if latest is not None else 0
    display_time = latest.updated_at if latest is not None else None
    valuation_mode = "official" if latest is not None else "none"

    if _should_use_estimate(latest, quote):
        display_nav = quote.estimated_nav
        display_change_rate = quote.estimated_change_rate
        display_time = quote.estimate_time
        valuation_mode = "estimated"

    market_value = position.shares * display_nav if display_nav > 0 else 0
    day_profit = _day_profit(
        shares=position.shares,
        display_nav=display_nav,
        change_rate=display_change_rate,
        latest=latest,
        valuation_mode=valuation_mode,
    )
    holding_profit = market_value - position.invested_amount
    total_profit = holding_profit + position.realized_profit
    base = position.invested_amount if position.invested_amount else 0
    return FundPositionSummary(
        position=position,
        latest_nav=latest,
        quote=quote,
        valuation_mode=valuation_mode,
        display_nav=display_nav,
        display_change_rate=display_change_rate,
        display_time=display_time,
        day_profit=day_profit,
        day_profit_rate=display_change_rate,
        market_value=market_value,
        holding_profit=holding_profit,
        holding_profit_rate=holding_profit / base * 100 if base else 0,
        total_profit=total_profit,
        total_profit_rate=total_profit / base * 100 if base else 0,
    )


def _should_use_estimate(
    latest: FundNavPoint | None,
    quote: FundQuote | None,
) -> bool:
    if quote is None or quote.estimated_nav <= 0 or quote.estimate_time is None:
        return False
    latest_date = latest.nav_date if latest is not None else date.min
    estimate_date = quote.estimate_time.astimezone(UTC).date()
    return estimate_date > latest_date


def _day_profit(
    *,
    shares: float,
    display_nav: float,
    change_rate: float,
    latest: FundNavPoint | None,
    valuation_mode: str,
) -> float:
    if display_nav <= 0:
        return 0
    if valuation_mode == "estimated" and latest is not None:
        return shares * (display_nav - latest.unit_nav)
    if change_rate == 0:
        return 0
    previous_nav = display_nav / (1 + change_rate / 100)
    return shares * (display_nav - previous_nav)
