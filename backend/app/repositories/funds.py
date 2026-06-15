from datetime import date, timedelta
from uuid import uuid4

from ..db.converters import _datetime_to_text, _now, _text_to_datetime
from ..db.core import _connect
from ..schemas import (
    FundNavPoint,
    FundPosition,
    FundPositionCreate,
    FundPositionHoldingSync,
    FundPositionUpdate,
    FundTrade,
    FundTradeCreate,
    FundTradeRecord,
    FundTradeRecordCreate,
)


class FundTradeError(ValueError):
    pass


_NAV_LOOKUP_LIMIT = 5000


def list_fund_positions() -> list[FundPosition]:
    with _connect() as connection:
        rows = connection.execute(
            """
            SELECT id, fund_code, name, fund_type, shares, avg_cost_nav,
                   invested_amount, realized_profit, currency, alert_enabled,
                   alert_threshold_percent, alert_buy_amount, alert_sell_ratio,
                   created_at, updated_at
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
                   invested_amount, realized_profit, currency, alert_enabled,
                   alert_threshold_percent, alert_buy_amount, alert_sell_ratio,
                   created_at, updated_at
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
    fund_code = payload.fund_code.strip()
    trade_date = _resolve_operation_trade_date(
        fund_code=fund_code,
        operation_date=payload.operation_date,
        operation_after_cutoff=payload.operation_after_cutoff,
        fallback_trade_date=payload.trade_date,
    )
    cost_nav = _resolve_nav_value(
        fund_code=fund_code,
        trade_date=trade_date,
        provided_nav=payload.cost_nav,
        auto_nav=payload.auto_nav,
    )
    shares = _resolve_trade_shares(
        action="buy",
        provided_shares=payload.shares,
        amount=payload.amount,
        nav=cost_nav,
        fee=payload.fee,
    )
    invested_amount = shares * cost_nav + payload.fee if shares > 0 else 0
    avg_cost_nav = invested_amount / shares if shares > 0 else 0
    position = FundPosition(
        id=str(uuid4()),
        fund_code=fund_code,
        name=payload.name.strip(),
        fund_type=payload.fund_type.strip(),
        shares=shares,
        avg_cost_nav=avg_cost_nav,
        invested_amount=invested_amount,
        realized_profit=0,
        currency="CNY",
        alert_enabled=payload.alert_enabled,
        alert_threshold_percent=payload.alert_threshold_percent,
        alert_buy_amount=payload.alert_buy_amount,
        alert_sell_ratio=payload.alert_sell_ratio,
        created_at=now,
        updated_at=now,
    )
    opening_trade = None
    if shares > 0:
        opening_trade = _build_fund_trade(
            position,
            FundTradeCreate(
                action="buy",
                shares=shares,
                nav=cost_nav,
                fee=payload.fee,
                trade_date=trade_date,
                operation_date=payload.operation_date,
                operation_after_cutoff=payload.operation_after_cutoff,
                note=payload.note,
            ),
        )
    with _connect() as connection:
        _insert_fund_position(connection, position)
        if opening_trade is not None:
            _insert_fund_trade(connection, opening_trade)
            _insert_fund_trade_record(
                connection,
                _fund_trade_to_record(opening_trade, is_system=True),
            )
    return position


def delete_fund_position(position_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute(
            "DELETE FROM fund_positions WHERE id = ?",
            (position_id,),
        )
    return cursor.rowcount > 0


def update_fund_position(
    position: FundPosition,
    payload: FundPositionUpdate,
) -> FundPosition:
    updated = position.model_copy(
        update={
            "name": payload.name.strip() if payload.name is not None else position.name,
            "fund_type": payload.fund_type.strip()
            if payload.fund_type is not None
            else position.fund_type,
            "alert_enabled": payload.alert_enabled
            if payload.alert_enabled is not None
            else position.alert_enabled,
            "alert_threshold_percent": payload.alert_threshold_percent
            if payload.alert_threshold_percent is not None
            else position.alert_threshold_percent,
            "alert_buy_amount": payload.alert_buy_amount
            if payload.alert_buy_amount is not None
            else position.alert_buy_amount,
            "alert_sell_ratio": payload.alert_sell_ratio
            if payload.alert_sell_ratio is not None
            else position.alert_sell_ratio,
            "updated_at": _now(),
        },
    )
    with _connect() as connection:
        connection.execute(
            """
            UPDATE fund_positions
            SET name = ?,
                fund_type = ?,
                alert_enabled = ?,
                alert_threshold_percent = ?,
                alert_buy_amount = ?,
                alert_sell_ratio = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                updated.name,
                updated.fund_type,
                1 if updated.alert_enabled else 0,
                updated.alert_threshold_percent,
                updated.alert_buy_amount,
                updated.alert_sell_ratio,
                _datetime_to_text(updated.updated_at),
                updated.id,
            ),
        )
    return updated


