from uuid import uuid4

from ..db.converters import _now
from ..repositories.market_data import get_quotes
from ..repositories.position_snapshots import save_position_snapshots
from ..repositories.positions import list_positions
from ..schemas import Position, PositionSnapshot, QuoteSnapshot


def capture_position_snapshots() -> list[PositionSnapshot]:
    positions = list_positions()
    if not positions:
        return []

    quote_by_code = {
        quote.code.strip().upper(): quote
        for quote in get_quotes([position.code for position in positions])
    }
    market_values = [
        _market_value(position, quote_by_code.get(position.code.strip().upper()))
        for position in positions
    ]
    total_market_value = sum(market_values)
    now = _now()
    snapshots = [
        _build_position_snapshot(
            position,
            quote,
            total_market_value=total_market_value,
            created_at=now,
        )
        for position in positions
        if (quote := quote_by_code.get(position.code.strip().upper())) is not None
    ]
    return save_position_snapshots(snapshots)


def _build_position_snapshot(
    position: Position,
    quote: QuoteSnapshot,
    *,
    total_market_value: float,
    created_at,
) -> PositionSnapshot:
    market_value = _market_value(position, quote)
    day_profit = position.quantity * (quote.current_price - quote.previous_close)
    day_profit_rate = _rate(day_profit, position.quantity * quote.previous_close)
    holding_profit = position.quantity * (
        quote.current_price - position.adjusted_cost_price
    )
    holding_cost = position.quantity * position.adjusted_cost_price
    total_profit = position.realized_profit + holding_profit
    total_cost = holding_cost + abs(position.realized_profit)
    return PositionSnapshot(
        id=str(uuid4()),
        position_id=position.id,
        market=position.market,
        code=position.code,
        name=position.name,
        currency=position.currency,
        quantity=position.quantity,
        avg_cost_price=position.avg_cost_price,
        adjusted_cost_price=position.adjusted_cost_price,
        realized_profit=position.realized_profit,
        current_price=quote.current_price,
        previous_close=quote.previous_close,
        market_value=market_value,
        day_profit=day_profit,
        day_profit_rate=day_profit_rate,
        holding_profit=holding_profit,
        holding_profit_rate=_rate(holding_profit, holding_cost),
        total_profit=total_profit,
        total_profit_rate=_rate(total_profit, total_cost),
        position_weight=_rate(market_value, total_market_value),
        snapshot_time=quote.quote_time,
        created_at=created_at,
    )


def _market_value(position: Position, quote: QuoteSnapshot | None) -> float:
    if quote is None:
        return 0
    return position.quantity * quote.current_price


def _rate(value: float, base: float) -> float:
    if abs(base) <= 1e-9:
        return 0
    return value / base * 100
