from uuid import uuid4

from ..db.core import _DatabaseConnection, _connect
from ..db.converters import (
    _datetime_to_text,
    _now,
    _position_trade_values,
    _row_to_position_trade,
)
from ..schemas import Position, PositionTrade, PositionTradeCreate
from ..services.trade_fees import calculate_default_position_trade_fee


class PositionTradeError(ValueError):
    pass


_POSITION_TRADE_COLUMNS = """
    id, position_id, market, code, name, currency, action, quantity,
    price, fee, trade_time, note, created_at, updated_at
"""


def list_position_trades(
    *,
    position_id: str | None = None,
    code: str | None = None,
    limit: int = 100,
) -> list[PositionTrade]:
    clauses: list[str] = []
    parameters: list[object] = []
    if position_id:
        clauses.append("position_id = ?")
        parameters.append(position_id)
    if code:
        clauses.append("code = ?")
        parameters.append(code.strip().upper())
    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    safe_limit = max(1, min(limit, 500))
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT {_POSITION_TRADE_COLUMNS}
            FROM position_trades
            {where_sql}
            ORDER BY trade_time DESC, created_at DESC
            LIMIT ?
            """,
            (*parameters, safe_limit),
        ).fetchall()
    return [_row_to_position_trade(row) for row in rows]


def create_position_trade_for_position(
    position: Position,
    payload: PositionTradeCreate,
) -> PositionTrade:
    trade = _build_position_trade(position, payload)
    updated_position = _apply_trade_to_position(position, trade)
    with _connect() as connection:
        _insert_position_trade(connection, trade)
        _update_position_snapshot(connection, updated_position)
    return trade


def delete_position_trade_for_position(position: Position, trade_id: str) -> bool:
    trade = get_position_trade(trade_id)
    if trade is None or trade.position_id != position.id:
        return False

    remaining_trades = _list_position_trades_for_replay(
        position_id=position.id,
        exclude_trade_id=trade_id,
    )
    updated_position = _replay_position_trades(position, remaining_trades)
    with _connect() as connection:
        cursor = connection.execute(
            "DELETE FROM position_trades WHERE id = ? AND position_id = ?",
            (trade_id, position.id),
        )
        if cursor.rowcount == 0:
            return False
        _update_position_snapshot(connection, updated_position)
    return True


def get_position_trade(trade_id: str) -> PositionTrade | None:
    with _connect() as connection:
        row = connection.execute(
            f"""
            SELECT {_POSITION_TRADE_COLUMNS}
            FROM position_trades
            WHERE id = ?
            """,
            (trade_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_position_trade(row)


def _list_position_trades_for_replay(
    *,
    position_id: str,
    exclude_trade_id: str,
) -> list[PositionTrade]:
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT {_POSITION_TRADE_COLUMNS}
            FROM position_trades
            WHERE position_id = ?
              AND id != ?
            ORDER BY trade_time ASC, created_at ASC
            """,
            (position_id, exclude_trade_id),
        ).fetchall()
    return [_row_to_position_trade(row) for row in rows]


def _replay_position_trades(
    position: Position,
    trades: list[PositionTrade],
) -> Position:
    replayed = position.model_copy(
        update={
            "quantity": 0,
            "cost_price": 0,
            "avg_cost_price": 0,
            "adjusted_cost_price": 0,
            "realized_profit": 0,
            "updated_at": _now(),
        },
    )
    for trade in trades:
        replayed = _apply_trade_to_position(replayed, trade)
    return replayed.model_copy(update={"updated_at": _now()})


def _build_position_trade(
    position: Position,
    payload: PositionTradeCreate,
    *,
    auto_fee: bool = True,
) -> PositionTrade:
    now = _now()
    fee = payload.fee
    if fee is None and auto_fee:
        fee = calculate_default_position_trade_fee(
            market=position.market,
            code=position.code,
            action=payload.action,
            quantity=payload.quantity,
            price=payload.price,
        )
    return PositionTrade(
        id=str(uuid4()),
        position_id=position.id,
        market=position.market,
        code=position.code.strip().upper(),
        name=position.name,
        currency=position.currency,
        action=payload.action,
        quantity=payload.quantity,
        price=payload.price,
        fee=fee or 0,
        trade_time=payload.trade_time or now,
        note=payload.note,
        created_at=now,
        updated_at=now,
    )


