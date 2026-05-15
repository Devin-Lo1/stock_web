from fastapi import APIRouter, status

from ..repositories.positions import list_positions
from ..errors import not_found_error
from ..mock_store import create_position, delete_position, update_position
from ..schemas import Position, PositionCreate, PositionUpdate

router = APIRouter(prefix="/api/v1/positions", tags=["positions"])


@router.get("", response_model=list[Position])
def api_list_positions() -> list[Position]:
    return list_positions()


@router.post(
    "",
    response_model=Position,
    status_code=status.HTTP_201_CREATED,
)
def api_create_position(payload: PositionCreate) -> Position:
    return create_position(payload)


@router.put("/{position_id}", response_model=Position)
def api_update_position(position_id: str, payload: PositionUpdate) -> Position:
    position = update_position(position_id, payload)
    if position is None:
        raise not_found_error("持仓不存在", position_id=position_id)
    return position


@router.delete(
    "/{position_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def api_delete_position(position_id: str) -> None:
    if not delete_position(position_id):
        raise not_found_error("持仓不存在", position_id=position_id)