def sync_fund_position_holding(
    position: FundPosition,
    payload: FundPositionHoldingSync,
) -> FundPosition:
    trade = _build_fund_trade(
        position,
        FundTradeCreate(
            action="buy",
            shares=payload.shares,
            nav=payload.cost_nav,
            fee=payload.fee,
            trade_date=payload.trade_date,
            operation_date=payload.operation_date,
            operation_after_cutoff=payload.operation_after_cutoff,
            note=payload.note,
        ),
    )
    updated = position.model_copy(
        update={
            "shares": trade.shares,
            "avg_cost_nav": (trade.shares * trade.nav + trade.fee) / trade.shares,
            "invested_amount": trade.shares * trade.nav + trade.fee,
            "realized_profit": 0,
            "updated_at": _now(),
        },
    )
    with _connect() as connection:
        connection.execute(
            "DELETE FROM fund_trades WHERE fund_position_id = ?",
            (position.id,),
        )
        _insert_fund_trade(connection, trade)
        _insert_fund_trade_record(
            connection,
            _fund_trade_to_record(trade, action="correct", is_system=True),
        )
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
    return updated


def create_fund_trade_for_position(
    position: FundPosition,
    payload: FundTradeCreate,
) -> FundTrade:
    pending = _build_pending_trade_record(position, payload)
    if pending is not None:
        with _connect() as connection:
            _insert_fund_trade_record(connection, pending)
        return _pending_record_to_trade(pending)

    trade = _build_fund_trade(position, payload)
    with _connect() as connection:
        duplicate = _find_duplicate_fund_trade(connection, trade)
        if duplicate is not None:
            _ensure_system_trade_record(connection, duplicate)
            return duplicate
        _insert_fund_trade(connection, trade)
        _insert_fund_trade_record(
            connection,
            _fund_trade_to_record(trade, is_system=True),
        )
        updated = _recalculate_position_from_trades(connection, position)
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


def _find_duplicate_fund_trade(connection, trade: FundTrade) -> FundTrade | None:
    row = connection.execute(
        """
        SELECT id, fund_position_id, fund_code, name, action, shares, nav,
               fee, trade_date, operation_date, operation_after_cutoff,
               note, created_at, updated_at
        FROM fund_trades
        WHERE fund_position_id = ?
          AND action = ?
          AND ABS(shares - ?) < 0.000001
          AND ABS(nav - ?) < 0.000001
          AND ABS(fee - ?) < 0.000001
          AND trade_date = ?
          AND COALESCE(operation_date, '') = ?
          AND operation_after_cutoff = ?
          AND COALESCE(note, '') = ?
        ORDER BY created_at ASC
        LIMIT 1
        """,
        (
            trade.fund_position_id,
            trade.action,
            trade.shares,
            trade.nav,
            trade.fee,
            trade.trade_date.isoformat(),
            trade.operation_date.isoformat() if trade.operation_date else "",
            1 if trade.operation_after_cutoff else 0,
            trade.note or "",
        ),
    ).fetchone()
    if row is None:
        return None
    return _row_to_fund_trade(row)


def _ensure_system_trade_record(connection, trade: FundTrade) -> None:
    row = connection.execute(
        """
        SELECT id
        FROM fund_trade_records
        WHERE source_trade_id = ?
        LIMIT 1
        """,
        (trade.id,),
    ).fetchone()
    if row is None:
        _insert_fund_trade_record(
            connection,
            _fund_trade_to_record(trade, is_system=True),
        )


