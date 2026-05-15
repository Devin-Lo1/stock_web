from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class StrategyDefinitionCreate(BaseModel):
    code: str = Field(min_length=1)
    name: str = Field(min_length=1)
    description: str = ""
    default_parameters: dict[str, Any] = Field(default_factory=dict)


class StrategyDefinition(StrategyDefinitionCreate):
    id: str
    created_at: datetime
    updated_at: datetime
