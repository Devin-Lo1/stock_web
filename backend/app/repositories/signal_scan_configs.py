from uuid import uuid4

from ..db.core import _connect
from ..db.converters import (
    _datetime_to_text,
    _now,
    _row_to_signal_scan_config,
    _signal_scan_config_values,
)
from ..schemas import SignalScanConfig, SignalScanConfigCreate, SignalScanConfigUpdate


def list_signal_scan_configs(*, enabled_only: bool = False) -> list[SignalScanConfig]:
    query = """
        SELECT id, strategy_code, strategy_name, parameters, enabled,
               push_candidate, sort_order, created_at, updated_at
        FROM signal_scan_configs
    """
    parameters: tuple[object, ...] = ()
    if enabled_only:
        query += " WHERE enabled = ?"
        parameters = (1,)
    query += " ORDER BY sort_order ASC, created_at ASC"

    with _connect() as connection:
        rows = connection.execute(query, parameters).fetchall()
    return [_row_to_signal_scan_config(row) for row in rows]


def get_signal_scan_config(config_id: str) -> SignalScanConfig | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, strategy_code, strategy_name, parameters, enabled,
                   push_candidate, sort_order, created_at, updated_at
            FROM signal_scan_configs
            WHERE id = ?
            """,
            (config_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_signal_scan_config(row)


def create_signal_scan_config(
    payload: SignalScanConfigCreate,
    *,
    config_id: str | None = None,
) -> SignalScanConfig:
    now = _now()
    config = SignalScanConfig(
        id=config_id or str(uuid4()),
        created_at=now,
        updated_at=now,
        **payload.model_dump(),
    )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO signal_scan_configs (
                id, strategy_code, strategy_name, parameters, enabled,
                push_candidate, sort_order, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _signal_scan_config_values(config),
        )
    return config


def update_signal_scan_config(
    config_id: str,
    payload: SignalScanConfigUpdate,
) -> SignalScanConfig | None:
    current = get_signal_scan_config(config_id)
    if current is None:
        return None

    update_data = payload.model_dump(exclude_none=True, exclude_unset=True)
    updated = current.model_copy(
        update={
            **update_data,
            "updated_at": _now(),
        },
    )
    with _connect() as connection:
        connection.execute(
            """
            UPDATE signal_scan_configs
            SET strategy_name = ?,
                parameters = ?,
                enabled = ?,
                push_candidate = ?,
                sort_order = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                updated.strategy_name,
                _signal_scan_config_values(updated)[3],
                1 if updated.enabled else 0,
                1 if updated.push_candidate else 0,
                updated.sort_order,
                _datetime_to_text(updated.updated_at),
                updated.id,
            ),
        )
    return updated


def replace_signal_scan_configs(
    configs: list[tuple[str, SignalScanConfigCreate]],
) -> list[SignalScanConfig]:
    now = _now()
    records = [
        SignalScanConfig(
            id=config_id,
            created_at=now,
            updated_at=now,
            **payload.model_dump(),
        )
        for config_id, payload in configs
    ]
    with _connect() as connection:
        connection.execute("DELETE FROM signal_scan_configs")
        for record in records:
            connection.execute(
                """
                INSERT INTO signal_scan_configs (
                    id, strategy_code, strategy_name, parameters, enabled,
                    push_candidate, sort_order, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                _signal_scan_config_values(record),
            )
    return records
