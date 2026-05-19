from datetime import datetime, timezone
from typing import Any

from ..repositories.notifications import create_push_record
from ..schemas import NotificationDevice, PushRecord, PushRecordCreate, SignalEvent
from .push_providers.base import PushProviderConfigurationError, PushProviderSendError
from .push_providers.fcm import send_fcm_message
from .push_providers.huawei import send_huawei_message


UNCONFIGURED_PROVIDER_MESSAGE = "真实推送通道尚未配置"
LOCAL_ONLY_PROVIDERS = {"local", "unknown"}


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
