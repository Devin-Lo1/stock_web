from fastapi import APIRouter, Query

from ..errors import futu_dependency_error, futu_unavailable_error
from ..schemas import StockSearchResult
from ..services.futu_client import FutuDependencyError, FutuOpenDError
from ..services.stock_search import search_stocks

router = APIRouter(prefix="/api/v1/stocks", tags=["stocks"])


@router.get("/search", response_model=list[StockSearchResult])
def api_search_stocks(
    q: str = Query(default="", min_length=0),
    limit: int = Query(default=20, ge=1, le=50),
    include_derivatives: bool = Query(default=False),
) -> list[StockSearchResult]:
    try:
        return search_stocks(q, limit, include_derivatives=include_derivatives)
    except FutuDependencyError as error:
        raise futu_dependency_error(str(error)) from error
    except FutuOpenDError as error:
        raise futu_unavailable_error(str(error)) from error
