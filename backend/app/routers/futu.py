from fastapi import APIRouter, Query

from ..errors import futu_dependency_error, futu_unavailable_error
from ..schemas import QuoteSnapshot
from ..services.futu_client import (
    FutuDependencyError,
    FutuOpenDError,
    check_futu_health,
    get_futu_quote,
    get_history_kline_quota,
)

router = APIRouter(prefix="/api/v1/futu", tags=["futu"])


@router.get("/health")
def api_futu_health() -> dict[str, object]:
    try:
        return {"status": "ok", **check_futu_health()}
    except FutuDependencyError as error:
        raise futu_dependency_error(str(error)) from error
    except FutuOpenDError as error:
        raise futu_unavailable_error(str(error)) from error


@router.get("/quote", response_model=QuoteSnapshot)
def api_futu_quote(code: str = Query(default="HK.00700")) -> QuoteSnapshot:
    try:
        return get_futu_quote(code)
    except FutuDependencyError as error:
        raise futu_dependency_error(str(error)) from error
    except FutuOpenDError as error:
        raise futu_unavailable_error(str(error)) from error


@router.get("/kline-quota")
def api_futu_kline_quota() -> dict[str, object]:
    try:
        return {"status": "ok", "quota": get_history_kline_quota()}
    except FutuDependencyError as error:
        raise futu_dependency_error(str(error)) from error
    except FutuOpenDError as error:
        raise futu_unavailable_error(str(error)) from error
