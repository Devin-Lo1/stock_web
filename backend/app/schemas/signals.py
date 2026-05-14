from datetime import datetime

from pydantic import BaseModel


class Signal(BaseModel):
    id: str
    code: str
    signal_type: str
    level: str
    message: str
    trigger_value: float
    threshold_value: float
    created_at: datetime
