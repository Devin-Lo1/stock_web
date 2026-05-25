from datetime import datetime, timezone

from fastapi import APIRouter, Query, status

from ..errors import api_error, not_found_error
from ..repositories.funds import (
    FundTradeError,
    create_fund_position,
    create_fund_trade_for_position,
    delete_fund_position,
    get_fund_position,
    list_fund_navs,
    list_fund_positions,
    list_fund_trades,
    update_fund_position,
    upsert_fund_navs,
)
from ..schemas import (
    FundBenchmarkPoint,
    FundNavPoint,
    FundAlertScanResult,
    FundAlertSchedulerStatus,
    FundAlertSchedulerUpdate,
    FundPosition,
    FundPositionCreate,
    FundPositionSummary,
    FundPositionUpdate,
    FundQuote,
    FundSearchResult,
    FundTrade,
    FundTradeCreate,
)
from ..services.fund_provider import EastmoneyFundProvider, FundProviderError
from ..services.funds import list_fund_position_summaries, refresh_fund_navs
from ..services.fund_alert_scheduler import get_fund_alert_scheduler

router = APIRouter(prefix="/api/v1/funds", tags=["funds"])


@router.get("/alerts/scheduler/status", response_model=FundAlertSchedulerStatus)
def api_fund_alert_scheduler_status() -> FundAlertSchedulerStatus:
    return get_fund_alert_scheduler().status()


@router.put("/alerts/scheduler/config", response_model=FundAlertSchedulerStatus)
def api_update_fund_alert_scheduler(
    payload: FundAlertSchedulerUpdate,
) -> FundAlertSchedulerStatus:
    return get_fund_alert_scheduler().configure(payload)


@router.post("/alerts/scheduler/run-once", response_model=FundAlertSchedulerStatus)
async def api_run_fund_alert_scheduler_once(
    refresh: bool = Query(default=True),
) -> FundAlertSchedulerStatus:
    await get_fund_alert_scheduler().run_once(refresh=refresh)
    return get_fund_alert_scheduler().status()


@router.post("/alerts/scan", response_model=FundAlertScanResult)
async def api_scan_fund_alerts(
    refresh: bool = Query(default=True),
) -> FundAlertScanResult:
    result = await get_fund_alert_scheduler().run_once(refresh=refresh)
    if result is None:
        status = get_fund_alert_scheduler().status()
        return FundAlertScanResult(
            scanned_count=0,
            created_count=0,
            skipped_count=0,
            events=[],
            errors=[{"message": "fund alert scan is already running"}],
            scanned_at=status.last_scan_at
            or status.last_started_at
            or datetime.now(timezone.utc),
            scan_key=status.last_scan_key,
        )
    return result


@router.get("/search", response_model=list[FundSearchResult])
def api_search_funds(
    query: str = Query(min_length=1),
    limit: int = Query(default=20, ge=1, le=50),
) -> list[FundSearchResult]:
    try:
        return EastmoneyFundProvider().search(query, limit=limit)
    except Exception as error:
        raise api_error(
            status.HTTP_502_BAD_GATEWAY,
            "FUND_PROVIDER_UNAVAILABLE",
            "基金数据源暂不可用",
            {"reason": str(error)},
        ) from error


@router.get("/benchmarks/hs300/navs", response_model=list[FundBenchmarkPoint])
def api_list_hs300_benchmark_navs(
    limit: int = Query(default=370, ge=1, le=1000),
) -> list[FundBenchmarkPoint]:
    try:
        return EastmoneyFundProvider().benchmark_history("hs300", limit=limit)
    except Exception as error:
        raise api_error(
            status.HTTP_502_BAD_GATEWAY,
            "FUND_BENCHMARK_UNAVAILABLE",
            "基金基准数据暂不可用",
            {"benchmark": "hs300", "reason": str(error)},
        ) from error


@router.get("/{fund_code}/quote", response_model=FundQuote)
def api_get_fund_quote(fund_code: str) -> FundQuote:
    try:
        quote = EastmoneyFundProvider().quote(fund_code)
        points = EastmoneyFundProvider().nav_history(fund_code, limit=3)
        upsert_fund_navs(points)
        return quote
    except Exception as error:
        raise api_error(
            status.HTTP_502_BAD_GATEWAY,
            "FUND_PROVIDER_UNAVAILABLE",
            "基金行情暂不可用",
            {"fund_code": fund_code, "reason": str(error)},
        ) from error


@router.get("/{fund_code}/navs", response_model=list[FundNavPoint])
def api_list_fund_navs(
    fund_code: str,
    limit: int = Query(default=90, ge=1, le=1000),
    refresh: bool = Query(default=True),
) -> list[FundNavPoint]:
    if refresh:
        try:
            return refresh_fund_navs(fund_code, limit=limit)
        except (FundProviderError, Exception):
            pass
    return list_fund_navs(fund_code, limit=limit)


@router.get("/positions", response_model=list[FundPosition])
def api_list_fund_positions() -> list[FundPosition]:
    return list_fund_positions()


@router.get("/positions/summary", response_model=list[FundPositionSummary])
def api_list_fund_position_summaries(
    refresh: bool = Query(default=True),
) -> list[FundPositionSummary]:
    return list_fund_position_summaries(refresh=refresh)


@router.post(
    "/positions",
    response_model=FundPosition,
    status_code=status.HTTP_201_CREATED,
)
def api_create_fund_position(payload: FundPositionCreate) -> FundPosition:
    return create_fund_position(payload)


@router.put("/positions/{position_id}", response_model=FundPosition)
def api_update_fund_position(
    position_id: str,
    payload: FundPositionUpdate,
) -> FundPosition:
    position = get_fund_position(position_id)
    if position is None:
        raise not_found_error("基金持仓不存在", position_id=position_id)
    return update_fund_position(position, payload)


@router.delete("/positions/{position_id}", status_code=status.HTTP_204_NO_CONTENT)
def api_delete_fund_position(position_id: str) -> None:
    if not delete_fund_position(position_id):
        raise not_found_error("基金持仓不存在", position_id=position_id)


@router.get("/positions/{position_id}/trades", response_model=list[FundTrade])
def api_list_fund_position_trades(
    position_id: str,
    limit: int = Query(default=100, ge=1, le=500),
) -> list[FundTrade]:
    return list_fund_trades(position_id=position_id, limit=limit)


@router.post(
    "/positions/{position_id}/trades",
    response_model=FundTrade,
    status_code=status.HTTP_201_CREATED,
)
def api_create_fund_trade(
    position_id: str,
    payload: FundTradeCreate,
) -> FundTrade:
    position = get_fund_position(position_id)
    if position is None:
        raise not_found_error("基金持仓不存在", position_id=position_id)
    try:
        return create_fund_trade_for_position(position, payload)
    except FundTradeError as error:
        raise api_error(
            status.HTTP_400_BAD_REQUEST,
            "FUND_TRADE_INVALID",
            str(error),
            {"position_id": position_id},
        ) from error
