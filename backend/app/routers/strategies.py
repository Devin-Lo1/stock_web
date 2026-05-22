from fastapi import APIRouter, Query, status

from ..errors import api_error, not_found_error
from ..repositories.strategy_monitors import (
    create_strategy_monitor,
    delete_strategy_monitor,
    get_strategy_monitor,
    list_strategy_monitors,
    update_strategy_monitor,
)
from ..repositories.strategy_monitor_scan_logs import (
    delete_strategy_monitor_scan_log,
    list_strategy_monitor_scan_logs,
)
from ..repositories.strategies import list_strategy_definitions
from ..schemas import (
    StrategyDefinition,
    SignalScanResult,
    StrategyMonitor,
    StrategyMonitorCreate,
    StrategyMonitorScanLog,
    StrategyMonitorSchedulerStatus,
    StrategyMonitorSchedulerUpdate,
    StrategyMonitorUpdate,
)
from ..services.strategy_monitor_scheduler import get_strategy_monitor_scheduler
from ..services.strategy_monitor_scanner import scan_strategy_monitors
from ..strategies import get_strategy

router = APIRouter(prefix="/api/v1/strategies", tags=["strategies"])


@router.get("", response_model=list[StrategyDefinition])
def api_list_strategies() -> list[StrategyDefinition]:
    return list_strategy_definitions()


@router.get("/monitors", response_model=list[StrategyMonitor])
def api_list_strategy_monitors(
    position_id: str | None = Query(default=None),
    code: str | None = Query(default=None),
    strategy_code: str | None = Query(default=None),
    enabled_only: bool = Query(default=False),
    limit: int = Query(default=100, ge=1, le=500),
) -> list[StrategyMonitor]:
    return list_strategy_monitors(
        position_id=position_id,
        code=code,
        strategy_code=strategy_code,
        enabled_only=enabled_only,
        limit=limit,
    )


@router.post(
    "/monitors",
    response_model=StrategyMonitor,
    status_code=status.HTTP_201_CREATED,
)
def api_create_strategy_monitor(
    payload: StrategyMonitorCreate,
) -> StrategyMonitor:
    _ensure_supported_strategy(payload.strategy_code)
    return create_strategy_monitor(payload)


@router.post("/monitors/scan", response_model=SignalScanResult)
def api_scan_strategy_monitors(
    refresh: bool = Query(default=False),
    force: bool = Query(default=False),
) -> SignalScanResult:
    return scan_strategy_monitors(refresh=refresh, force=force)


@router.get("/monitors/scheduler/status", response_model=StrategyMonitorSchedulerStatus)
def api_strategy_monitor_scheduler_status() -> StrategyMonitorSchedulerStatus:
    return get_strategy_monitor_scheduler().status()


@router.post("/monitors/scheduler/start", response_model=StrategyMonitorSchedulerStatus)
async def api_start_strategy_monitor_scheduler(
    payload: StrategyMonitorSchedulerUpdate | None = None,
) -> StrategyMonitorSchedulerStatus:
    return await get_strategy_monitor_scheduler().start(payload)


@router.post("/monitors/scheduler/stop", response_model=StrategyMonitorSchedulerStatus)
async def api_stop_strategy_monitor_scheduler() -> StrategyMonitorSchedulerStatus:
    return await get_strategy_monitor_scheduler().stop()


@router.post("/monitors/scheduler/run-once", response_model=StrategyMonitorSchedulerStatus)
async def api_run_strategy_monitor_scheduler_once(
    payload: StrategyMonitorSchedulerUpdate | None = None,
    force: bool = Query(default=True),
) -> StrategyMonitorSchedulerStatus:
    scheduler = get_strategy_monitor_scheduler()
    if payload is not None:
        scheduler.configure(payload)
    await scheduler.run_once(force=force)
    return scheduler.status()


@router.get("/monitors/scan-logs", response_model=list[StrategyMonitorScanLog])
def api_list_strategy_monitor_scan_logs(
    monitor_id: str | None = Query(default=None),
    code: str | None = Query(default=None),
    status: str | None = Query(default=None),
    limit: int = Query(default=10, ge=1, le=10),
) -> list[StrategyMonitorScanLog]:
    return list_strategy_monitor_scan_logs(
        monitor_id=monitor_id,
        code=code,
        status=status,
        limit=limit,
    )


@router.delete(
    "/monitors/scan-logs/{log_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def api_delete_strategy_monitor_scan_log(log_id: str) -> None:
    if not delete_strategy_monitor_scan_log(log_id):
        raise not_found_error("strategy monitor scan log not found", log_id=log_id)


@router.get("/monitors/{monitor_id}", response_model=StrategyMonitor)
def api_get_strategy_monitor(monitor_id: str) -> StrategyMonitor:
    monitor = get_strategy_monitor(monitor_id)
    if monitor is None:
        raise not_found_error("strategy monitor not found", monitor_id=monitor_id)
    return monitor


@router.put("/monitors/{monitor_id}", response_model=StrategyMonitor)
def api_update_strategy_monitor(
    monitor_id: str,
    payload: StrategyMonitorUpdate,
) -> StrategyMonitor:
    if payload.strategy_code is not None:
        _ensure_supported_strategy(payload.strategy_code)
    monitor = update_strategy_monitor(monitor_id, payload)
    if monitor is None:
        raise not_found_error("strategy monitor not found", monitor_id=monitor_id)
    return monitor


@router.delete(
    "/monitors/{monitor_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def api_delete_strategy_monitor(monitor_id: str) -> None:
    if not delete_strategy_monitor(monitor_id):
        raise not_found_error("strategy monitor not found", monitor_id=monitor_id)


def _ensure_supported_strategy(strategy_code: str) -> None:
    if get_strategy(strategy_code.strip()) is None:
        raise api_error(
            status.HTTP_400_BAD_REQUEST,
            "STRATEGY_NOT_SUPPORTED",
            "strategy is not supported by backend registry",
            {"strategy_code": strategy_code},
        )
