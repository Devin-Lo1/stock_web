from ..db.core import _connect
from ..db.converters import (
    _position_snapshot_values,
    _row_to_position_snapshot,
)
from ..schemas import PositionSnapshot


_POSITION_SNAPSHOT_COLUMNS = """
    id, position_id, market, code, name, currency, quantity,
    avg_cost_price, adjusted_cost_price, realized_profit,
    current_price, previous_close, market_value,
    day_profit, day_profit_rate, holding_profit, holding_profit_rate,
    total_profit, total_profit_rate, position_weight,
    snapshot_time, created_at
"""


def save_position_snapshots(
    snapshots: list[PositionSnapshot],
) -> list[PositionSnapshot]:
    if not snapshots:
        return []
    with _connect() as connection:
        connection.executemany(
            """
            INSERT INTO position_snapshots (
                id, position_id, market, code, name, currency, quantity,
                avg_cost_price, adjusted_cost_price, realized_profit,
                current_price, previous_close, market_value,
                day_profit, day_profit_rate, holding_profit, holding_profit_rate,
                total_profit, total_profit_rate, position_weight,
                snapshot_time, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [_position_snapshot_values(snapshot) for snapshot in snapshots],
        )
    return snapshots


def list_position_snapshots(
    *,
    position_id: str | None = None,
    code: str | None = None,
    limit: int = 200,
) -> list[PositionSnapshot]:
    clauses: list[str] = []
    parameters: list[object] = []
    if position_id:
        clauses.append("position_id = ?")
        parameters.append(position_id)
    if code:
        clauses.append("code = ?")
        parameters.append(code.strip().upper())
    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    safe_limit = max(1, min(limit, 1000))
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT {_POSITION_SNAPSHOT_COLUMNS}
            FROM position_snapshots
            {where_sql}
            ORDER BY snapshot_time DESC, created_at DESC
            LIMIT ?
            """,
            (*parameters, safe_limit),
        ).fetchall()
    return [_row_to_position_snapshot(row) for row in rows]


def list_latest_position_snapshots() -> list[PositionSnapshot]:
    rows = list_position_snapshots(limit=1000)
    latest_by_position: dict[str, PositionSnapshot] = {}
    for row in rows:
        latest_by_position.setdefault(row.position_id, row)
    return list(latest_by_position.values())
