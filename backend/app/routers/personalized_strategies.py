from fastapi import APIRouter, Query, status

from ..errors import api_error
from ..schemas import (
    PersonalizedStrategyBulkScanResult,
    PersonalizedStrategyScanResult,
    PersonalizedStrategyTemplate,
)
from ..services.personalized_strategies import (
    get_personalized_strategy_template,
    list_personalized_strategy_templates,
    scan_all_personalized_strategies,
    scan_personalized_strategy,
)

router = APIRouter(
    prefix="/api/v1/personalized-strategies",
    tags=["personalized-strategies"],
)


@router.get("", response_model=list[PersonalizedStrategyTemplate])
def api_list_personalized_strategy_templates() -> list[PersonalizedStrategyTemplate]:
    return list_personalized_strategy_templates()


@router.post("/scan-all", response_model=PersonalizedStrategyBulkScanResult)
def api_scan_all_personalized_strategies(
    refresh: bool = Query(default=False),
    limit: int = Query(default=3, ge=1, le=10),
) -> PersonalizedStrategyBulkScanResult:
    return scan_all_personalized_strategies(refresh=refresh, limit=limit)


@router.get("/{symbol}", response_model=PersonalizedStrategyTemplate)
def api_get_personalized_strategy_template(symbol: str) -> PersonalizedStrategyTemplate:
    template = get_personalized_strategy_template(symbol)
    if template is None:
        raise _strategy_not_found(symbol)
    return template


@router.post("/{symbol}/scan", response_model=PersonalizedStrategyScanResult)
def api_scan_personalized_strategy(
    symbol: str,
    refresh: bool = Query(default=False),
) -> PersonalizedStrategyScanResult:
    result = scan_personalized_strategy(symbol, refresh=refresh)
    if result is None:
        raise _strategy_not_found(symbol)
    return result


def _strategy_not_found(symbol: str):
    return api_error(
        status.HTTP_404_NOT_FOUND,
        "PERSONALIZED_STRATEGY_NOT_FOUND",
        "personalized strategy template not found",
        {"symbol": symbol},
    )
