from datetime import date
from uuid import uuid4

from ..db.converters import _datetime_to_text, _now, _text_to_datetime
from ..db.core import _connect
from ..schemas import (
    FundNavPoint,
    FundPosition,
    FundPositionCreate,
    FundTrade,
    FundTradeCreate,
)


class FundTradeError(ValueError):
    pass


def list_fund_positions() -> list[FundPosition]:
    with _connect() as connection:
        rows = connection.execute(
            """
            SELECT id, fund_code, name, fund_type, shares, avg_cost_nav,
                   invested_amount, realized_profit, currency, created_at, updated_at
            FROM fund_positions
            ORDER BY created_at ASC
            """,
        ).fetchall()
    return [_row_to_fund_position(row) for row in rows]


def get_fund_position(position_id: str) -> FundPosition | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, fund_code, name, fund_type, shares, avg_cost_nav,
                   invested_amount, realized_profit, currency, created_at, updated_at
            FROM fund_positions
            WHERE id = ?
            """,
            (position_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_fund_position(row)


def create_fund_position(payload: FundPositionCreate) -> FundPosition:
    now = _now()
    invested_amount = payload.shares * payload.cost_nav + payload.fee
    avg_cost_nav = invested_amount / payload.shares if payload.shares > 0 else 0
    position = FundPosition(
        id=str(uuid4()),
        fund_code=payload.fund_code.strip(),
        name=payload.name.strip(),
        fund_type=payload.fund_type.strip(),
        shares=payload.shares,
        avg_cost_nav=avg_cost_nav,
        invested_amount=invested_amount,
        realized_profit=0,
        currency="CNY",
        created_at=now,
        updated_at=now,
    )
    opening_trade = None
    if payload.shares > 0:
        opening_trade = _build_fund_trade(
            position,
            FundTradeCreate(
                action="buy",
                shares=payload.shares,
                nav=payload.cost_nav,
                fee=payload.fee,
                trade_date=payload.trade_date,
                note=payload.note,
            ),
        )
    with _connect() as connection:
        _insert_fund_position(connection, position)
        if opening_trade is not None:
            _insert_fund_trade(connection, opening_trade)
    return position


def delete_fund_position(position_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute(
            "DELETE FROM fund_positions WHERE id = ?",
            (position_id,),
        )
    return cursor.rowcount > 0


def create_fund_trade_for_position(
    position: FundPosition,
    payload: FundTradeCreate,
) -> FundTrade:
    trade = _build_fund_trade(position, payload)
    updated = _position_after_trade(position, trade)
    with _connect() as connection:
        _insert_fund_trade(connection, trade)
        connection.execute(
            """
            UPDATE fund_positions
            SET shares = ?,
                avg_cost_nav = ?,
                invested_amount = ?,
                realized_profit = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                updated.shares,
                updated.avg_cost_nav,
                updated.invested_amount,
                updated.realized_profit,
                _datetime_to_text(updated.updated_at),
                updated.id,
            ),
        )
    return trade


def list_fund_trades(
    *,
    position_id: str | None = None,
    fund_code: str | None = None,
    limit: int = 100,
) -> list[FundTrade]:
    clauses: list[str] = []
    params: list[object] = []
    if position_id:
        clauses.append("fund_position_id = ?")
        params.append(position_id)
    if fund_code:
        clauses.append("fund_code = ?")
        params.append(fund_code)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    params.append(limit)
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT id, fund_position_id, fund_code, name, action, shares, nav,
                   fee, trade_date, note, created_at, updated_at
            FROM fund_trades
            {where}
            ORDER BY trade_date DESC, created_at DESC
            LIMIT ?
            """,
            tuple(params),
        ).fetchall()
    return [_row_to_fund_trade(row) for row in rows]


def upsert_fund_navs(points: list[FundNavPoint]) -> None:
    if not points:
        return
    with _connect() as connection:
        connection.executemany(
            """
            INSERT INTO fund_navs (
                fund_code, nav_date, unit_nav, accumulated_nav, daily_growth_rate,
                subscribe_status, redeem_status, source, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(fund_code, nav_date) DO UPDATE SET
                unit_nav = excluded.unit_nav,
                accumulated_nav = excluded.accumulated_nav,
                daily_growth_rate = excluded.daily_growth_rate,
                subscribe_status = excluded.subscribe_status,
                redeem_status = excluded.redeem_status,
                source = excluded.source,
                updated_at = excluded.updated_at
            """,
            [_fund_nav_values(point) for point in points],
        )


def list_fund_navs(fund_code: str, *, limit: int = 90) -> list[FundNavPoint]:
    with _connect() as connection:
        rows = connection.execute(
            """
            SELECT fund_code, nav_date, unit_nav, accumulated_nav, daily_growth_rate,
                   subscribe_status, redeem_status, source, updated_at
            FROM fund_navs
            WHERE fund_code = ?
            ORDER BY nav_date DESC
            LIMIT ?
            """,
            (fund_code, limit),
        ).fetchall()
    return [_row_to_fund_nav(row) for row in rows]


def get_latest_fund_nav(fund_code: str) -> FundNavPoint | None:
    rows = list_fund_navs(fund_code, limit=1)
    return rows[0] if rows else None


def _insert_fund_position(connection, position: FundPosition) -> None:
    connection.execute(
        """
        INSERT INTO fund_positions (
            id, fund_code, name, fund_type, shares, avg_cost_nav,
            invested_amount, realized_profit, currency, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            position.id,
            position.fund_code,
            position.name,
            position.fund_type,
            position.shares,
            position.avg_cost_nav,
            position.invested_amount,
            position.realized_profit,
            position.currency,
            _datetime_to_text(position.created_at),
            _datetime_to_text(position.updated_at),
        ),
    )


