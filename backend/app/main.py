from fastapi import FastAPI, HTTPException, Query, status

from .database import (
    init_database,
    list_candles,
    list_positions,
    upsert_candles,
    upsert_quote,
)
from .mock_store import (
    create_position,
    delete_position,
    get_candles,
    get_quotes,
    list_signals,
    update_position,
)
from .schemas import (
    Candle,
    Position,
    PositionCreate,
    PositionUpdate,
    QuoteSnapshot,
    Signal,
    StockSearchResult,
)
from .services.futu_client import (
    FutuDependencyError,
    FutuOpenDError,
    check_futu_health,
    get_history_kline_quota,
    get_futu_quote,
    request_history_klines,
)
from .services.stock_search import search_stocks

app = FastAPI(
    title="Stock Web Android MVP API",
    description="Backend API for the Android stock signal MVP.",
    version="0.1.0",
)


@app.on_event("startup")
def startup() -> None:
    init_database()


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/", tags=["system"])
def root() -> dict[str, str]:
    return {"message": "Stock Web backend is running"}


@app.get("/api/v1/positions", response_model=list[Position], tags=["positions"])
def api_list_positions() -> list[Position]:
    return list_positions()


@app.post(
    "/api/v1/positions",
    response_model=Position,
    status_code=status.HTTP_201_CREATED,
    tags=["positions"],
)
def api_create_position(payload: PositionCreate) -> Position:
    return create_position(payload)


@app.put("/api/v1/positions/{position_id}", response_model=Position, tags=["positions"])
def api_update_position(position_id: str, payload: PositionUpdate) -> Position:
    position = update_position(position_id, payload)
    if position is None:
        raise HTTPException(status_code=404, detail="Position not found")
    return position


@app.delete(
    "/api/v1/positions/{position_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["positions"],
)
def api_delete_position(position_id: str) -> None:
    if not delete_position(position_id):
        raise HTTPException(status_code=404, detail="Position not found")


@app.get("/api/v1/quotes", response_model=list[QuoteSnapshot], tags=["quotes"])
def api_get_quotes(codes: str = Query(default="")) -> list[QuoteSnapshot]:
    return get_quotes(codes.split(","))


@app.get("/api/v1/klines/{stock_code}", response_model=list[Candle], tags=["quotes"])
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


@app.get("/api/v1/signals", response_model=list[Signal], tags=["signals"])
def api_list_signals() -> list[Signal]:
    return list_signals()


@app.get("/api/v1/stocks/search", response_model=list[StockSearchResult], tags=["stocks"])
def api_search_stocks(
    q: str = Query(default="", min_length=0),
    limit: int = Query(default=20, ge=1, le=50),
    include_derivatives: bool = Query(default=False),
) -> list[StockSearchResult]:
    try:
        return search_stocks(q, limit, include_derivatives=include_derivatives)
    except FutuDependencyError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except FutuOpenDError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.get("/api/v1/futu/health", tags=["futu"])
def api_futu_health() -> dict[str, object]:
    try:
        return {"status": "ok", **check_futu_health()}
    except FutuDependencyError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except FutuOpenDError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.get("/api/v1/futu/quote", response_model=QuoteSnapshot, tags=["futu"])
def api_futu_quote(code: str = Query(default="HK.00700")) -> QuoteSnapshot:
    try:
        return get_futu_quote(code)
    except FutuDependencyError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except FutuOpenDError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.get("/api/v1/futu/kline-quota", tags=["futu"])
def api_futu_kline_quota() -> dict[str, object]:
    try:
        return {"status": "ok", "quota": get_history_kline_quota()}
    except FutuDependencyError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except FutuOpenDError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.post("/api/v1/quotes/refresh", response_model=list[QuoteSnapshot], tags=["quotes"])
def api_refresh_quotes(codes: str = Query(default="")) -> list[QuoteSnapshot]:
    requested_codes = [code.strip().upper() for code in codes.split(",") if code.strip()]
    if not requested_codes:
        requested_codes = [position.code for position in list_positions()]

    refreshed_quotes: list[QuoteSnapshot] = []
    for code in requested_codes:
        try:
            quote = get_futu_quote(code)
        except FutuDependencyError as error:
            raise HTTPException(status_code=503, detail=str(error)) from error
        except FutuOpenDError:
            continue
        refreshed_quotes.append(upsert_quote(quote))
    return refreshed_quotes


@app.post("/api/v1/klines/refresh", response_model=list[Candle], tags=["quotes"])
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
            raise HTTPException(status_code=503, detail=str(error)) from error
        except FutuOpenDError:
            continue
        refreshed_candles.extend(upsert_candles(candles))
    return refreshed_candles
