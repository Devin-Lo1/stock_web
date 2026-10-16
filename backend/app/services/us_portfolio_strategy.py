from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Iterable

from ..repositories.market_data import get_quotes
from ..repositories.positions import list_positions
from ..schemas import (
    PortfolioStrategyAsset,
    PortfolioStrategyMetric,
    PortfolioStrategyResult,
    PortfolioStrategySuggestion,
    Position,
    QuoteSnapshot,
)

_CORE_BROAD = {"VOO"}
_CORE_GROWTH = {"QQQ", "QQQM"}
_CASH_LIKE = {"SGOV"}
_QUALITY_TECH = {"GOOG", "GOOGL"}
_SEMICONDUCTOR = {"MU", "WDC", "LITE"}
_LEVERAGED = {"MUU"}

_PROFIT_TAKE_TARGETS = {
    90: (0.60, {"VOO": 50, "SGOV": 30, "QQQM": 20}),
    60: (0.50, {"VOO": 50, "QQQM": 25, "SGOV": 25}),
    30: (0.40, {"VOO": 60, "QQQM": 25, "SGOV": 15}),
}


@dataclass(frozen=True)
class _Holding:
    position: Position
    quote: QuoteSnapshot | None
    symbol: str
    category: str
    current_price: float
    market_value: float
    cost_value: float
    holding_profit: float
    holding_profit_rate: float


def build_us_portfolio_strategy(*, cash: float = 0) -> PortfolioStrategyResult:
    positions = [
        position
        for position in list_positions()
        if position.market == "US" and position.quantity > 0
    ]
    quotes_by_code = {
        quote.code.upper(): quote for quote in get_quotes([position.code for position in positions])
    }
    holdings = [_build_holding(position, quotes_by_code.get(position.code.upper())) for position in positions]
    total_market_value = sum(item.market_value for item in holdings)
    total_equity = total_market_value + max(0.0, cash)
    cost_value = sum(item.cost_value for item in holdings)
    holding_profit = sum(item.holding_profit for item in holdings)
    holding_profit_rate = holding_profit / cost_value * 100 if cost_value else 0

    weights = _build_weights(holdings, cash=max(0.0, cash), total_equity=total_equity)
    assets = [_to_asset(item, total_equity=total_equity) for item in holdings]
    metrics = _build_metrics(weights)
    suggestions = _build_suggestions(
        holdings,
        cash=max(0.0, cash),
        total_equity=total_equity,
        weights=weights,
    )
    return PortfolioStrategyResult(
        market="US",
        currency="USD",
        cash=max(0.0, cash),
        total_market_value=total_market_value,
        total_equity=total_equity,
        holding_profit=holding_profit,
        holding_profit_rate=holding_profit_rate,
        core_weight=weights["core"],
        growth_weight=weights["growth"],
        cash_like_weight=weights["cash_like"],
        leverage_weight=weights["leverage"],
        semiconductor_weight=weights["semiconductor"],
        assets=assets,
        metrics=metrics,
        suggestions=suggestions,
        limitations=[
            "fundamental_freeze_rules_not_evaluated",
            "sixty_day_high_drawdown_rules_require_daily_klines",
            "all_suggestions_require_manual_confirmation",
        ],
        generated_at=datetime.now(timezone.utc),
    )


def _build_holding(position: Position, quote: QuoteSnapshot | None) -> _Holding:
    symbol = _symbol(position.code)
    current_price = quote.current_price if quote is not None else position.cost_price
    market_value = position.quantity * current_price
    cost_price = position.adjusted_cost_price or position.avg_cost_price or position.cost_price
    cost_value = position.quantity * cost_price
    holding_profit = market_value - cost_value
    holding_profit_rate = holding_profit / cost_value * 100 if cost_value else 0
    return _Holding(
        position=position,
        quote=quote,
        symbol=symbol,
        category=_category(symbol),
        current_price=current_price,
        market_value=market_value,
        cost_value=cost_value,
        holding_profit=holding_profit,
        holding_profit_rate=holding_profit_rate,
    )


