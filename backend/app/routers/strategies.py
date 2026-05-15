from fastapi import APIRouter

from ..repositories.strategies import list_strategy_definitions
from ..schemas import StrategyDefinition

router = APIRouter(prefix="/api/v1/strategies", tags=["strategies"])


@router.get("", response_model=list[StrategyDefinition])
def api_list_strategies() -> list[StrategyDefinition]:
    return list_strategy_definitions()
