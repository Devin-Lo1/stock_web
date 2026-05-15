from fastapi import APIRouter, Query

from ..errors import futu_dependency_error, futu_no_data_error, futu_unavailable_error
from ..mock_store import get_candles
from ..repositories.market_data import list_candles, upsert_candles
from ..repositories.positions import list_positions
from ..schemas import Candle
from ..services.futu_client import (
    FutuDependencyError,
    FutuOpenDError,
    request_history_klines,
)

router = APIRouter(prefix="/api/v1/klines", tags=["quotes"])


@router.get("/{stock_code}", response_model=list[Candle])
def api_get_klines(
    stock_code: str,
    period: str = Query(default="day"),
    limit: int = Query(default=120, ge=1, le=1000),
    include_mock: bool = Query(default=True),
) -> list[Candle]:
    cached_candles = list_candles(stock_code, period, limit)
    if cached_candles:
        return cached_candles
    if not include_mock:
        return []
    return get_candles(stock_code, period, min(limit, 240))


@router.post("/refresh", response_model=list[Candle])
def api_refresh_klines(
    codes: str = Query(default=""),
    period: str = Query(default="day"),
    max_count: int = Query(default=240, ge=1, le=1000),
    start: str | None = Query(default=None),
    end: str | None = Query(default=None),
) -> list[Candle]:
    requested_codes = [code.strip().upper() for code in codes.split(",") if code.strip()]
    if not requested_codes:
        requested_codes = [position.code for position in list_positions()]

    refreshed_candles: list[Candle] = []
    failed_codes: dict[str, str] = {}
    for code in requested_codes:
        try:
            candles = request_history_klines(
                code=code,
                period=period,
                max_count=max_count,
                start=start,
                end=end,
            )
        except FutuDependencyError as error:
            raise futu_dependency_error(str(error)) from error
        except FutuOpenDError as error:
            failed_codes[code] = str(error)
            continue
        refreshed_candles.extend(upsert_candles(candles))
    if not refreshed_candles:
        if failed_codes:
            raise futu_unavailable_error(str(failed_codes))
        raise futu_no_data_error(
            "富途未返回 K 线数据",
            codes=requested_codes,
            period=period,
            max_count=max_count,
        )
    return refreshed_candles
