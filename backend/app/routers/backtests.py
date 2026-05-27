from fastapi import APIRouter, Query, status

from ..backtest import run_backtest
from ..backtest.volume_profile import run_volume_profile_backtest
from ..errors import not_found_error
from ..repositories.backtests import (
    create_backtest_run,
    delete_all_backtest_runs,
    delete_backtest_run,
    get_backtest_result,
    list_backtest_runs,
    rename_backtest_run,
)
from ..schemas import (
    BacktestBatchCreate,
    BacktestBatchItemResult,
    BacktestBatchResult,
    BacktestCreate,
    BacktestRename,
    BacktestResult,
    BacktestRun,
    VolumeProfileBacktestCreate,
    VolumeProfileBacktestResult,
)

router = APIRouter(prefix="/api/v1/backtests", tags=["backtests"])


@router.get("", response_model=list[BacktestRun])
def api_list_backtests(
    stock_code: str | None = Query(default=None),
    strategy_code: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=100),
) -> list[BacktestRun]:
    return list_backtest_runs(
        stock_code=stock_code,
        strategy_code=strategy_code,
        status=status_filter,
        limit=limit,
    )


@router.post(
    "",
    response_model=BacktestResult,
    status_code=status.HTTP_201_CREATED,
)
def api_create_backtest(payload: BacktestCreate) -> BacktestResult:
    run = create_backtest_run(payload)
    return run_backtest(run)


@router.post(
    "/batch",
    response_model=BacktestBatchResult,
    status_code=status.HTTP_201_CREATED,
)
def api_create_backtest_batch(payload: BacktestBatchCreate) -> BacktestBatchResult:
    results: list[BacktestBatchItemResult] = []
    completed_count = 0
    failed_count = 0

    for index, item in enumerate(payload.items):
        try:
            run = create_backtest_run(item)
            result = run_backtest(run)
            if result.run.status == "completed":
                completed_count += 1
            elif result.run.status == "failed":
                failed_count += 1
            results.append(
                BacktestBatchItemResult(
                    index=index,
                    request=item,
                    run=result.run,
                )
            )
            if result.run.status == "failed" and not payload.continue_on_error:
                break
        except Exception as error:
            failed_count += 1
            results.append(
                BacktestBatchItemResult(
                    index=index,
                    request=item,
                    error=str(error),
                )
            )
            if not payload.continue_on_error:
                break

    return BacktestBatchResult(
        total_count=len(payload.items),
        completed_count=completed_count,
        failed_count=failed_count,
        results=results,
    )


@router.post(
    "/volume-profile",
    response_model=VolumeProfileBacktestResult,
    status_code=status.HTTP_201_CREATED,
)
def api_create_volume_profile_backtest(
    payload: VolumeProfileBacktestCreate,
) -> VolumeProfileBacktestResult:
    return run_volume_profile_backtest(payload)


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def api_delete_all_backtests() -> None:
    delete_all_backtest_runs()


@router.get("/{run_id}", response_model=BacktestResult)
def api_get_backtest(run_id: str) -> BacktestResult:
    result = get_backtest_result(run_id)
    if result is None:
        raise not_found_error("Backtest run not found", run_id=run_id)
    return result


@router.put("/{run_id}/name", response_model=BacktestRun)
def api_rename_backtest(run_id: str, payload: BacktestRename) -> BacktestRun:
    run = rename_backtest_run(run_id, payload.name)
    if run is None:
        raise not_found_error("Backtest run not found", run_id=run_id)
    return run


@router.delete("/{run_id}", status_code=status.HTTP_204_NO_CONTENT)
def api_delete_backtest(run_id: str) -> None:
    deleted = delete_backtest_run(run_id)
    if not deleted:
        raise not_found_error("Backtest run not found", run_id=run_id)
