from datetime import datetime
from uuid import uuid4

from ..db.core import _connect
from ..db.converters import (
    _datetime_to_text,
    _now,
    _row_to_strategy_monitor,
    _strategy_monitor_values,
)
from ..schemas import StrategyMonitor, StrategyMonitorCreate, StrategyMonitorUpdate


_STRATEGY_MONITOR_SELECT = """
    SELECT id, position_id, market, code, name, strategy_code, strategy_name,
           parameters, period, scan_interval_minutes, cooldown_minutes, enabled,
           push_candidate, source_backtest_run_id, last_scanned_at,
           last_triggered_at, last_signal_event_id, created_at, updated_at
    FROM strategy_monitors
"""


def list_strategy_monitors(
    *,
    position_id: str | None = None,
    code: str | None = None,
    strategy_code: str | None = None,
    enabled_only: bool = False,
    limit: int = 100,
) -> list[StrategyMonitor]:
    clauses: list[str] = []
    parameters: list[object] = []
    if position_id:
        clauses.append("position_id = ?")
        parameters.append(position_id.strip())
    if code:
        clauses.append("UPPER(code) = ?")
        parameters.append(code.strip().upper())
    if strategy_code:
        clauses.append("strategy_code = ?")
        parameters.append(strategy_code.strip())
    if enabled_only:
        clauses.append("enabled = ?")
        parameters.append(1)

    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    bounded_limit = max(1, min(limit, 500))
    parameters.append(bounded_limit)
    with _connect() as connection:
        rows = connection.execute(
            f"""
            {_STRATEGY_MONITOR_SELECT}
            {where_sql}
            ORDER BY updated_at DESC
            LIMIT ?
            """,
            tuple(parameters),
        ).fetchall()
    return [_row_to_strategy_monitor(row) for row in rows]


def get_strategy_monitor(monitor_id: str) -> StrategyMonitor | None:
    with _connect() as connection:
        row = connection.execute(
            f"""
            {_STRATEGY_MONITOR_SELECT}
            WHERE id = ?
            """,
            (monitor_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_strategy_monitor(row)


def create_strategy_monitor(
    payload: StrategyMonitorCreate,
    *,
    monitor_id: str | None = None,
) -> StrategyMonitor:
    now = _now()
    monitor = StrategyMonitor(
        id=monitor_id or str(uuid4()),
        last_scanned_at=None,
        last_triggered_at=None,
        last_signal_event_id=None,
        created_at=now,
        updated_at=now,
        **_normalize_monitor_data(payload.model_dump()),
    )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO strategy_monitors (
                id, position_id, market, code, name, strategy_code, strategy_name,
                parameters, period, scan_interval_minutes, cooldown_minutes,
                enabled, push_candidate, source_backtest_run_id, last_scanned_at,
                last_triggered_at, last_signal_event_id, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _strategy_monitor_values(monitor),
        )
    return monitor


def update_strategy_monitor(
    monitor_id: str,
    payload: StrategyMonitorUpdate,
) -> StrategyMonitor | None:
    current = get_strategy_monitor(monitor_id)
    if current is None:
        return None

    update_data = _normalize_monitor_data(payload.model_dump(exclude_unset=True))
    updated = current.model_copy(
        update={
            **update_data,
            "updated_at": _now(),
        },
    )
    _save_strategy_monitor(updated)
    return updated


def update_strategy_monitor_scan_state(
    monitor_id: str,
    *,
    last_scanned_at: datetime,
    last_triggered_at: datetime | None = None,
    last_signal_event_id: str | None = None,
) -> StrategyMonitor | None:
    current = get_strategy_monitor(monitor_id)
    if current is None:
        return None

    update_data: dict[str, object | None] = {
        "last_scanned_at": last_scanned_at,
        "updated_at": _now(),
    }
    if last_triggered_at is not None:
        update_data["last_triggered_at"] = last_triggered_at
    if last_signal_event_id is not None:
        update_data["last_signal_event_id"] = last_signal_event_id

    updated = current.model_copy(update=update_data)
    with _connect() as connection:
        connection.execute(
            """
            UPDATE strategy_monitors
            SET last_scanned_at = ?,
                last_triggered_at = ?,
                last_signal_event_id = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                _datetime_to_text(updated.last_scanned_at),
                (
                    _datetime_to_text(updated.last_triggered_at)
                    if updated.last_triggered_at is not None
                    else None
                ),
                updated.last_signal_event_id,
                _datetime_to_text(updated.updated_at),
                updated.id,
            ),
        )
    return updated


def delete_strategy_monitor(monitor_id: str) -> bool:
    with _connect() as connection:
        exists = connection.execute(
            "SELECT 1 FROM strategy_monitors WHERE id = ?",
            (monitor_id,),
        ).fetchone()
        if exists is None:
            return False
        connection.execute("DELETE FROM strategy_monitors WHERE id = ?", (monitor_id,))
    return True


def _save_strategy_monitor(monitor: StrategyMonitor) -> None:
    with _connect() as connection:
        connection.execute(
            """
            UPDATE strategy_monitors
            SET position_id = ?,
                market = ?,
                code = ?,
                name = ?,
                strategy_code = ?,
                strategy_name = ?,
                parameters = ?,
                period = ?,
                scan_interval_minutes = ?,
                cooldown_minutes = ?,
                enabled = ?,
                push_candidate = ?,
                source_backtest_run_id = ?,
                last_scanned_at = ?,
                last_triggered_at = ?,
                last_signal_event_id = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                *_strategy_monitor_values(monitor)[1:17],
                _datetime_to_text(monitor.updated_at),
                monitor.id,
            ),
        )


def _normalize_monitor_data(data: dict[str, object]) -> dict[str, object]:
    normalized = dict(data)
    if isinstance(normalized.get("position_id"), str):
        normalized["position_id"] = normalized["position_id"].strip()
    if isinstance(normalized.get("code"), str):
        normalized["code"] = normalized["code"].strip().upper()
    if isinstance(normalized.get("name"), str):
        normalized["name"] = normalized["name"].strip()
    if isinstance(normalized.get("strategy_code"), str):
        normalized["strategy_code"] = normalized["strategy_code"].strip()
    if isinstance(normalized.get("strategy_name"), str):
        normalized["strategy_name"] = normalized["strategy_name"].strip()
    if isinstance(normalized.get("period"), str):
        normalized["period"] = normalized["period"].strip().lower()
    if isinstance(normalized.get("source_backtest_run_id"), str):
        normalized["source_backtest_run_id"] = normalized["source_backtest_run_id"].strip()
    return normalized
