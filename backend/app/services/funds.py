from ..repositories.funds import get_latest_fund_nav, list_fund_positions, upsert_fund_navs
from ..schemas import FundPositionSummary
from .fund_provider import EastmoneyFundProvider, FundProviderError


def refresh_fund_navs(fund_code: str, *, limit: int = 90):
    provider = EastmoneyFundProvider()
    points = provider.nav_history(fund_code, limit=limit)
    upsert_fund_navs(points)
    return points


def list_fund_position_summaries(*, refresh: bool = True) -> list[FundPositionSummary]:
    positions = list_fund_positions()
    if refresh:
        provider = EastmoneyFundProvider()
        for position in positions:
            try:
                points = provider.nav_history(position.fund_code, limit=3)
            except (FundProviderError, Exception):
                continue
            upsert_fund_navs(points)
    summaries: list[FundPositionSummary] = []
    for position in positions:
        latest = get_latest_fund_nav(position.fund_code)
        market_value = position.shares * latest.unit_nav if latest is not None else 0
        holding_profit = market_value - position.invested_amount
        total_profit = holding_profit + position.realized_profit
        base = position.invested_amount if position.invested_amount else 0
        summaries.append(
            FundPositionSummary(
                position=position,
                latest_nav=latest,
                market_value=market_value,
                holding_profit=holding_profit,
                holding_profit_rate=holding_profit / base * 100 if base else 0,
                total_profit=total_profit,
                total_profit_rate=total_profit / base * 100 if base else 0,
            ),
        )
    return summaries