def materialize_pending_fund_trades(position_id: str | None = None) -> int:
    clauses = [
        "source_trade_id IS NULL",
        "is_system = 1",
        "action IN ('buy', 'sell')",
    ]
    params: list[object] = []
    if position_id:
        clauses.append("fund_position_id = ?")
        params.append(position_id)
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT id, fund_position_id, fund_code, name, action, shares, nav,
                   amount, fee, trade_date, operation_date,
                   operation_after_cutoff, note, source_trade_id, is_system,
                   created_at, updated_at
            FROM fund_trade_records
            WHERE {' AND '.join(clauses)}
            ORDER BY trade_date ASC, created_at ASC
            """,
            tuple(params),
        ).fetchall()

        materialized_count = 0
        changed_positions: set[str] = set()
        for row in rows:
            record = _row_to_fund_trade_record(row)
            nav_point = _confirmation_nav_for_record(record)
            if nav_point is None or nav_point.unit_nav <= 0:
                continue
            try:
                trade = _trade_from_pending_record(record, nav_point)
            except FundTradeError:
                continue
            _insert_fund_trade(connection, trade)
            replacement = _fund_trade_to_record(trade, is_system=True)
            connection.execute(
                """
                UPDATE fund_trade_records
                SET shares = ?,
                    nav = ?,
                    amount = ?,
                    trade_date = ?,
                    source_trade_id = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                (
                    replacement.shares,
                    replacement.nav,
                    replacement.amount,
                    replacement.trade_date.isoformat(),
                    trade.id,
                    _datetime_to_text(trade.updated_at),
                    record.id,
                ),
            )
            changed_positions.add(record.fund_position_id)
            materialized_count += 1

        for changed_position_id in changed_positions:
            row = connection.execute(
                """
                SELECT id, fund_code, name, fund_type, shares, avg_cost_nav,
                       invested_amount, realized_profit, currency, alert_enabled,
                       alert_threshold_percent, alert_buy_amount, alert_sell_ratio,
                       created_at, updated_at
                FROM fund_positions
                WHERE id = ?
                """,
                (changed_position_id,),
            ).fetchone()
            if row is None:
                continue
            updated = _recalculate_position_from_trades(
                connection,
                _row_to_fund_position(row),
            )
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
    return materialized_count


def list_fund_trade_records(
    *,
    position_id: str | None = None,
    fund_code: str | None = None,
    limit: int = 100,
) -> list[FundTradeRecord]:
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
                   amount, fee, trade_date, operation_date,
                   operation_after_cutoff, note, source_trade_id, is_system,
                   created_at, updated_at
            FROM fund_trade_records
            {where}
            ORDER BY trade_date DESC, created_at DESC
            LIMIT ?
            """,
            tuple(params),
        ).fetchall()
    return [_row_to_fund_trade_record(row) for row in rows]


def create_fund_trade_record_for_position(
    position: FundPosition,
    payload: FundTradeRecordCreate,
) -> FundTradeRecord:
    record = _build_fund_trade_record(position, payload)
    with _connect() as connection:
        _insert_fund_trade_record(connection, record)
    return record


def delete_fund_trade_record(position_id: str, record_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute(
            """
            DELETE FROM fund_trade_records
            WHERE id = ? AND fund_position_id = ?
            """,
            (record_id, position_id),
        )
    return cursor.rowcount > 0


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
                   fee, trade_date, operation_date, operation_after_cutoff,
                   note, created_at, updated_at
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
            invested_amount, realized_profit, currency, alert_enabled,
            alert_threshold_percent, alert_buy_amount, alert_sell_ratio,
            created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            1 if position.alert_enabled else 0,
            position.alert_threshold_percent,
            position.alert_buy_amount,
            position.alert_sell_ratio,
            _datetime_to_text(position.created_at),
            _datetime_to_text(position.updated_at),
        ),
    )


def _insert_fund_trade(connection, trade: FundTrade) -> None:
    connection.execute(
        """
        INSERT INTO fund_trades (
            id, fund_position_id, fund_code, name, action, shares, nav, fee,
            trade_date, operation_date, operation_after_cutoff, note,
            created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            trade.operation_date.isoformat() if trade.operation_date else None,
            1 if trade.operation_after_cutoff else 0,
            trade.note,
            _datetime_to_text(trade.created_at),
            _datetime_to_text(trade.updated_at),
        ),
    )


