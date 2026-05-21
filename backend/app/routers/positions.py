from fastapi import APIRouter, Query, status

from ..repositories.positions import get_position, list_positions
from ..repositories.position_trades import (
    PositionTradeError,
    create_position_trade_for_position,
    list_position_trades,
)
from ..repositories.position_snapshots import (
    list_latest_position_snapshots,
    list_position_snapshots,
)
from ..errors import api_error, not_found_error
from ..mock_store import create_position, delete_position, update_position
from ..schemas import (
    Position,
    PositionCreate,
    PositionSnapshot,
    PositionTrade,
    PositionTradeCreate,
    PositionUpdate,
)
from ..services.position_snapshots import capture_position_snapshots

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


@router.get("/trades", response_model=list[PositionTrade])
def api_list_position_trades(
    position_id: str | None = Query(default=None),
    code: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
) -> list[PositionTrade]:
    return list_position_trades(position_id=position_id, code=code, limit=limit)


@router.get("/snapshots", response_model=list[PositionSnapshot])
def api_list_position_snapshots(
    position_id: str | None = Query(default=None),
    code: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
) -> list[PositionSnapshot]:
    return list_position_snapshots(position_id=position_id, code=code, limit=limit)


@router.get("/snapshots/latest", response_model=list[PositionSnapshot])
def api_list_latest_position_snapshots() -> list[PositionSnapshot]:
    return list_latest_position_snapshots()


@router.post("/snapshots/capture", response_model=list[PositionSnapshot])
def api_capture_position_snapshots() -> list[PositionSnapshot]:
    return capture_position_snapshots()


@router.get("/{position_id}/trades", response_model=list[PositionTrade])
def api_list_position_trades_for_position(
    position_id: str,
    limit: int = Query(default=100, ge=1, le=500),
) -> list[PositionTrade]:
    return list_position_trades(position_id=position_id, limit=limit)


@router.get("/{position_id}/snapshots", response_model=list[PositionSnapshot])
def api_list_position_snapshots_for_position(
    position_id: str,
    limit: int = Query(default=200, ge=1, le=1000),
) -> list[PositionSnapshot]:
    return list_position_snapshots(position_id=position_id, limit=limit)


@router.post(
    "/{position_id}/trades",
    response_model=PositionTrade,
    status_code=status.HTTP_201_CREATED,
)
def api_create_position_trade(
    position_id: str,
    payload: PositionTradeCreate,
) -> PositionTrade:
    position = get_position(position_id)
    if position is None:
        raise not_found_error("position not found", position_id=position_id)
    try:
        return create_position_trade_for_position(position, payload)
    except PositionTradeError as error:
        raise api_error(
            status.HTTP_400_BAD_REQUEST,
            "POSITION_TRADE_INVALID",
            str(error),
            {"position_id": position_id},
        ) from error


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
