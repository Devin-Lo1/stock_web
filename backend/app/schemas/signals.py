from datetime import datetime
from typing import Any

from pydantic import BaseModel

from .notifications import SignalEvent


class Signal(BaseModel):
    id: str
    code: str
    signal_type: str
    level: str
    message: str
    trigger_value: float
    threshold_value: float
    created_at: datetime


class SignalScanResult(BaseModel):
    scanned_count: int
    created_count: int
    skipped_count: int
    events: list[SignalEvent]
    errors: list[dict[str, Any]] = []
