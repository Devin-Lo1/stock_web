from fastapi import APIRouter, Query

from ..schemas import PortfolioStrategyResult
from ..services.us_portfolio_strategy import build_us_portfolio_strategy

router = APIRouter(prefix="/api/v1/portfolio-strategy", tags=["portfolio-strategy"])


@router.get("/us", response_model=PortfolioStrategyResult)
def api_us_portfolio_strategy(
    cash: float = Query(default=0, ge=0),
) -> PortfolioStrategyResult:
    return build_us_portfolio_strategy(cash=cash)
