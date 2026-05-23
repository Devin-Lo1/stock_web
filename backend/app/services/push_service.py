from datetime import datetime, timezone
import os
from typing import Any

from ..repositories.notifications import (
    create_push_record,
    get_notification_device,
    get_push_record,
    get_push_record_by_signal_event_and_device,
    get_signal_event,
    list_notification_devices,
)
from ..schemas import (
    NotificationDevice,
    PushDispatchResult,
    PushProviderStatus,
    PushRecord,
    PushRecordCreate,
    SignalEvent,
)
from .push_providers.base import PushProviderConfigurationError, PushProviderSendError
from .push_providers.fcm import send_fcm_message
from .push_providers.huawei import send_huawei_message


UNCONFIGURED_PROVIDER_MESSAGE = "真实推送通道尚未配置"
LOCAL_ONLY_PROVIDERS = {"local", "unknown"}
IMPORTANT_PUSH_LEVELS = {"important", "warning"}
HUAWEI_REQUIRED_ENV = [
    "HUAWEI_PUSH_APP_ID",
    "HUAWEI_PUSH_CLIENT_ID",
    "HUAWEI_PUSH_CLIENT_SECRET",
]
FCM_ALTERNATIVE_ENV = [
    "FCM_SERVICE_ACCOUNT_JSON",
    "FCM_SERVICE_ACCOUNT_PATH",
    "GOOGLE_APPLICATION_CREDENTIALS",
]


def list_push_provider_statuses() -> list[PushProviderStatus]:
    huawei_missing = _missing_env(HUAWEI_REQUIRED_ENV)
    fcm_configured = any(_env_present(name) for name in FCM_ALTERNATIVE_ENV)
    return [
        PushProviderStatus(
            provider="huawei",
            configured=not huawei_missing,
            validate_only=_env_bool("HUAWEI_PUSH_VALIDATE_ONLY"),
            missing_env=huawei_missing,
            message=(
                "Huawei Push Kit 已具备服务端发送配置。"
                if not huawei_missing
                else "Huawei Push Kit 尚缺少服务端环境变量。"
            ),
        ),
        PushProviderStatus(
            provider="fcm",
            configured=fcm_configured,
            missing_env=[] if fcm_configured else [" / ".join(FCM_ALTERNATIVE_ENV)],
            message=(
                "FCM 已具备服务端发送配置。"
                if fcm_configured
                else "FCM 尚未配置服务账号或 Google 默认凭据。"
            ),
        ),
    ]


def dispatch_signal_event_to_devices(event: SignalEvent) -> PushDispatchResult:
    if not _is_push_candidate(event):
        return PushDispatchResult(
            signal_event_id=event.id,
            reason="push_candidate_disabled",
        )

    devices = list_notification_devices()
    records: list[PushRecord] = []
    created_count = 0
    for device in devices:
        existing = get_push_record_by_signal_event_and_device(
            signal_event_id=event.id,
            device_id=device.id,
        )
        if existing is not None:
            records.append(existing)
            continue

        record = _dispatch_signal_event_to_device(device=device, event=event)
        records.append(record)
        created_count += 1

    return _dispatch_result(
        event=event,
        records=records,
        created_count=created_count,
        reason="" if devices else "no_registered_devices",
    )


def retry_push_record(record_id: str) -> PushRecord | None:
    record = get_push_record(record_id)
    if record is None or record.signal_event_id is None:
        return None
    event = get_signal_event(record.signal_event_id)
    device = get_notification_device(record.device_id)
    if event is None or device is None:
        return None
    if event.source == "test" or event.signal_type == "notification_test":
        return dispatch_notification_to_device(
            device=device,
            event=event,
            title=event.title,
            message=event.message,
            data={"source": "notification_test"},
        )
    return _dispatch_signal_event_to_device(device=device, event=event)


