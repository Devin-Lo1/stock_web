import json
import os
from typing import Any

from .base import PushProviderConfigurationError, PushProviderSendError


class FcmConfigurationError(PushProviderConfigurationError):
    pass


class FcmSendError(PushProviderSendError):
    pass


_initialized = False


def send_fcm_message(
    *,
    token: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, str]:
    messaging = _load_messaging()
    message = messaging.Message(
        token=token,
        notification=messaging.Notification(title=title, body=body),
        data=_string_data(data or {}),
    )
    try:
        message_id = messaging.send(message)
    except Exception as error:  # pragma: no cover - SDK error type varies.
        if "Project ID is required" in str(error):
            raise FcmConfigurationError(f"FCM is not configured: {error}") from error
        raise FcmSendError(str(error)) from error
    return {"message_id": message_id}


def _load_messaging():
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
    except ImportError as error:  # pragma: no cover - depends on local env.
        raise FcmConfigurationError(
            "firebase-admin is not installed. Install backend requirements first."
        ) from error

    global _initialized
    if not _initialized:
        try:
            if not firebase_admin._apps:
                credential = _load_credential(credentials)
                if credential is None:
                    firebase_admin.initialize_app()
                else:
                    firebase_admin.initialize_app(credential)
            _initialized = True
        except Exception as error:  # pragma: no cover - depends on local env.
            raise FcmConfigurationError(f"FCM is not configured: {error}") from error
    return messaging


def _load_credential(credentials_module):
    service_account_json = os.getenv("FCM_SERVICE_ACCOUNT_JSON", "").strip()
    service_account_path = os.getenv("FCM_SERVICE_ACCOUNT_PATH", "").strip()

    if service_account_json:
        try:
            return credentials_module.Certificate(json.loads(service_account_json))
        except json.JSONDecodeError as error:
            raise FcmConfigurationError("FCM_SERVICE_ACCOUNT_JSON is invalid JSON") from error

    if service_account_path:
        if not os.path.exists(service_account_path):
            raise FcmConfigurationError("FCM_SERVICE_ACCOUNT_PATH does not exist")
        return credentials_module.Certificate(service_account_path)

    return None


def _string_data(data: dict[str, Any]) -> dict[str, str]:
    return {str(key): "" if value is None else str(value) for key, value in data.items()}