def _build_weights(
    holdings: Iterable[_Holding],
    *,
    cash: float,
    total_equity: float,
) -> dict[str, float]:
    if total_equity <= 0:
        return {
            "core": 0,
            "growth": 0,
            "cash_like": 0,
            "leverage": 0,
            "semiconductor": 0,
        }
    buckets = {
        "core": cash,
        "growth": 0.0,
        "cash_like": cash,
        "leverage": 0.0,
        "semiconductor": 0.0,
    }
    for item in holdings:
        if item.symbol in _CORE_BROAD or item.symbol in _CORE_GROWTH or item.symbol in _CASH_LIKE:
            buckets["core"] += item.market_value
        if item.symbol in _CORE_GROWTH:
            buckets["growth"] += item.market_value
        if item.symbol in _CASH_LIKE:
            buckets["cash_like"] += item.market_value
        if item.symbol in _LEVERAGED:
            buckets["leverage"] += item.market_value
        if item.symbol in _SEMICONDUCTOR or item.symbol in _LEVERAGED:
            buckets["semiconductor"] += item.market_value
    return {key: value / total_equity * 100 for key, value in buckets.items()}


def _build_metrics(weights: dict[str, float]) -> list[PortfolioStrategyMetric]:
    return [
        _metric(
            "core_weight",
            "core_weight",
            weights["core"],
            target=68,
            lower=60,
            upper=75,
        ),
        _metric(
            "cash_like_weight",
            "cash_like_weight",
            weights["cash_like"],
            target=12,
            lower=8,
            upper=18,
        ),
        _metric(
            "leverage_weight",
            "leverage_weight",
            weights["leverage"],
            target=3,
            lower=0,
            upper=5,
        ),
        _metric(
            "semiconductor_weight",
            "semiconductor_chain_weight",
            weights["semiconductor"],
            target=35,
            lower=0,
            upper=40,
            breach=45,
        ),
        _metric(
            "growth_weight",
            "qqq_qqqm_weight",
            weights["growth"],
            target=20,
            lower=12,
            upper=28,
        ),
    ]


def _build_suggestions(
    holdings: list[_Holding],
    *,
    cash: float,
    total_equity: float,
    weights: dict[str, float],
) -> list[PortfolioStrategySuggestion]:
    if total_equity <= 0:
        return [
            _suggestion(
                action="alert",
                reason_code="NO_US_HOLDINGS",
                reason="No active US holdings found.",
                priority="high",
            ),
        ]

    suggestions: list[PortfolioStrategySuggestion] = []
    suggestions.extend(_risk_suggestions(holdings, total_equity=total_equity, weights=weights))
    suggestions.extend(
        _profit_and_loss_suggestions(
            holdings,
            cash=cash,
            total_equity=total_equity,
            weights=weights,
        ),
    )
    suggestions.extend(_cash_deployment_suggestions(cash=cash, total_equity=total_equity, weights=weights))
    if not suggestions:
        suggestions.append(
            _suggestion(
                action="hold",
                reason_code="PORTFOLIO_WITHIN_RULES",
                reason="Portfolio is within the configured US holding discipline.",
                priority="low",
            ),
        )
    return suggestions


def _risk_suggestions(
    holdings: list[_Holding],
    *,
    total_equity: float,
    weights: dict[str, float],
) -> list[PortfolioStrategySuggestion]:
    suggestions: list[PortfolioStrategySuggestion] = []
    if weights["leverage"] > 5:
        target_value = total_equity * 0.03
        current_value = _sum_value(holdings, _LEVERAGED)
        suggestions.append(
            _suggestion(
                action="sell",
                code="US.MUU",
                amount=max(0.0, current_value - target_value),
                total_equity=total_equity,
                reason_code="LEVERAGE_OVER_HARD_LIMIT",
                reason="Leveraged ETF weight is above 5%; trim toward the 3% target.",
                priority="high",
                allocation={"VOO": 70, "SGOV": 30},
            ),
        )
    elif weights["leverage"] > 3:
        suggestions.append(
            _suggestion(
                action="alert",
                reason_code="LEVERAGE_ABOVE_TARGET",
                reason="Leveraged ETF weight is above the 3% target; do not add.",
                priority="medium",
            ),
        )
    if weights["semiconductor"] >= 45:
        suggestions.append(
            _suggestion(
                action="freeze",
                reason_code="SEMICONDUCTOR_OVER_HARD_LIMIT",
                reason="Semiconductor chain exposure is above 45%; freeze new MU/MUU/WDC/LITE buys.",
                priority="high",
            ),
        )
    elif weights["semiconductor"] >= 40:
        suggestions.append(
            _suggestion(
                action="alert",
                reason_code="SEMICONDUCTOR_OVER_WARNING_LIMIT",
                reason="Semiconductor chain exposure is above 40%; only risk-reduction actions are allowed.",
                priority="high",
            ),
        )
    elif weights["semiconductor"] >= 35:
        suggestions.append(
            _suggestion(
                action="alert",
                reason_code="SEMICONDUCTOR_ABOVE_ALERT_LINE",
                reason="Semiconductor chain exposure is above 35%; new adds need extra caution.",
                priority="medium",
            ),
        )
    if weights["core"] < 60:
        suggestions.append(
            _suggestion(
                action="rebalance",
                reason_code="CORE_BELOW_MINIMUM",
                reason="Core ETF plus cash-like assets are below 60%; prioritize VOO/QQQM/SGOV before individual stocks.",
                priority="high",
                allocation={"VOO": 70, "QQQM": 20, "SGOV": 10},
            ),
        )
    return suggestions


