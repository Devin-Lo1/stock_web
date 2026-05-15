from fastapi import APIRouter, status

from ..backtest import run_backtest
from ..database import create_backtest_run, get_backtest_result
from ..errors import not_found_error
from ..schemas import BacktestCreate, BacktestResult

router = APIRouter(prefix="/api/v1/backtests", tags=["backtests"])


@router.post(
    "",
    response_model=BacktestResult,
    status_code=status.HTTP_201_CREATED,
)
def api_create_backtest(payload: BacktestCreate) -> BacktestResult:
    run = create_backtest_run(payload)
    return run_backtest(run)


@router.get("/{run_id}", response_model=BacktestResult)
def api_get_backtest(run_id: str) -> BacktestResult:
    result = get_backtest_result(run_id)
    if result is None:
        raise not_found_error("Backtest run not found", run_id=run_id)
    return result