def _insert_fund_trade(connection, trade: FundTrade) -> None:
    connection.execute(
        """
        INSERT INTO fund_trades (
            id, fund_position_id, fund_code, name, action, shares, nav, fee,
            trade_date, note, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            trade.id,
            trade.fund_position_id,
            trade.fund_code,
            trade.name,
            trade.action,
            trade.shares,
            trade.nav,
            trade.fee,
            trade.trade_date.isoformat(),
            trade.note,
            _datetime_to_text(trade.created_at),
            _datetime_to_text(trade.updated_at),
        ),
    )


def _build_fund_trade(position: FundPosition, payload: FundTradeCreate) -> FundTrade:
    now = _now()
    return FundTrade(
        id=str(uuid4()),
        fund_position_id=position.id,
        fund_code=position.fund_code,
        name=position.name,
        action=payload.action,
        shares=payload.shares,
        nav=payload.nav,
        fee=payload.fee,
        trade_date=payload.trade_date or now.date(),
        note=payload.note,
        created_at=now,
        updated_at=now,
    )


def _position_after_trade(position: FundPosition, trade: FundTrade) -> FundPosition:
    if trade.action == "buy":
        invested_amount = position.invested_amount + trade.shares * trade.nav + trade.fee
        shares = position.shares + trade.shares
        avg_cost_nav = invested_amount / shares if shares > 0 else 0
        return position.model_copy(
            update={
                "shares": shares,
                "avg_cost_nav": avg_cost_nav,
                "invested_amount": invested_amount,
                "updated_at": _now(),
            },
        )
    if trade.shares > position.shares:
        raise FundTradeError("sell shares exceed current holding")
    cost_basis = position.avg_cost_nav * trade.shares
    proceeds = trade.shares * trade.nav - trade.fee
    shares = position.shares - trade.shares
    invested_amount = max(0, position.invested_amount - cost_basis)
    avg_cost_nav = invested_amount / shares if shares > 0 else 0
    return position.model_copy(
        update={
            "shares": shares,
            "avg_cost_nav": avg_cost_nav,
            "invested_amount": invested_amount,
            "realized_profit": position.realized_profit + proceeds - cost_basis,
            "updated_at": _now(),
        },
    )


def _fund_nav_values(point: FundNavPoint) -> tuple[object, ...]:
    return (
        point.fund_code,
        point.nav_date.isoformat(),
        point.unit_nav,
        point.accumulated_nav,
        point.daily_growth_rate,
        point.subscribe_status,
        point.redeem_status,
        point.source,
        _datetime_to_text(point.updated_at),
    )


def _row_to_fund_position(row) -> FundPosition:
    return FundPosition(
        id=row["id"],
        fund_code=row["fund_code"],
        name=row["name"],
        fund_type=row["fund_type"],
        shares=row["shares"],
        avg_cost_nav=row["avg_cost_nav"],
        invested_amount=row["invested_amount"],
        realized_profit=row["realized_profit"],
        currency=row["currency"],
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_fund_trade(row) -> FundTrade:
    return FundTrade(
        id=row["id"],
        fund_position_id=row["fund_position_id"],
        fund_code=row["fund_code"],
        name=row["name"],
        action=row["action"],
        shares=row["shares"],
        nav=row["nav"],
        fee=row["fee"],
        trade_date=date.fromisoformat(row["trade_date"]),
        note=row["note"],
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_fund_nav(row) -> FundNavPoint:
    return FundNavPoint(
        fund_code=row["fund_code"],
        nav_date=date.fromisoformat(row["nav_date"]),
        unit_nav=row["unit_nav"],
        accumulated_nav=row["accumulated_nav"],
        daily_growth_rate=row["daily_growth_rate"],
        subscribe_status=row["subscribe_status"],
        redeem_status=row["redeem_status"],
        source=row["source"],
        updated_at=_text_to_datetime(row["updated_at"]),
    )
