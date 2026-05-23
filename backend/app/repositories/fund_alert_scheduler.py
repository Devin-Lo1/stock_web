import json
import re
from datetime import datetime
from typing import Any

from ..db.converters import _datetime_to_text, _now, _optional_text_to_datetime
from ..db.core import _connect
from ..schemas import FundAlertSchedulerStatus, FundAlertSchedulerUpdate

_CONFIG_ID = "default"
_DEFAULT_REMINDER_TIMES = ["14:30"]
_TIME_RE = re.compile(r"^(\d|[01]\d|2[0-3]):([0-5]\d)$")


def get_fund_alert_scheduler_config() -> FundAlertSchedulerStatus:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT enabled, reminder_times, due_window_minutes, last_scan_at,
                   last_scan_key, last_error, last_result, updated_at
            FROM fund_alert_scheduler
            WHERE id = ?
            """,
            (_CONFIG_ID,),
        ).fetchone()
        if row is None:
            config = _default_config()
            connection.execute(
                """
                INSERT INTO fund_alert_scheduler (
                    id, enabled, reminder_times, due_window_minutes,
                    last_scan_at, last_scan_key, last_error, last_result, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                _config_values(config),
            )
            return config
    return _row_to_config(row)


def update_fund_alert_scheduler_config(
    payload: FundAlertSchedulerUpdate,
) -> FundAlertSchedulerStatus:
    current = get_fund_alert_scheduler_config()
    reminder_times = current.reminder_times
    if payload.reminder_times is not None:
        reminder_times = _normalize_times(payload.reminder_times)
    updated = current.model_copy(
        update={
            "enabled": payload.enabled
            if payload.enabled is not None
            else current.enabled,
            "reminder_times": reminder_times,
            "due_window_minutes": payload.due_window_minutes
            if payload.due_window_minutes is not None
            else current.due_window_minutes,
        },
    )
    _save_config(updated)
    return updated


def record_fund_alert_scan_result(
    *,
    scan_key: str,
    scan_at: datetime,
    result: dict[str, Any],
    error: str = "",
) -> FundAlertSchedulerStatus:
    current = get_fund_alert_scheduler_config()
    updated = current.model_copy(
        update={
            "last_scan_at": scan_at,
            "last_scan_key": scan_key,
            "last_error": error,
            "last_result": result,
        },
    )
    _save_config(updated)
    return updated


def _save_config(config: FundAlertSchedulerStatus) -> None:
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO fund_alert_scheduler (
                id, enabled, reminder_times, due_window_minutes, last_scan_at,
                last_scan_key, last_error, last_result, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                enabled = excluded.enabled,
                reminder_times = excluded.reminder_times,
                due_window_minutes = excluded.due_window_minutes,
                last_scan_at = excluded.last_scan_at,
                last_scan_key = excluded.last_scan_key,
                last_error = excluded.last_error,
                last_result = excluded.last_result,
                updated_at = excluded.updated_at
            """,
            _config_values(config),
        )


def _default_config() -> FundAlertSchedulerStatus:
    return FundAlertSchedulerStatus(
        enabled=False,
        reminder_times=list(_DEFAULT_REMINDER_TIMES),
        due_window_minutes=10,
    )


def _row_to_config(row) -> FundAlertSchedulerStatus:
    return FundAlertSchedulerStatus(
        enabled=bool(row["enabled"]),
        reminder_times=_normalize_times(_json_from_text(row["reminder_times"])),
        due_window_minutes=int(row["due_window_minutes"]),
        last_scan_at=_optional_text_to_datetime(row["last_scan_at"]),
        last_scan_key=row["last_scan_key"],
        last_error=row["last_error"],
        last_result=_json_from_text(row["last_result"]),
    )


def _config_values(config: FundAlertSchedulerStatus) -> tuple[object, ...]:
    now = _now()
    return (
        _CONFIG_ID,
        1 if config.enabled else 0,
        json.dumps(_normalize_times(config.reminder_times), ensure_ascii=False),
        config.due_window_minutes,
        _datetime_to_text(config.last_scan_at) if config.last_scan_at else None,
        config.last_scan_key,
        config.last_error,
        json.dumps(config.last_result, ensure_ascii=False, sort_keys=True),
        _datetime_to_text(now),
    )


def _json_from_text(value: str | list[str] | dict[str, Any] | None):
    if value is None or value == "":
        return {}
    if isinstance(value, (list, dict)):
        return value
    return json.loads(value)


def _normalize_times(values: list[str] | object) -> list[str]:
    if not isinstance(values, list):
        return list(_DEFAULT_REMINDER_TIMES)
    normalized_set: set[str] = set()
    for value in values:
        match = _TIME_RE.match(str(value).strip())
        if match is None:
            continue
        hour = int(match.group(1))
        minute = match.group(2)
        normalized_set.add(f"{hour:02d}:{minute}")
    normalized = sorted(normalized_set)
    return normalized or list(_DEFAULT_REMINDER_TIMES)