def _profit_and_loss_suggestions(
    holdings: list[_Holding],
    *,
    cash: float,
    total_equity: float,
    weights: dict[str, float],
) -> list[PortfolioStrategySuggestion]:
    suggestions: list[PortfolioStrategySuggestion] = []
    buy_dip_allowed = (
        weights["core"] >= 60
        and weights["leverage"] <= 3
        and weights["semiconductor"] <= 35
        and cash > 0
    )
    for item in holdings:
        if item.symbol in _QUALITY_TECH or item.symbol in _SEMICONDUCTOR:
            suggestions.extend(_single_stock_profit_suggestions(item, total_equity=total_equity))
            if item.holding_profit_rate <= -90:
                suggestions.append(
                    _suggestion(
                        action="freeze",
                        code=item.position.code,
                        reason_code="SINGLE_STOCK_LOSS_FREEZE",
                        reason="Position drawdown is worse than -90%; freeze new buys.",
                        priority="high",
                    ),
                )
            elif item.holding_profit_rate <= -60:
                suggestions.append(
                    _suggestion(
                        action="alert",
                        code=item.position.code,
                        reason_code="SINGLE_STOCK_LOSS_ALERT",
                        reason="Position drawdown is worse than -60%; alert only, no automatic buy.",
                        priority="high",
                    ),
                )
            elif item.holding_profit_rate <= -30 and buy_dip_allowed:
                amount = total_equity * (0.0025 if item.symbol in _SEMICONDUCTOR else 0.005)
                suggestions.append(
                    _suggestion(
                        action="buy",
                        code=item.position.code,
                        amount=min(cash, amount),
                        total_equity=total_equity,
                        reason_code="CONTROLLED_BUY_DIP",
                        reason="Small buy-dip is allowed by portfolio constraints; confirm manually.",
                        priority="medium",
                    ),
                )
        if item.symbol in _LEVERAGED:
            if item.holding_profit_rate >= 20:
                suggestions.append(
                    _suggestion(
                        action="sell",
                        code=item.position.code,
                        amount=max(0.0, item.holding_profit * 0.50),
                        total_equity=total_equity,
                        reason_code="LEVERAGED_PROFIT_TAKE",
                        reason="Leveraged ETF profit is above 20%; take half of the unrealized profit amount.",
                        priority="high",
                        allocation={"VOO": 70, "SGOV": 30},
                    ),
                )
            elif item.holding_profit_rate <= -20:
                suggestions.append(
                    _suggestion(
                        action="sell",
                        code=item.position.code,
                        amount=item.market_value * 0.50,
                        total_equity=total_equity,
                        reason_code="LEVERAGED_LOSS_REDUCE",
                        reason="Leveraged ETF loss is worse than -20%; reduce or exit manually.",
                        priority="high",
                    ),
                )
            elif item.holding_profit_rate <= -15:
                suggestions.append(
                    _suggestion(
                        action="alert",
                        code=item.position.code,
                        reason_code="LEVERAGED_LOSS_ALERT",
                        reason="Leveraged ETF loss is worse than -15%; do not add.",
                        priority="high",
                    ),
                )
    return suggestions


def _single_stock_profit_suggestions(
    item: _Holding,
    *,
    total_equity: float,
) -> list[PortfolioStrategySuggestion]:
    for threshold, (profit_fraction, allocation) in _PROFIT_TAKE_TARGETS.items():
        if item.holding_profit_rate >= threshold:
            return [
                _suggestion(
                    action="sell",
                    code=item.position.code,
                    amount=max(0.0, item.holding_profit * profit_fraction),
                    total_equity=total_equity,
                    reason_code=f"SINGLE_STOCK_PROFIT_TAKE_{threshold}",
                    reason=(
                        f"Single-stock profit is above {threshold}%; "
                        f"sell {int(profit_fraction * 100)}% of unrealized profit amount."
                    ),
                    priority="medium" if threshold == 30 else "high",
                    allocation=allocation,
                ),
            ]
    return []


