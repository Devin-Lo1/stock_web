from fastapi import APIRouter, Query

from ..errors import futu_dependency_error, futu_unavailable_error
from ..mock_store import get_quotes
from ..repositories.market_data import upsert_quote
from ..repositories.positions import list_positions
from ..schemas import QuoteSnapshot
from ..services.futu_client import FutuDependencyError, FutuOpenDError, get_futu_quote

router = APIRouter(prefix="/api/v1/quotes", tags=["quotes"])


@router.get("", response_model=list[QuoteSnapshot])
def api_get_quotes(codes: str = Query(default="")) -> list[QuoteSnapshot]:
    return get_quotes(codes.split(","))


@router.post("/refresh", response_model=list[QuoteSnapshot])
def api_refresh_quotes(codes: str = Query(default="")) -> list[QuoteSnapshot]:
    requested_codes = [code.strip().upper() for code in codes.split(",") if code.strip()]
    if not requested_codes:
        requested_codes = [position.code for position in list_positions()]

    refreshed_quotes: list[QuoteSnapshot] = []
    failed_codes: dict[str, str] = {}
    for code in requested_codes:
        try:
            quote = get_futu_quote(code)
        except FutuDependencyError as error:
            raise futu_dependency_error(str(error)) from error
        except FutuOpenDError as error:
            failed_codes[code] = str(error)
            continue
        refreshed_quotes.append(upsert_quote(quote))
    if not refreshed_quotes and failed_codes:
        raise futu_unavailable_error(str(failed_codes))
    return refreshed_quotes
