from uuid import uuid4

from ..db.core import _connect
from ..db.converters import (
    _now,
    _row_to_strategy_monitor_scan_log,
    _strategy_monitor_scan_log_values,
)
from ..schemas import StrategyMonitorScanLog, StrategyMonitorScanLogCreate


_STRATEGY_MONITOR_SCAN_LOG_SELECT = """
    SELECT id, monitor_id, code, strategy_code, stage, status, message, detail,
           scanned_at, created_at
    FROM strategy_monitor_scan_logs
"""


def create_strategy_monitor_scan_log(
    payload: StrategyMonitorScanLogCreate,
    *,
    log_id: str | None = None,
) -> StrategyMonitorScanLog:
    now = _now()
    log = StrategyMonitorScanLog(
        id=log_id or str(uuid4()),
        monitor_id=payload.monitor_id.strip(),
        code=payload.code.strip().upper(),
        strategy_code=payload.strategy_code.strip(),
        stage=payload.stage.strip(),
        status=payload.status.strip(),
        message=payload.message.strip(),
        detail=payload.detail,
        scanned_at=payload.scanned_at or now,
        created_at=now,
    )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO strategy_monitor_scan_logs (
                id, monitor_id, code, strategy_code, stage, status, message,
                detail, scanned_at, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _strategy_monitor_scan_log_values(log),
        )
    return log


def list_strategy_monitor_scan_logs(
    *,
    monitor_id: str | None = None,
    code: str | None = None,
    status: str | None = None,
    limit: int = 50,
) -> list[StrategyMonitorScanLog]:
    clauses: list[str] = []
    parameters: list[object] = []
    if monitor_id:
        clauses.append("monitor_id = ?")
        parameters.append(monitor_id.strip())
    if code:
        clauses.append("UPPER(code) = ?")
        parameters.append(code.strip().upper())
    if status:
        clauses.append("status = ?")
        parameters.append(status.strip())

    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    bounded_limit = max(1, min(limit, 200))
    parameters.append(bounded_limit)
    with _connect() as connection:
        rows = connection.execute(
            f"""
            {_STRATEGY_MONITOR_SCAN_LOG_SELECT}
            {where_sql}
            ORDER BY scanned_at DESC, created_at DESC
            LIMIT ?
            """,
            tuple(parameters),
        ).fetchall()
    return [_row_to_strategy_monitor_scan_log(row) for row in rows]


def delete_strategy_monitor_scan_log(log_id: str) -> bool:
    with _connect() as connection:
        exists = connection.execute(
            "SELECT 1 FROM strategy_monitor_scan_logs WHERE id = ?",
            (log_id,),
        ).fetchone()
        if exists is None:
            return False
        connection.execute(
            "DELETE FROM strategy_monitor_scan_logs WHERE id = ?",
            (log_id,),
        )
    return True