def _cash_deployment_suggestions(
    *,
    cash: float,
    total_equity: float,
    weights: dict[str, float],
) -> list[PortfolioStrategySuggestion]:
    if cash <= 0 or total_equity <= 0:
        return []
    if weights["cash_like"] < 8:
        return [
            _suggestion(
                action="buy",
                code="US.SGOV",
                amount=cash,
                total_equity=total_equity,
                reason_code="CASH_LIKE_BELOW_SAFE_LINE",
                reason="Cash-like assets are below 8%; prioritize SGOV/cash before risk assets.",
                priority="high",
            ),
        ]
    return [
        _suggestion(
            action="buy",
            code="US.VOO",
            amount=cash * 0.70,
            total_equity=total_equity,
            reason_code="DEFAULT_NEW_CASH_VOO",
            reason="Default new cash allocation: 70% VOO.",
            priority="low",
        ),
        _suggestion(
            action="buy",
            code="US.QQQM",
            amount=cash * 0.20,
            total_equity=total_equity,
            reason_code="DEFAULT_NEW_CASH_QQQM",
            reason="Default new cash allocation: 20% QQQM.",
            priority="low",
        ),
        _suggestion(
            action="buy",
            code="US.SGOV",
            amount=cash * 0.10,
            total_equity=total_equity,
            reason_code="DEFAULT_NEW_CASH_SGOV",
            reason="Default new cash allocation: 10% SGOV/cash.",
            priority="low",
        ),
    ]


def _to_asset(item: _Holding, *, total_equity: float) -> PortfolioStrategyAsset:
    return PortfolioStrategyAsset(
        code=item.position.code,
        name=item.position.name,
        category=item.category,
        quantity=item.position.quantity,
        current_price=item.current_price,
        cost_price=item.position.adjusted_cost_price or item.position.cost_price,
        market_value=item.market_value,
        cost_value=item.cost_value,
        holding_profit=item.holding_profit,
        holding_profit_rate=item.holding_profit_rate,
        weight=item.market_value / total_equity * 100 if total_equity else 0,
    )


def _suggestion(
    *,
    action: str,
    reason_code: str,
    reason: str,
    code: str = "",
    amount: float = 0,
    total_equity: float = 0,
    priority: str = "medium",
    allocation: dict[str, float] | None = None,
) -> PortfolioStrategySuggestion:
    return PortfolioStrategySuggestion(
        action=action,
        code=code,
        amount=amount,
        percent_of_equity=amount / total_equity * 100 if total_equity else 0,
        reason_code=reason_code,
        reason=reason,
        priority=priority,
        allocation=allocation or {},
    )


def _metric(
    key: str,
    label: str,
    value: float,
    *,
    target: float,
    lower: float,
    upper: float,
    breach: float | None = None,
) -> PortfolioStrategyMetric:
    status = "ok"
    detail = ""
    if value < lower:
        status = "warning"
        detail = "below_lower_bound"
    if value > upper:
        status = "warning"
        detail = "above_upper_bound"
    if breach is not None and value >= breach:
        status = "breach"
        detail = "above_hard_limit"
    return PortfolioStrategyMetric(
        key=key,
        label=label,
        value=value,
        target=target,
        lower_bound=lower,
        upper_bound=upper,
        status=status,
        detail=detail,
    )


def _sum_value(holdings: Iterable[_Holding], symbols: set[str]) -> float:
    return sum(item.market_value for item in holdings if item.symbol in symbols)


def _symbol(code: str) -> str:
    return code.strip().upper().split(".")[-1]


def _category(symbol: str) -> str:
    if symbol in _CORE_BROAD:
        return "core_broad_etf"
    if symbol in _CORE_GROWTH:
        return "core_growth_etf"
    if symbol in _CASH_LIKE:
        return "cash_like"
    if symbol in _QUALITY_TECH:
        return "quality_tech"
    if symbol in _SEMICONDUCTOR:
        return "semiconductor_ai_hardware"
    if symbol in _LEVERAGED:
        return "leveraged_etf"
    return "other"
