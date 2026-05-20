from fastapi import APIRouter, Query, status

from ..mock_store import list_signals
from ..repositories.notifications import (
    list_signal_events,
    mark_signal_event_ignored,
    mark_signal_event_read,
)
from ..repositories.signal_scan_configs import (
    create_signal_scan_config,
    list_signal_scan_configs,
    replace_signal_scan_configs,
    update_signal_scan_config,
)
from ..errors import not_found_error
from ..schemas import (
    Signal,
    SignalEvent,
    SignalScanConfig,
    SignalScanConfigCreate,
    SignalScanConfigUpdate,
    SignalScanResult,
)
from ..services.signal_scan_config import default_signal_scan_configs
from ..services.signal_scanner import scan_strategy_signals

router = APIRouter(prefix="/api/v1/signals", tags=["signals"])


@router.get("", response_model=list[Signal])
def api_list_signals() -> list[Signal]:
    return list_signals()


@router.get("/events", response_model=list[SignalEvent])
def api_list_signal_events(
    code: str | None = Query(default=None),
    read_status: str | None = Query(default=None),
    level: str | None = Query(default=None),
    source_category: str | None = Query(default=None),
    strategy_code: str | None = Query(default=None),
    push_candidate: bool | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[SignalEvent]:
    return list_signal_events(
        code=code,
        read_status=read_status,
        level=level,
        source_category=source_category,
        strategy_code=strategy_code,
        push_candidate=push_candidate,
        limit=limit,
    )


@router.put("/events/{event_id}/read", response_model=SignalEvent)
def api_mark_signal_event_read(event_id: str) -> SignalEvent:
    event = mark_signal_event_read(event_id)
    if event is None:
        raise not_found_error("信号事件不存在", event_id=event_id)
    return event


@router.put("/events/{event_id}/ignore", response_model=SignalEvent)
def api_mark_signal_event_ignored(event_id: str) -> SignalEvent:
    event = mark_signal_event_ignored(event_id)
    if event is None:
        raise not_found_error("信号事件不存在", event_id=event_id)
    return event


@router.get("/configs", response_model=list[SignalScanConfig])
def api_list_signal_scan_configs(
    enabled_only: bool = Query(default=False),
) -> list[SignalScanConfig]:
    return list_signal_scan_configs(enabled_only=enabled_only)


@router.post(
    "/configs",
    response_model=SignalScanConfig,
    status_code=status.HTTP_201_CREATED,
)
def api_create_signal_scan_config(
    payload: SignalScanConfigCreate,
) -> SignalScanConfig:
    return create_signal_scan_config(payload)


@router.put("/configs/{config_id}", response_model=SignalScanConfig)
def api_update_signal_scan_config(
    config_id: str,
    payload: SignalScanConfigUpdate,
) -> SignalScanConfig:
    config = update_signal_scan_config(config_id, payload)
    if config is None:
        raise not_found_error("扫描配置不存在", config_id=config_id)
    return config


@router.post("/configs/reset-defaults", response_model=list[SignalScanConfig])
def api_reset_signal_scan_configs() -> list[SignalScanConfig]:
    return replace_signal_scan_configs(default_signal_scan_configs())


@router.post("/scan", response_model=SignalScanResult)
def api_scan_signal_events(
    refresh: bool = Query(default=False),
) -> SignalScanResult:
    return scan_strategy_signals(refresh=refresh)
