from fastapi import APIRouter

from ..mock_store import list_signals
from ..schemas import Signal

router = APIRouter(prefix="/api/v1/signals", tags=["signals"])


@router.get("", response_model=list[Signal])
def api_list_signals() -> list[Signal]:
    return list_signals()
