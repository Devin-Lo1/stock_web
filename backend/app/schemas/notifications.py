from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


NotificationPlatform = Literal["android", "ios", "web", "unknown"]
PushProvider = Literal[
    "fcm",
    "huawei",
    "xiaomi",
    "oppo",
    "vivo",
    "apns",
    "local",
    "unknown",
]
PushStatus = Literal["queued", "sent", "failed", "skipped"]
SignalReadStatus = Literal["unread", "read", "ignored"]


class SignalEventCreate(BaseModel):
    source: str = Field(default="backend", min_length=1)
    code: str = Field(min_length=1)
    signal_type: str = Field(min_length=1)
    level: str = Field(default="info", min_length=1)
    title: str = Field(min_length=1, max_length=120)
    message: str = Field(min_length=1, max_length=500)
    trigger_value: float | None = None
    threshold_value: float | None = None
    dedupe_key: str = Field(min_length=1, max_length=200)
    payload: dict[str, Any] = Field(default_factory=dict)
    triggered_at: datetime | None = None


class SignalEvent(SignalEventCreate):
    id: str
    read_status: SignalReadStatus = "unread"
    read_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class NotificationDeviceUpsert(BaseModel):
    platform: NotificationPlatform = "unknown"
    push_provider: PushProvider = "unknown"
    push_token: str = Field(min_length=1)
    device_name: str = Field(default="", max_length=120)
    app_version: str = Field(default="", max_length=80)
    enabled: bool = True
    important_enabled: bool = True


class NotificationDevice(NotificationDeviceUpsert):
    id: str
    last_seen_at: datetime
    created_at: datetime
    updated_at: datetime


class PushRecordCreate(BaseModel):
    signal_event_id: str | None = None
    device_id: str = Field(min_length=1)
    provider: PushProvider
    status: PushStatus = "queued"
    request_payload: dict[str, Any] = Field(default_factory=dict)
    response_payload: dict[str, Any] = Field(default_factory=dict)
    error_message: str = ""
    attempt_count: int = Field(default=0, ge=0)
    sent_at: datetime | None = None


class PushRecord(PushRecordCreate):
    id: str
    created_at: datetime
    updated_at: datetime


class NotificationTestRequest(BaseModel):
    device_id: str = Field(min_length=1)
    title: str = Field(default="测试提醒", min_length=1, max_length=120)
    message: str = Field(default="这是一条通知链路测试。", min_length=1, max_length=500)


class NotificationRegistrationResult(BaseModel):
    device: NotificationDevice
    latest_signal_count: int = 0