def dispatch_notification_to_device(
    *,
    device: NotificationDevice,
    event: SignalEvent,
    title: str,
    message: str,
    data: dict[str, Any] | None = None,
) -> PushRecord:
    request_payload = {
        "title": title,
        "message": message,
        "provider": device.push_provider,
        "signal_event_id": event.id,
    }

    if not device.enabled:
        return create_push_record(
            PushRecordCreate(
                signal_event_id=event.id,
                device_id=device.id,
                provider=device.push_provider,
                status="skipped",
                request_payload=request_payload,
                error_message="device_disabled",
            ),
        )

    if device.push_provider in LOCAL_ONLY_PROVIDERS:
        return create_push_record(
            PushRecordCreate(
                signal_event_id=event.id,
                device_id=device.id,
                provider=device.push_provider,
                status="skipped",
                request_payload=request_payload,
                error_message=UNCONFIGURED_PROVIDER_MESSAGE,
            ),
        )

    push_data = {
        "signal_event_id": event.id,
        "code": event.code,
        "signal_type": event.signal_type,
        **(data or {}),
    }

    try:
        response_payload = _send_with_provider(
            provider=device.push_provider,
            token=device.push_token,
            title=title,
            message=message,
            data=push_data,
        )
    except PushProviderConfigurationError as error:
        return create_push_record(
            PushRecordCreate(
                signal_event_id=event.id,
                device_id=device.id,
                provider=device.push_provider,
                status="skipped",
                request_payload=request_payload,
                error_message=str(error),
            ),
        )
    except PushProviderSendError as error:
        return create_push_record(
            PushRecordCreate(
                signal_event_id=event.id,
                device_id=device.id,
                provider=device.push_provider,
                status="failed",
                request_payload=request_payload,
                error_message=str(error),
                attempt_count=1,
            ),
        )

    return create_push_record(
        PushRecordCreate(
            signal_event_id=event.id,
            device_id=device.id,
            provider=device.push_provider,
            status="sent",
            request_payload=request_payload,
            response_payload=response_payload,
            attempt_count=1,
            sent_at=datetime.now(timezone.utc),
        ),
    )


def _dispatch_signal_event_to_device(
    *,
    device: NotificationDevice,
    event: SignalEvent,
) -> PushRecord:
    if not device.enabled:
        return dispatch_notification_to_device(
            device=device,
            event=event,
            title=event.title,
            message=event.message,
            data=_signal_push_data(event),
        )
    if _important_push_disabled(device=device, event=event):
        return create_push_record(
            PushRecordCreate(
                signal_event_id=event.id,
                device_id=device.id,
                provider=device.push_provider,
                status="skipped",
                request_payload=_signal_request_payload(device=device, event=event),
                error_message="important_notifications_disabled",
            ),
        )

    return dispatch_notification_to_device(
        device=device,
        event=event,
        title=event.title,
        message=event.message,
        data=_signal_push_data(event),
    )


def _is_push_candidate(event: SignalEvent) -> bool:
    return bool(event.payload.get("push_candidate", False))


def _important_push_disabled(
    *,
    device: NotificationDevice,
    event: SignalEvent,
) -> bool:
    return event.level in IMPORTANT_PUSH_LEVELS and not device.important_enabled


def _signal_request_payload(
    *,
    device: NotificationDevice,
    event: SignalEvent,
) -> dict[str, Any]:
    return {
        "title": event.title,
        "message": event.message,
        "provider": device.push_provider,
        "signal_event_id": event.id,
    }


def _signal_push_data(event: SignalEvent) -> dict[str, Any]:
    payload = event.payload
    data: dict[str, Any] = {
        "source": event.source,
    }
    for key in ("source_category", "strategy_code", "monitor_id", "side", "period"):
        value = payload.get(key)
        if value is not None:
            data[key] = str(value)
    return data


def _dispatch_result(
    *,
    event: SignalEvent,
    records: list[PushRecord],
    created_count: int,
    reason: str,
) -> PushDispatchResult:
    return PushDispatchResult(
        signal_event_id=event.id,
        attempted_count=len(records),
        created_count=created_count,
        sent_count=sum(1 for record in records if record.status == "sent"),
        failed_count=sum(1 for record in records if record.status == "failed"),
        skipped_count=sum(1 for record in records if record.status == "skipped"),
        reason=reason,
        records=records,
    )


def _send_with_provider(
    *,
    provider: str,
    token: str,
    title: str,
    message: str,
    data: dict[str, Any],
) -> dict[str, Any]:
    if provider == "fcm":
        return send_fcm_message(token=token, title=title, body=message, data=data)
    if provider == "huawei":
        return send_huawei_message(token=token, title=title, body=message, data=data)
    raise PushProviderConfigurationError(f"{UNCONFIGURED_PROVIDER_MESSAGE}: {provider}")


def _missing_env(names: list[str]) -> list[str]:
    return [name for name in names if not _env_present(name)]


def _env_present(name: str) -> bool:
    return bool(os.getenv(name, "").strip())


def _env_bool(name: str) -> bool:
    return os.getenv(name, "").strip().lower() in {"1", "true", "yes", "on"}
