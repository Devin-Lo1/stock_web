from uuid import uuid4

from ..db.core import _connect
from ..db.converters import (
    _datetime_to_text,
    _notification_device_values,
    _now,
    _push_record_values,
    _row_to_notification_device,
    _row_to_push_record,
    _row_to_signal_event,
    _signal_event_values,
)
from ..schemas import (
    NotificationDevice,
    NotificationDeviceUpsert,
    PushRecord,
    PushRecordCreate,
    SignalEvent,
    SignalEventCreate,
)


def create_signal_event(payload: SignalEventCreate) -> SignalEvent:
    now = _now()
    data = payload.model_dump(exclude={"triggered_at"})
    data["code"] = data["code"].strip().upper()
    event = SignalEvent(
        id=str(uuid4()),
        triggered_at=payload.triggered_at or now,
        read_status="unread",
        read_at=None,
        created_at=now,
        updated_at=now,
        **data,
    )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO signal_events (
                id, source, code, signal_type, level, title, message,
                trigger_value, threshold_value, dedupe_key, payload,
                read_status, read_at, triggered_at, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _signal_event_values(event),
        )
    return event


def get_signal_event_by_dedupe_key(dedupe_key: str) -> SignalEvent | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, source, code, signal_type, level, title, message,
                   trigger_value, threshold_value, dedupe_key, payload,
                   read_status, read_at, triggered_at, created_at, updated_at
            FROM signal_events
            WHERE dedupe_key = ?
            ORDER BY triggered_at DESC
            LIMIT 1
            """,
            (dedupe_key,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_signal_event(row)


def get_signal_event(event_id: str) -> SignalEvent | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, source, code, signal_type, level, title, message,
                   trigger_value, threshold_value, dedupe_key, payload,
                   read_status, read_at, triggered_at, created_at, updated_at
            FROM signal_events
            WHERE id = ?
            """,
            (event_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_signal_event(row)


def list_signal_events(
    *,
    code: str | None = None,
    signal_type: str | None = None,
    read_status: str | None = None,
    level: str | None = None,
    source_category: str | None = None,
    strategy_code: str | None = None,
    push_candidate: bool | None = None,
    limit: int = 50,
) -> list[SignalEvent]:
    clauses: list[str] = []
    parameters: list[object] = []
    if code:
        clauses.append("code = ?")
        parameters.append(code.strip().upper())
    if signal_type:
        clauses.append("signal_type = ?")
        parameters.append(signal_type.strip())
    if read_status:
        clauses.append("read_status = ?")
        parameters.append(read_status)
    if level:
        clauses.append("level = ?")
        parameters.append(level)
    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    safe_limit = max(1, min(limit, 200))
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT id, source, code, signal_type, level, title, message,
                   trigger_value, threshold_value, dedupe_key, payload,
                   read_status, read_at, triggered_at, created_at, updated_at
            FROM signal_events
            {where_sql}
            ORDER BY triggered_at DESC
            """,
            tuple(parameters),
        ).fetchall()
    events = [_row_to_signal_event(row) for row in rows]
    return [
        event
        for event in events
        if _matches_payload_filters(
            event,
            source_category=source_category,
            strategy_code=strategy_code,
            push_candidate=push_candidate,
        )
    ][:safe_limit]


def mark_signal_event_read(event_id: str) -> SignalEvent | None:
    return _mark_signal_event_status(event_id, "read")


def mark_signal_event_ignored(event_id: str) -> SignalEvent | None:
    return _mark_signal_event_status(event_id, "ignored")


def _mark_signal_event_status(
    event_id: str,
    read_status: str,
) -> SignalEvent | None:
    now = _now()
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id
            FROM signal_events
            WHERE id = ?
            """,
            (event_id,),
        ).fetchone()
        if row is None:
            return None
        connection.execute(
            """
            UPDATE signal_events
            SET read_status = ?,
                read_at = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (read_status, _datetime_to_text(now), _datetime_to_text(now), event_id),
        )
        updated = connection.execute(
            """
            SELECT id, source, code, signal_type, level, title, message,
                   trigger_value, threshold_value, dedupe_key, payload,
                   read_status, read_at, triggered_at, created_at, updated_at
            FROM signal_events
            WHERE id = ?
            """,
            (event_id,),
        ).fetchone()
    return _row_to_signal_event(updated)


def _matches_payload_filters(
    event: SignalEvent,
    *,
    source_category: str | None,
    strategy_code: str | None,
    push_candidate: bool | None,
) -> bool:
    if source_category and _event_source_category(event) != source_category:
        return False
    if strategy_code:
        value = str(event.payload.get("strategy_code", "")).strip()
        if value != strategy_code:
            return False
    if push_candidate is not None:
        value = event.payload.get("push_candidate", False)
        if bool(value) is not push_candidate:
            return False
    return True


def _event_source_category(event: SignalEvent) -> str:
    value = str(event.payload.get("source_category", "")).strip()
    if value:
        return value
    if event.source == "test" or event.code == "TEST":
        return "system"
    if event.source == "strategy_scanner":
        return "strategy"
    return ""


def upsert_notification_device(
    payload: NotificationDeviceUpsert,
) -> NotificationDevice:
    device, _ = upsert_notification_device_with_signal_count(payload, signal_limit=0)
    return device


def upsert_notification_device_with_signal_count(
    payload: NotificationDeviceUpsert,
    *,
    signal_limit: int = 20,
) -> tuple[NotificationDevice, int]:
    now = _now()
    safe_signal_limit = max(0, min(signal_limit, 200))
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, platform, push_provider, push_token, device_name,
                   app_version, enabled, important_enabled, last_seen_at,
                   created_at, updated_at
            FROM notification_devices
            WHERE push_provider = ? AND push_token = ?
            """,
            (payload.push_provider, payload.push_token),
        ).fetchone()
        if row is None:
            device = NotificationDevice(
                id=str(uuid4()),
                last_seen_at=now,
                created_at=now,
                updated_at=now,
                **payload.model_dump(),
            )
            connection.execute(
                """
                INSERT INTO notification_devices (
                    id, platform, push_provider, push_token, device_name,
                    app_version, enabled, important_enabled, last_seen_at,
                    created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                _notification_device_values(device),
            )
        else:
            existing = _row_to_notification_device(row)
            device = existing.model_copy(
                update={
                    **payload.model_dump(),
                    "last_seen_at": now,
                    "updated_at": now,
                },
            )
            connection.execute(
                """
                UPDATE notification_devices
                SET platform = ?,
                    device_name = ?,
                    app_version = ?,
                    enabled = ?,
                    important_enabled = ?,
                    last_seen_at = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                (
                    device.platform,
                    device.device_name,
                    device.app_version,
                    1 if device.enabled else 0,
                    1 if device.important_enabled else 0,
                    _datetime_to_text(device.last_seen_at),
                    _datetime_to_text(device.updated_at),
                    device.id,
                ),
            )
        signal_count = 0
        if safe_signal_limit > 0:
            count_row = connection.execute(
                """
                SELECT COUNT(*) AS signal_count
                FROM (
                    SELECT id
                    FROM signal_events
                    ORDER BY triggered_at DESC
                    LIMIT ?
                ) latest
                """,
                (safe_signal_limit,),
            ).fetchone()
            if count_row is not None:
                signal_count = int(count_row["signal_count"])
    return device, signal_count


