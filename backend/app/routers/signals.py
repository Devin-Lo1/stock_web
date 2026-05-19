from fastapi import APIRouter, Query

from ..mock_store import list_signals
from ..repositories.notifications import list_signal_events
from ..schemas import Signal, SignalEvent, SignalScanResult
from ..services.signal_scanner import scan_strategy_signals

router = APIRouter(prefix="/api/v1/signals", tags=["signals"])


@router.get("", response_model=list[Signal])
def api_list_signals() -> list[Signal]:
    return list_signals()


@router.get("/events", response_model=list[SignalEvent])
def api_list_signal_events(
    code: str | None = Query(default=None),
    read_status: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[SignalEvent]:
    return list_signal_events(code=code, read_status=read_status, limit=limit)


@router.post("/scan", response_model=SignalScanResult)
def api_scan_signal_events(
    refresh: bool = Query(default=False),
) -> SignalScanResult:
    return scan_strategy_signals(refresh=refresh)