def _insert_position_trade(
    connection: _DatabaseConnection,
    trade: PositionTrade,
) -> None:
    connection.execute(
        """
        INSERT INTO position_trades (
            id, position_id, market, code, name, currency, action, quantity,
            price, fee, trade_time, note, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        _position_trade_values(trade),
    )


def _apply_trade_to_position(
    position: Position,
    trade: PositionTrade,
) -> Position:
    if trade.action == "open":
        return _apply_open_trade(position, trade)
    if trade.action == "add":
        return _apply_add_trade(position, trade)
    if trade.action == "reduce":
        return _apply_reduce_trade(position, trade)
    if trade.action == "close":
        return _apply_close_trade(position, trade)
    raise PositionTradeError(f"unsupported position trade action: {trade.action}")


def _apply_open_trade(position: Position, trade: PositionTrade) -> Position:
    if position.quantity > 0:
        raise PositionTradeError("open trade is only allowed for an empty position")
    cost_price = _cost_price(trade.quantity, trade.price, trade.fee)
    return position.model_copy(
        update={
            "quantity": trade.quantity,
            "cost_price": cost_price,
            "avg_cost_price": cost_price,
            "adjusted_cost_price": cost_price,
            "updated_at": trade.created_at,
        },
    )


def _apply_add_trade(position: Position, trade: PositionTrade) -> Position:
    new_quantity = position.quantity + trade.quantity
    current_avg_cost = position.quantity * _avg_cost_price(position)
    current_adjusted_cost = position.quantity * _adjusted_cost_price(position)
    added_cost = trade.quantity * trade.price + trade.fee
    avg_cost_price = (current_avg_cost + added_cost) / new_quantity
    adjusted_cost_price = (current_adjusted_cost + added_cost) / new_quantity
    return position.model_copy(
        update={
            "quantity": new_quantity,
            "cost_price": _display_cost_price(adjusted_cost_price),
            "avg_cost_price": avg_cost_price,
            "adjusted_cost_price": adjusted_cost_price,
            "updated_at": trade.created_at,
        },
    )


def _apply_reduce_trade(position: Position, trade: PositionTrade) -> Position:
    _ensure_can_reduce(position, trade.quantity)
    new_quantity = position.quantity - trade.quantity
    realized_profit = position.realized_profit + _realized_profit(position, trade)
    adjusted_cost_price = _remaining_adjusted_cost_price(
        position,
        trade,
        new_quantity,
    )
    cost_price = _display_cost_price(adjusted_cost_price) if new_quantity > 0 else 0
    return position.model_copy(
        update={
            "quantity": new_quantity,
            "cost_price": cost_price,
            "avg_cost_price": _avg_cost_price(position) if new_quantity > 0 else 0,
            "adjusted_cost_price": adjusted_cost_price if new_quantity > 0 else 0,
            "realized_profit": realized_profit,
            "updated_at": trade.created_at,
        },
    )


def _apply_close_trade(position: Position, trade: PositionTrade) -> Position:
    _ensure_can_reduce(position, trade.quantity)
    if abs(position.quantity - trade.quantity) > 1e-9:
        raise PositionTradeError("close trade quantity must equal current position")
    realized_profit = position.realized_profit + _realized_profit(position, trade)
    return position.model_copy(
        update={
            "quantity": 0,
            "cost_price": 0,
            "avg_cost_price": 0,
            "adjusted_cost_price": 0,
            "realized_profit": realized_profit,
            "updated_at": trade.created_at,
        },
    )


def _ensure_can_reduce(position: Position, quantity: float) -> None:
    if position.quantity <= 0:
        raise PositionTradeError("position has no quantity to reduce")
    if quantity - position.quantity > 1e-9:
        raise PositionTradeError("trade quantity exceeds current position")


def _cost_price(quantity: float, price: float, fee: float) -> float:
    return (quantity * price + fee) / quantity


def _avg_cost_price(position: Position) -> float:
    return position.avg_cost_price or position.cost_price


def _adjusted_cost_price(position: Position) -> float:
    return position.adjusted_cost_price or position.cost_price


def _realized_profit(position: Position, trade: PositionTrade) -> float:
    net_proceeds = trade.quantity * trade.price - trade.fee
    cost_basis = trade.quantity * _avg_cost_price(position)
    return net_proceeds - cost_basis


def _remaining_adjusted_cost_price(
    position: Position,
    trade: PositionTrade,
    new_quantity: float,
) -> float:
    if new_quantity <= 0:
        return 0
    current_adjusted_cost = position.quantity * _adjusted_cost_price(position)
    net_proceeds = trade.quantity * trade.price - trade.fee
    return (current_adjusted_cost - net_proceeds) / new_quantity


def _display_cost_price(adjusted_cost_price: float) -> float:
    return max(0, adjusted_cost_price)


def _update_position_snapshot(
    connection: _DatabaseConnection,
    position: Position,
) -> None:
    connection.execute(
        """
        UPDATE positions
        SET quantity = ?,
            cost_price = ?,
            avg_cost_price = ?,
            adjusted_cost_price = ?,
            realized_profit = ?,
            updated_at = ?
        WHERE id = ?
        """,
        (
            position.quantity,
            position.cost_price,
            position.avg_cost_price,
            position.adjusted_cost_price,
            position.realized_profit,
            _datetime_to_text(position.updated_at),
            position.id,
        ),
    )
