from datetime import datetime

from pydantic import BaseModel, Field

from .common import Market


class PositionBase(BaseModel):
    market: Market
    code: str = Field(min_length=1)
    name: str = Field(min_length=1)
    quantity: float = Field(ge=0)
    cost_price: float = Field(ge=0)
    currency: str


class PositionCreate(PositionBase):
    pass


class PositionUpdate(BaseModel):
    market: Market | None = None
    code: str | None = Field(default=None, min_length=1)
    name: str | None = Field(default=None, min_length=1)
    quantity: float | None = Field(default=None, ge=0)
    cost_price: float | None = Field(default=None, ge=0)
    currency: str | None = None


class Position(PositionBase):
    id: str
    created_at: datetime
    updated_at: datetime
