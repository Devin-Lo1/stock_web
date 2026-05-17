from fastapi import APIRouter, Query, status

from ..errors import not_found_error
from ..repositories.notifications import (
    create_push_record,
    create_signal_event,
    get_notification_device_by_token,
    list_notification_devices,
    list_push_records,
    list_signal_events,
    mark_signal_event_read,
    upsert_notification_device,
)
from ..schemas import (
    NotificationDevice,
    NotificationDeviceUpsert,
    NotificationRegistrationResult,
    NotificationTestRequest,
    PushRecord,
    PushRecordCreate,
    SignalEvent,
    SignalEventCreate,
)

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


@router.post(
    "/devices",
    response_model=NotificationRegistrationResult,
    status_code=status.HTTP_201_CREATED,
)
def api_upsert_notification_device(
    payload: NotificationDeviceUpsert,
) -> NotificationRegistrationResult:
    device = upsert_notification_device(payload)
    return NotificationRegistrationResult(
        device=device,
        latest_signal_count=len(list_signal_events(limit=20)),
    )


@router.get("/devices", response_model=list[NotificationDevice])
def api_list_notification_devices(
    enabled_only: bool = Query(default=False),
) -> list[NotificationDevice]:
    return list_notification_devices(enabled_only=enabled_only)


@router.get("/signals", response_model=list[SignalEvent])
def api_list_signal_events(
    code: str | None = Query(default=None),
    read_status: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[SignalEvent]:
    return list_signal_events(code=code, read_status=read_status, limit=limit)


@router.post(
    "/signals",
    response_model=SignalEvent,
    status_code=status.HTTP_201_CREATED,
)
def api_create_signal_event(payload: SignalEventCreate) -> SignalEvent:
    return create_signal_event(payload)


@router.put("/signals/{event_id}/read", response_model=SignalEvent)
def api_mark_signal_event_read(event_id: str) -> SignalEvent:
    event = mark_signal_event_read(event_id)
    if event is None:
        raise not_found_error("信号事件不存在", event_id=event_id)
    return event


@router.get("/push-records", response_model=list[PushRecord])
def api_list_push_records(
    signal_event_id: str | None = Query(default=None),
    device_id: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[PushRecord]:
    return list_push_records(
        signal_event_id=signal_event_id,
        device_id=device_id,
        limit=limit,
    )


@router.post(
    "/test",
    response_model=PushRecord,
    status_code=status.HTTP_201_CREATED,
)
def api_create_test_notification(payload: NotificationTestRequest) -> PushRecord:
    devices = list_notification_devices()
    device = next((item for item in devices if item.id == payload.device_id), None)
    if device is None:
        raise not_found_error("通知设备不存在", device_id=payload.device_id)

    event = create_signal_event(
        SignalEventCreate(
            source="test",
            code="TEST",
            signal_type="notification_test",
            level="info",
            title=payload.title,
            message=payload.message,
            dedupe_key=f"notification_test:{device.id}",
            payload={"device_id": device.id},
        ),
    )
    status_value = "queued" if device.push_provider == "fcm" else "skipped"
    error_message = "" if device.push_provider == "fcm" else "真实推送通道尚未配置"
    return create_push_record(
        PushRecordCreate(
            signal_event_id=event.id,
            device_id=device.id,
            provider=device.push_provider,
            status=status_value,
            request_payload={
                "title": payload.title,
                "message": payload.message,
                "push_token": device.push_token,
            },
            error_message=error_message,
        ),
    )
