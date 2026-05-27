from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, datetime

from ..db.converters import UTC
from ..repositories.funds import (
    get_latest_fund_nav,
    list_fund_positions,
    list_fund_trades,
    materialize_pending_fund_trades,
    upsert_fund_navs,
)
from ..schemas import (
    FundGridRecommendation,
    FundNavPoint,
    FundPosition,
    FundPositionSummary,
    FundQuote,
    FundStrategyReference,
    FundTrade,
)
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
        for fund_code, points, quote in _refresh_positions_concurrently(positions):
            upsert_fund_navs(points)
            if quote is not None:
                quotes[fund_code] = quote
    materialize_pending_fund_trades()
    positions = list_fund_positions()
    summaries: list[FundPositionSummary] = []
    for position in positions:
        latest = get_latest_fund_nav(position.fund_code)
        trades = list_fund_trades(position_id=position.id, limit=500)
        summaries.append(
            _build_fund_summary(
                position,
                latest,
                quotes.get(position.fund_code),
                trades=trades,
            ),
        )
    return summaries


def _build_fund_summary(
    position: FundPosition,
    latest: FundNavPoint | None,
    quote: FundQuote | None = None,
    last_trade: FundTrade | None = None,
    trades: list[FundTrade] | None = None,
) -> FundPositionSummary:
    ordered_trades = _sorted_trades(trades)
    if last_trade is None and ordered_trades:
        last_trade = ordered_trades[-1]
    display_nav = latest.unit_nav if latest is not None else 0
    display_change_rate = latest.daily_growth_rate if latest is not None else 0
    display_time = latest.updated_at if latest is not None else None
    valuation_mode = "official" if latest is not None else "none"

    if _should_use_estimate(latest, quote):
        display_nav = quote.estimated_nav
        display_change_rate = quote.estimated_change_rate
        display_time = quote.estimate_time
        valuation_mode = "estimated"

    valuation_nav = latest.unit_nav if latest is not None and latest.unit_nav > 0 else display_nav
    market_value = position.shares * valuation_nav if valuation_nav > 0 else 0
    day_profit_shares = _day_profit_shares(
        position=position,
        latest=latest,
        valuation_mode=valuation_mode,
        trades=ordered_trades,
    )
    day_profit = _day_profit(
        shares=day_profit_shares,
        display_nav=display_nav,
        change_rate=display_change_rate,
        latest=latest,
        valuation_mode=valuation_mode,
    )
    holding_profit = market_value - position.invested_amount
    total_profit = holding_profit + position.realized_profit
    base = position.invested_amount if position.invested_amount else 0
    strategy_reference = _build_strategy_reference(
        position=position,
        current_nav=display_nav,
        valuation_mode=valuation_mode,
        valuation_time=display_time,
        last_trade=last_trade,
    )
    recommendation = _build_grid_recommendation(
        position=position,
        current_nav=display_nav,
        strategy_reference=strategy_reference,
    )
    return FundPositionSummary(
        position=position,
        latest_nav=latest,
        quote=quote,
        grid_recommendation=recommendation,
        strategy_reference=strategy_reference,
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


def _sorted_trades(trades: list[FundTrade] | None) -> list[FundTrade]:
    if not trades:
        return []
    return sorted(trades, key=lambda item: (item.trade_date, item.created_at))


def _should_use_estimate(
    latest: FundNavPoint | None,
    quote: FundQuote | None,
) -> bool:
    if quote is None or quote.estimated_nav <= 0 or quote.estimate_time is None:
        return False
    latest_date = latest.nav_date if latest is not None else date.min
    estimate_date = quote.estimate_time.astimezone(UTC).date()
    return estimate_date > latest_date


def _day_profit_shares(
    *,
    position: FundPosition,
    latest: FundNavPoint | None,
    valuation_mode: str,
    trades: list[FundTrade],
) -> float:
    if latest is None or not trades:
        return position.shares
    shares = 0.0
    for trade in trades:
        if valuation_mode == "official":
            if trade.trade_date >= latest.nav_date:
                continue
        elif trade.trade_date > latest.nav_date:
            continue
        if trade.action == "buy":
            shares += trade.shares
        else:
            shares -= trade.shares
    return max(0.0, shares)


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


def _build_grid_recommendation(
    *,
    position: FundPosition,
    current_nav: float,
    strategy_reference: FundStrategyReference | None,
) -> FundGridRecommendation | None:
    if not position.alert_enabled:
        return None
    if position.shares <= 0 or current_nav <= 0:
        return None
    if strategy_reference is None or strategy_reference.nav <= 0:
        return None
    baseline_nav = strategy_reference.nav
    change_rate = strategy_reference.change_rate
    reason = (
        f"较上次操作净值 {baseline_nav:.4f} "
        f"{'上涨' if change_rate >= 0 else '下跌'} {abs(change_rate):.2f}%"
    )
    threshold = position.alert_threshold_percent
    if change_rate >= threshold:
        return FundGridRecommendation(
            position_id=position.id,
            fund_code=position.fund_code,
            name=position.name,
            action="sell",
            action_label="上涨提醒",
            reason=reason,
            baseline_nav=baseline_nav,
            current_nav=current_nav,
            change_rate=change_rate,
            threshold_percent=threshold,
            valuation_mode=strategy_reference.valuation_mode,
            valuation_time=strategy_reference.valuation_time,
        )
    if change_rate <= -threshold:
        return FundGridRecommendation(
            position_id=position.id,
            fund_code=position.fund_code,
            name=position.name,
            action="buy",
            action_label="下跌提醒",
            reason=reason,
            baseline_nav=baseline_nav,
            current_nav=current_nav,
            change_rate=change_rate,
            threshold_percent=threshold,
            valuation_mode=strategy_reference.valuation_mode,
            valuation_time=strategy_reference.valuation_time,
        )
    return None


def _build_strategy_reference(
    *,
    position: FundPosition,
    current_nav: float,
    valuation_mode: str,
    valuation_time: datetime | None,
    last_trade: FundTrade | None,
) -> FundStrategyReference | None:
    if position.shares <= 0 or current_nav <= 0:
        return None
    baseline_nav = last_trade.nav if last_trade is not None else position.avg_cost_nav
    if baseline_nav <= 0:
        return None
    return FundStrategyReference(
        nav=baseline_nav,
        trade_date=last_trade.trade_date if last_trade is not None else None,
        source="last_trade" if last_trade is not None else "position_cost",
        change_rate=(current_nav - baseline_nav) / baseline_nav * 100,
        valuation_mode=valuation_mode,
        valuation_time=valuation_time,
    )


def _refresh_positions_concurrently(
    positions: list[FundPosition],
) -> list[tuple[str, list[FundNavPoint], FundQuote | None]]:
    if not positions:
        return []
    results: list[tuple[str, list[FundNavPoint], FundQuote | None]] = []
    max_workers = min(6, len(positions))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(_fetch_position_fund_data, position): position.fund_code
            for position in positions
        }
        for future in as_completed(futures):
            try:
                results.append(future.result())
            except Exception:
                continue
    return results


def _fetch_position_fund_data(
    position: FundPosition,
) -> tuple[str, list[FundNavPoint], FundQuote | None]:
    provider = EastmoneyFundProvider()
    points = provider.nav_history(position.fund_code, limit=3)
    latest = points[0] if points else None
    try:
        quote = provider.quote(position.fund_code, latest=latest)
    except (FundProviderError, Exception):
        quote = None
    return position.fund_code, points, quote
