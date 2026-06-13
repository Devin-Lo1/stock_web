from fastapi import APIRouter, Query

from ..errors import futu_dependency_error, futu_unavailable_error
from ..mock_store import get_quotes
from ..repositories.market_data import upsert_quote
from ..repositories.positions import list_positions
from ..schemas import CapitalFlowSnapshot, QuoteSnapshot
from ..services.futu_client import (
    FutuDependencyError,
    FutuOpenDError,
    get_futu_capital_flow,
    get_futu_quotes,
)

router = APIRouter(prefix="/api/v1/quotes", tags=["quotes"])


@router.get("", response_model=list[QuoteSnapshot])
def api_get_quotes(codes: str = Query(default="")) -> list[QuoteSnapshot]:
    return get_quotes(codes.split(","))


@router.post("/refresh", response_model=list[QuoteSnapshot])
def api_refresh_quotes(codes: str = Query(default="")) -> list[QuoteSnapshot]:
    requested_codes = [
        code.strip().upper()
        for code in codes.split(",")
        if code.strip()
    ]
    if not requested_codes:
        requested_codes = [position.code for position in list_positions()]

    try:
        quotes = get_futu_quotes(requested_codes)
    except FutuDependencyError as error:
        raise futu_dependency_error(str(error)) from error
    except FutuOpenDError as error:
        raise futu_unavailable_error(str(error)) from error

    refreshed_quotes = [upsert_quote(quote) for quote in quotes]
    if not refreshed_quotes:
        raise futu_unavailable_error(
            f"No quote returned for {','.join(requested_codes)}",
        )
    return refreshed_quotes


@router.get("/{code}/capital-flow", response_model=CapitalFlowSnapshot)
def api_get_capital_flow(code: str) -> CapitalFlowSnapshot:
    try:
        return get_futu_capital_flow(code)
    except FutuDependencyError as error:
        raise futu_dependency_error(str(error)) from error
    except FutuOpenDError as error:
        raise futu_unavailable_error(str(error)) from error
