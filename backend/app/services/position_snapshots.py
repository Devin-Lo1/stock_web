from uuid import uuid4

from ..db.converters import _now
from ..repositories.market_data import get_quotes
from ..repositories.position_snapshots import save_position_snapshots
from ..repositories.position_trades import list_position_trades
from ..repositories.positions import list_positions
from ..schemas import Position, PositionSnapshot, PositionTrade, QuoteSnapshot


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
    trade_by_position = {
        position.id: list_position_trades(position_id=position.id, limit=500)
        for position in positions
    }
    now = _now()
    snapshots = [
        _build_position_snapshot(
            position,
            quote,
            trades=trade_by_position.get(position.id, []),
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
    trades: list[PositionTrade],
    total_market_value: float,
    created_at,
) -> PositionSnapshot:
    market_value = _market_value(position, quote)
    day_profit, day_profit_base = _day_profit(position, quote, trades)
    day_profit_rate = _rate(day_profit, day_profit_base)
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


def _day_profit(
    position: Position,
    quote: QuoteSnapshot,
    trades: list[PositionTrade],
) -> tuple[float, float]:
    trade_day = quote.quote_time.date()
    same_day_trades = [
        trade for trade in trades if trade.trade_time.date() == trade_day
    ]
    if not same_day_trades:
        base = position.quantity * quote.previous_close
        return position.quantity * (quote.current_price - quote.previous_close), base

    today_lots: list[tuple[float, float]] = []
    for trade in sorted(same_day_trades, key=lambda item: item.trade_time):
        if trade.action in {"open", "add"}:
            unit_cost = (trade.quantity * trade.price + trade.fee) / trade.quantity
            today_lots.append((trade.quantity, unit_cost))
            continue
        if trade.action in {"reduce", "close"}:
            quantity_to_remove = trade.quantity
            updated_lots: list[tuple[float, float]] = []
            for lot_quantity, lot_unit_cost in today_lots:
                if quantity_to_remove <= 0:
                    updated_lots.append((lot_quantity, lot_unit_cost))
                    continue
                removed_quantity = min(lot_quantity, quantity_to_remove)
                quantity_to_remove -= removed_quantity
                remaining_quantity = lot_quantity - removed_quantity
                if remaining_quantity > 1e-9:
                    updated_lots.append((remaining_quantity, lot_unit_cost))
            today_lots = updated_lots

    remaining_today_quantity = sum(quantity for quantity, _ in today_lots)
    today_profit = sum(
        quantity * (quote.current_price - unit_cost)
        for quantity, unit_cost in today_lots
    )
    today_base = sum(quantity * unit_cost for quantity, unit_cost in today_lots)
    overnight_quantity = max(0.0, position.quantity - remaining_today_quantity)
    overnight_base = overnight_quantity * quote.previous_close
    overnight_profit = overnight_quantity * (quote.current_price - quote.previous_close)
    return overnight_profit + today_profit, overnight_base + today_base


def _rate(value: float, base: float) -> float:
    if abs(base) <= 1e-9:
        return 0
    return value / base * 100
