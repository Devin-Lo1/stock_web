import json
import os
import time
from dataclasses import dataclass
from typing import Any

import httpx

from .base import PushProviderConfigurationError, PushProviderSendError


class HuaweiConfigurationError(PushProviderConfigurationError):
    pass


class HuaweiSendError(PushProviderSendError):
    pass


DEFAULT_OAUTH_URL = "https://oauth-login.cloud.huawei.com/oauth2/v3/token"
DEFAULT_API_BASE_URL = "https://push-api.cloud.huawei.com"
SUCCESS_CODE = "80000000"


@dataclass
class _HuaweiAccessToken:
    value: str
    expires_at: float


_cached_token: _HuaweiAccessToken | None = None


def send_huawei_message(
    *,
    token: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    app_id = _required_env("HUAWEI_PUSH_APP_ID")
    access_token = _get_access_token()
    payload = {
        "validate_only": _env_bool("HUAWEI_PUSH_VALIDATE_ONLY"),
        "message": {
            "token": [token],
            "notification": {"title": title, "body": body},
            "android": {
                "notification": {
                    "title": title,
                    "body": body,
                },
            },
            "data": json.dumps(_string_data(data or {}), ensure_ascii=False),
        },
    }
    url = f"{_api_base_url()}/v1/{app_id}/messages:send"

    try:
        response = httpx.post(
            url,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json; charset=UTF-8",
            },
            json=payload,
            timeout=10,
        )
    except httpx.RequestError as error:  # pragma: no cover - network dependent.
        raise HuaweiSendError(f"Huawei Push request failed: {error}") from error

    response_payload = _response_json(response)
    if response.status_code >= 400:
        raise HuaweiSendError(_format_error(response, response_payload))

    code = str(response_payload.get("code", ""))
    if code and code != SUCCESS_CODE:
        raise HuaweiSendError(_format_error(response, response_payload))

    return {
        "code": code or SUCCESS_CODE,
        "msg": str(response_payload.get("msg", "")),
        "request_id": response.headers.get("X-Request-ID", ""),
    }


def _get_access_token() -> str:
    global _cached_token
    now = time.time()
    if _cached_token is not None and _cached_token.expires_at - 60 > now:
        return _cached_token.value

    client_id = _required_env("HUAWEI_PUSH_CLIENT_ID")
    client_secret = _required_env("HUAWEI_PUSH_CLIENT_SECRET")
    try:
        response = httpx.post(
            os.getenv("HUAWEI_PUSH_OAUTH_URL", DEFAULT_OAUTH_URL).strip()
            or DEFAULT_OAUTH_URL,
            data={
                "grant_type": "client_credentials",
                "client_id": client_id,
                "client_secret": client_secret,
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10,
        )
    except httpx.RequestError as error:  # pragma: no cover - network dependent.
        raise HuaweiSendError(f"Huawei Push OAuth request failed: {error}") from error

    payload = _response_json(response)
    if response.status_code >= 400:
        raise HuaweiConfigurationError(_format_error(response, payload))

    access_token = str(payload.get("access_token", "")).strip()
    if not access_token:
        raise HuaweiConfigurationError("Huawei Push OAuth did not return access_token")

    expires_in = _int_value(payload.get("expires_in"), default=3600)
    _cached_token = _HuaweiAccessToken(
        value=access_token,
        expires_at=now + max(expires_in, 60),
    )
    return access_token


def _required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise HuaweiConfigurationError(f"{name} is required for Huawei Push")
    return value


def _api_base_url() -> str:
    return (
        os.getenv("HUAWEI_PUSH_API_BASE_URL", DEFAULT_API_BASE_URL).strip()
        or DEFAULT_API_BASE_URL
    ).rstrip("/")


def _response_json(response: httpx.Response) -> dict[str, Any]:
    try:
        payload = response.json()
    except ValueError:
        return {"raw": response.text[:500]}
    return payload if isinstance(payload, dict) else {"raw": payload}


def _format_error(response: httpx.Response, payload: dict[str, Any]) -> str:
    code = payload.get("code") or payload.get("error") or response.status_code
    message = payload.get("msg") or payload.get("error_description") or payload
    return f"Huawei Push failed ({code}): {message}"


def _string_data(data: dict[str, Any]) -> dict[str, str]:
    return {str(key): "" if value is None else str(value) for key, value in data.items()}


def _env_bool(name: str) -> bool:
    return os.getenv(name, "").strip().lower() in {"1", "true", "yes", "on"}


def _int_value(value: Any, *, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default
