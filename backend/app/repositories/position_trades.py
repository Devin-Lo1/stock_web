from uuid import uuid4

from ..db.core import _DatabaseConnection, _connect
from ..db.converters import (
    _position_trade_values,
    _row_to_position_trade,
    _now,
)
from ..schemas import Position, PositionTrade, PositionTradeCreate


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
    with _connect() as connection:
        _insert_position_trade(connection, trade)
    return trade


def _build_position_trade(
    position: Position,
    payload: PositionTradeCreate,
) -> PositionTrade:
    now = _now()
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
        fee=payload.fee,
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