def get_notification_device_by_token(
    push_provider: str,
    push_token: str,
) -> NotificationDevice | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, platform, push_provider, push_token, device_name,
                   app_version, enabled, important_enabled, last_seen_at,
                   created_at, updated_at
            FROM notification_devices
            WHERE push_provider = ? AND push_token = ?
            """,
            (push_provider, push_token),
        ).fetchone()
    if row is None:
        return None
    return _row_to_notification_device(row)


def list_notification_devices(*, enabled_only: bool = False) -> list[NotificationDevice]:
    where_sql = "WHERE enabled = 1" if enabled_only else ""
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT id, platform, push_provider, push_token, device_name,
                   app_version, enabled, important_enabled, last_seen_at,
                   created_at, updated_at
            FROM notification_devices
            {where_sql}
            ORDER BY last_seen_at DESC
            """,
        ).fetchall()
    return [_row_to_notification_device(row) for row in rows]


def get_notification_device(device_id: str) -> NotificationDevice | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, platform, push_provider, push_token, device_name,
                   app_version, enabled, important_enabled, last_seen_at,
                   created_at, updated_at
            FROM notification_devices
            WHERE id = ?
            """,
            (device_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_notification_device(row)


def create_push_record(payload: PushRecordCreate) -> PushRecord:
    now = _now()
    record = PushRecord(
        id=str(uuid4()),
        created_at=now,
        updated_at=now,
        **payload.model_dump(),
    )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO push_records (
                id, signal_event_id, device_id, provider, status,
                request_payload, response_payload, error_message,
                attempt_count, sent_at, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _push_record_values(record),
        )
    return record


def list_push_records(
    *,
    signal_event_id: str | None = None,
    device_id: str | None = None,
    code: str | None = None,
    status: str | None = None,
    limit: int = 50,
) -> list[PushRecord]:
    clauses: list[str] = []
    parameters: list[object] = []
    if signal_event_id:
        clauses.append("records.signal_event_id = ?")
        parameters.append(signal_event_id)
    if device_id:
        clauses.append("records.device_id = ?")
        parameters.append(device_id)
    if code:
        clauses.append("events.code = ?")
        parameters.append(code.strip().upper())
    if status:
        clauses.append("records.status = ?")
        parameters.append(status.strip())
    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    safe_limit = max(1, min(limit, 200))
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT records.id, records.signal_event_id, records.device_id,
                   records.provider, records.status, records.request_payload,
                   records.response_payload, records.error_message,
                   records.attempt_count, records.sent_at, records.created_at,
                   records.updated_at
            FROM push_records records
            LEFT JOIN signal_events events
              ON events.id = records.signal_event_id
            {where_sql}
            ORDER BY records.created_at DESC
            LIMIT ?
            """,
            (*parameters, safe_limit),
        ).fetchall()
    return [_row_to_push_record(row) for row in rows]


def get_push_record(record_id: str) -> PushRecord | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, signal_event_id, device_id, provider, status,
                   request_payload, response_payload, error_message,
                   attempt_count, sent_at, created_at, updated_at
            FROM push_records
            WHERE id = ?
            """,
            (record_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_push_record(row)


def delete_push_record(record_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute(
            """
            DELETE FROM push_records
            WHERE id = ?
            """,
            (record_id,),
        )
        return bool(cursor.rowcount)


def get_push_record_by_signal_event_and_device(
    *,
    signal_event_id: str,
    device_id: str,
) -> PushRecord | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, signal_event_id, device_id, provider, status,
                   request_payload, response_payload, error_message,
                   attempt_count, sent_at, created_at, updated_at
            FROM push_records
            WHERE signal_event_id = ? AND device_id = ?
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (signal_event_id, device_id),
        ).fetchone()
    if row is None:
        return None
    return _row_to_push_record(row)
