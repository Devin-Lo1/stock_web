from uuid import uuid4

from ..schemas import Position, PositionCreate, PositionTradeCreate, PositionUpdate
from ..db.core import _connect
from ..db.converters import (
    _datetime_to_text,
    _now,
    _position_values,
    _row_to_position,
)
from .position_trades import _build_position_trade, _insert_position_trade


def list_positions() -> list[Position]:
    with _connect() as connection:
        rows = connection.execute(
            """
            SELECT id, market, code, name, quantity, cost_price, currency,
                   created_at, updated_at
            FROM positions
            ORDER BY created_at ASC
            """,
        ).fetchall()
    return [_row_to_position(row) for row in rows]


def create_position(payload: PositionCreate) -> Position:
    now = _now()
    position = Position(
        id=str(uuid4()),
        created_at=now,
        updated_at=now,
        **payload.model_dump(),
    )
    opening_trade = None
    if position.quantity > 0:
        opening_trade = _build_position_trade(
            position,
            PositionTradeCreate(
                action="open",
                quantity=position.quantity,
                price=position.cost_price,
            ),
        )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO positions (
                id, market, code, name, quantity, cost_price, currency,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _position_values(position),
        )
        if opening_trade is not None:
            _insert_position_trade(connection, opening_trade)
    return position


def update_position(position_id: str, payload: PositionUpdate) -> Position | None:
    current = get_position(position_id)
    if current is None:
        return None

    update_data = payload.model_dump(exclude_unset=True)
    updated = current.model_copy(
        update={
            **update_data,
            "updated_at": _now(),
        },
    )
    with _connect() as connection:
        connection.execute(
            """
            UPDATE positions
            SET market = ?,
                code = ?,
                name = ?,
                quantity = ?,
                cost_price = ?,
                currency = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                updated.market,
                updated.code,
                updated.name,
                updated.quantity,
                updated.cost_price,
                updated.currency,
                _datetime_to_text(updated.updated_at),
                updated.id,
            ),
        )
    return updated


def delete_position(position_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute(
            "DELETE FROM positions WHERE id = ?",
            (position_id,),
        )
    return cursor.rowcount > 0


def get_position(position_id: str) -> Position | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, market, code, name, quantity, cost_price, currency,
                   created_at, updated_at
            FROM positions
            WHERE id = ?
            """,
            (position_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_position(row)