def _insert_fund_trade_record(connection, record: FundTradeRecord) -> None:
    connection.execute(
        """
        INSERT INTO fund_trade_records (
            id, fund_position_id, fund_code, name, action, shares, nav, amount,
            fee, trade_date, operation_date, operation_after_cutoff, note,
            source_trade_id, is_system, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            record.id,
            record.fund_position_id,
            record.fund_code,
            record.name,
            record.action,
            record.shares,
            record.nav,
            record.amount,
            record.fee,
            record.trade_date.isoformat(),
            record.operation_date.isoformat() if record.operation_date else None,
            1 if record.operation_after_cutoff else 0,
            record.note,
            record.source_trade_id,
            1 if record.is_system else 0,
            _datetime_to_text(record.created_at),
            _datetime_to_text(record.updated_at),
        ),
    )


def _build_fund_trade(position: FundPosition, payload: FundTradeCreate) -> FundTrade:
    now = _now()
    trade_date = _resolve_operation_trade_date(
        fund_code=position.fund_code,
        operation_date=payload.operation_date,
        operation_after_cutoff=payload.operation_after_cutoff,
        fallback_trade_date=payload.trade_date,
    )
    nav = _resolve_nav_value(
        fund_code=position.fund_code,
        trade_date=trade_date,
        provided_nav=payload.nav,
        auto_nav=payload.auto_nav,
    )
    shares = _resolve_trade_shares(
        action=payload.action,
        provided_shares=payload.shares,
        amount=payload.amount,
        nav=nav,
        fee=payload.fee,
    )
    if shares <= 0:
        raise FundTradeError("fund trade shares must be greater than zero")
    return FundTrade(
        id=str(uuid4()),
        fund_position_id=position.id,
        fund_code=position.fund_code,
        name=position.name,
        action=payload.action,
        shares=shares,
        nav=nav,
        fee=payload.fee,
        trade_date=trade_date,
        operation_date=payload.operation_date,
        operation_after_cutoff=payload.operation_after_cutoff,
        note=payload.note,
        created_at=now,
        updated_at=now,
    )


def _build_pending_trade_record(
    position: FundPosition,
    payload: FundTradeCreate,
) -> FundTradeRecord | None:
    if not payload.auto_nav:
        return None
    trade_date = _resolve_operation_trade_date(
        fund_code=position.fund_code,
        operation_date=payload.operation_date,
        operation_after_cutoff=payload.operation_after_cutoff,
        fallback_trade_date=payload.trade_date,
    )
    if _nav_point_for_date(position.fund_code, trade_date) is not None:
        return None
    latest_nav = get_latest_fund_nav(position.fund_code)
    fallback_nav = (
        latest_nav.unit_nav
        if latest_nav is not None and latest_nav.unit_nav > 0
        else payload.nav
    )
    record = _build_fund_trade_record(
        position,
        FundTradeRecordCreate(
            action=payload.action,
            shares=payload.shares,
            nav=fallback_nav,
            amount=payload.amount,
            fee=payload.fee,
            auto_nav=False,
            trade_date=trade_date,
            operation_date=payload.operation_date,
            operation_after_cutoff=payload.operation_after_cutoff,
            note=payload.note,
        ),
    )
    return record.model_copy(update={"is_system": True})


def _pending_record_to_trade(record: FundTradeRecord) -> FundTrade:
    return FundTrade(
        id=record.id,
        fund_position_id=record.fund_position_id,
        fund_code=record.fund_code,
        name=record.name,
        action="sell" if record.action == "sell" else "buy",
        shares=record.shares,
        nav=record.nav,
        fee=record.fee,
        trade_date=record.trade_date,
        operation_date=record.operation_date,
        operation_after_cutoff=record.operation_after_cutoff,
        note=record.note,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )


def _confirmation_nav_for_record(record: FundTradeRecord) -> FundNavPoint | None:
    if record.operation_date is None:
        return _nav_point_for_date(record.fund_code, record.trade_date)
    trade_date = _resolve_operation_trade_date(
        fund_code=record.fund_code,
        operation_date=record.operation_date,
        operation_after_cutoff=record.operation_after_cutoff,
        fallback_trade_date=record.trade_date,
    )
    return _nav_point_for_date(record.fund_code, trade_date)


def _trade_from_pending_record(
    record: FundTradeRecord,
    nav_point: FundNavPoint,
) -> FundTrade:
    action = "sell" if record.action == "sell" else "buy"
    shares = _resolve_trade_shares(
        action=action,
        provided_shares=record.shares,
        amount=record.amount,
        nav=nav_point.unit_nav,
        fee=record.fee,
    )
    if shares <= 0:
        raise FundTradeError("pending fund trade shares must be greater than zero")
    now = _now()
    return FundTrade(
        id=str(uuid4()),
        fund_position_id=record.fund_position_id,
        fund_code=record.fund_code,
        name=record.name,
        action=action,
        shares=shares,
        nav=nav_point.unit_nav,
        fee=record.fee,
        trade_date=nav_point.nav_date,
        operation_date=record.operation_date,
        operation_after_cutoff=record.operation_after_cutoff,
        note=record.note,
        created_at=now,
        updated_at=now,
    )


def _build_fund_trade_record(
    position: FundPosition,
    payload: FundTradeRecordCreate,
) -> FundTradeRecord:
    now = _now()
    trade_date = _resolve_operation_trade_date(
        fund_code=position.fund_code,
        operation_date=payload.operation_date,
        operation_after_cutoff=payload.operation_after_cutoff,
        fallback_trade_date=payload.trade_date,
    )
    nav = _resolve_nav_value(
        fund_code=position.fund_code,
        trade_date=trade_date,
        provided_nav=payload.nav,
        auto_nav=payload.auto_nav,
    )
    trade_action = "sell" if payload.action == "sell" else "buy"
    shares = _resolve_trade_shares(
        action=trade_action,
        provided_shares=payload.shares,
        amount=payload.amount,
        nav=nav,
        fee=payload.fee,
    )
    if shares <= 0:
        raise FundTradeError("fund trade record shares must be greater than zero")
    amount = payload.amount if payload.amount > 0 else _trade_record_amount(
        action=payload.action,
        shares=shares,
        nav=nav,
        fee=payload.fee,
    )
    return FundTradeRecord(
        id=str(uuid4()),
        fund_position_id=position.id,
        fund_code=position.fund_code,
        name=position.name,
        action=payload.action,
        shares=shares,
        nav=nav,
        amount=amount,
        fee=payload.fee,
        trade_date=trade_date,
        operation_date=payload.operation_date,
        operation_after_cutoff=payload.operation_after_cutoff,
        note=payload.note,
        source_trade_id=None,
        is_system=False,
        created_at=now,
        updated_at=now,
    )


def _fund_trade_to_record(
    trade: FundTrade,
    *,
    action: str | None = None,
    is_system: bool,
) -> FundTradeRecord:
    return FundTradeRecord(
        id=str(uuid4()),
        fund_position_id=trade.fund_position_id,
        fund_code=trade.fund_code,
        name=trade.name,
        action=action or trade.action,
        shares=trade.shares,
        nav=trade.nav,
        amount=_trade_record_amount(
            action=action or trade.action,
            shares=trade.shares,
            nav=trade.nav,
            fee=trade.fee,
        ),
        fee=trade.fee,
        trade_date=trade.trade_date,
        operation_date=trade.operation_date,
        operation_after_cutoff=trade.operation_after_cutoff,
        note=trade.note,
        source_trade_id=trade.id,
        is_system=is_system,
        created_at=trade.created_at,
        updated_at=trade.updated_at,
    )


def _trade_record_amount(
    *,
    action: str,
    shares: float,
    nav: float,
    fee: float,
) -> float:
    gross = shares * nav
    if action == "sell":
        return max(0, gross - fee)
    return gross + fee


def _resolve_operation_trade_date(
    *,
    fund_code: str,
    operation_date: date | None,
    operation_after_cutoff: bool,
    fallback_trade_date: date | None,
) -> date:
    if operation_date is None:
        return fallback_trade_date or _now().date()
    navs = _sorted_navs_for_code(fund_code)
    point = _first_confirmation_nav(
        navs,
        operation_date=operation_date,
        operation_after_cutoff=operation_after_cutoff,
    )
    if point is None:
        _refresh_navs_for_code(fund_code)
        navs = _sorted_navs_for_code(fund_code)
        point = _first_confirmation_nav(
            navs,
            operation_date=operation_date,
            operation_after_cutoff=operation_after_cutoff,
        )
    if point is not None:
        return point.nav_date
    return _weekday_confirmation_date(operation_date, operation_after_cutoff)


def _first_confirmation_nav(
    navs: list[FundNavPoint],
    *,
    operation_date: date,
    operation_after_cutoff: bool,
) -> FundNavPoint | None:
    for point in navs:
        if operation_after_cutoff:
            if point.nav_date > operation_date:
                return point
        elif point.nav_date >= operation_date:
            return point
    return None


def _weekday_confirmation_date(
    operation_date: date,
    operation_after_cutoff: bool,
) -> date:
    candidate = operation_date + timedelta(days=1 if operation_after_cutoff else 0)
    while candidate.weekday() >= 5:
        candidate += timedelta(days=1)
    return candidate


def _resolve_nav_value(
    *,
    fund_code: str,
    trade_date: date,
    provided_nav: float,
    auto_nav: bool,
) -> float:
    nav = provided_nav
    if auto_nav or nav <= 0:
        point = _nav_point_for_date(fund_code, trade_date)
        if point is not None and point.unit_nav > 0:
            nav = point.unit_nav
    if nav <= 0:
        raise FundTradeError("fund nav is required for trade date")
    return nav


def _resolve_trade_shares(
    *,
    action: str,
    provided_shares: float,
    amount: float,
    nav: float,
    fee: float,
) -> float:
    if amount > 0:
        if nav <= 0:
            raise FundTradeError("fund nav is required for amount conversion")
        if action == "buy":
            available_amount = amount - fee
            if available_amount <= 0:
                raise FundTradeError("fund buy amount must be greater than fee")
            return available_amount / nav
        return amount / nav
    return provided_shares


def _nav_point_for_date(fund_code: str, nav_date: date) -> FundNavPoint | None:
    navs = _sorted_navs_for_code(fund_code)
    point = _find_nav_point(navs, nav_date)
    if point is not None:
        return point
    _refresh_navs_for_code(fund_code)
    return _find_nav_point(_sorted_navs_for_code(fund_code), nav_date)


def _find_nav_point(
    navs: list[FundNavPoint],
    nav_date: date,
) -> FundNavPoint | None:
    for point in navs:
        if point.nav_date == nav_date:
            return point
    return None


def _sorted_navs_for_code(fund_code: str) -> list[FundNavPoint]:
    return sorted(list_fund_navs(fund_code, limit=_NAV_LOOKUP_LIMIT), key=lambda item: item.nav_date)


def _refresh_navs_for_code(fund_code: str) -> None:
    try:
        from ..services.fund_provider import EastmoneyFundProvider

        points = EastmoneyFundProvider().nav_history(fund_code, limit=_NAV_LOOKUP_LIMIT)
    except Exception:
        return
    upsert_fund_navs(points)


def _recalculate_position_from_trades(connection, position: FundPosition) -> FundPosition:
    rows = connection.execute(
        """
        SELECT id, fund_position_id, fund_code, name, action, shares, nav,
               fee, trade_date, operation_date, operation_after_cutoff,
               note, created_at, updated_at
        FROM fund_trades
        WHERE fund_position_id = ?
        ORDER BY trade_date ASC, created_at ASC
        """,
        (position.id,),
    ).fetchall()
    updated = position.model_copy(
        update={
            "shares": 0,
            "avg_cost_nav": 0,
            "invested_amount": 0,
            "realized_profit": 0,
            "updated_at": _now(),
        },
    )
    for row in rows:
        updated = _position_after_trade(updated, _row_to_fund_trade(row))
    return updated.model_copy(update={"updated_at": _now()})


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
        alert_enabled=bool(row["alert_enabled"]),
        alert_threshold_percent=row["alert_threshold_percent"],
        alert_buy_amount=row["alert_buy_amount"],
        alert_sell_ratio=row["alert_sell_ratio"],
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
        operation_date=date.fromisoformat(row["operation_date"])
        if row["operation_date"]
        else None,
        operation_after_cutoff=bool(row["operation_after_cutoff"]),
        note=row["note"],
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_fund_trade_record(row) -> FundTradeRecord:
    return FundTradeRecord(
        id=row["id"],
        fund_position_id=row["fund_position_id"],
        fund_code=row["fund_code"],
        name=row["name"],
        action=row["action"],
        shares=row["shares"],
        nav=row["nav"],
        amount=row["amount"],
        fee=row["fee"],
        trade_date=date.fromisoformat(row["trade_date"]),
        operation_date=date.fromisoformat(row["operation_date"])
        if row["operation_date"]
        else None,
        operation_after_cutoff=bool(row["operation_after_cutoff"]),
        note=row["note"],
        source_trade_id=row["source_trade_id"],
        is_system=bool(row["is_system"]),
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
