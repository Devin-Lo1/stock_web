from uuid import uuid4

from ..schemas import (
    BacktestCreate,
    BacktestEquityPoint,
    BacktestResult,
    BacktestRun,
    BacktestTrade,
)
from ..db.core import _connect
from ..db.converters import (
    _backtest_equity_values,
    _backtest_run_values,
    _backtest_trade_values,
    _datetime_to_text,
    _json_to_text,
    _now,
    _row_to_backtest_equity_point,
    _row_to_backtest_run,
    _row_to_backtest_trade,
)


def create_backtest_run(payload: BacktestCreate) -> BacktestRun:
    now = _now()
    run = BacktestRun(
        id=str(uuid4()),
        name=_default_run_name(payload),
        status="created",
        summary={},
        created_at=now,
        updated_at=now,
        **payload.model_dump(),
    )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO backtest_runs (
                id, name, strategy_code, stock_code, period, start_date, end_date,
                initial_cash, fee_rate, slippage_rate, parameters, status,
                summary, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _backtest_run_values(run),
        )
    return run


def list_backtest_runs(
    *,
    stock_code: str | None = None,
    strategy_code: str | None = None,
    status: str | None = None,
    limit: int = 20,
) -> list[BacktestRun]:
    clauses: list[str] = []
    parameters: list[object] = []
    if stock_code:
        clauses.append("UPPER(stock_code) = ?")
        parameters.append(stock_code.strip().upper())
    if strategy_code:
        clauses.append("strategy_code = ?")
        parameters.append(strategy_code.strip())
    if status:
        clauses.append("status = ?")
        parameters.append(status.strip())
    where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    bounded_limit = max(1, min(limit, 100))
    parameters.append(bounded_limit)
    with _connect() as connection:
        rows = connection.execute(
            f"""
            SELECT id, strategy_code, stock_code, period, start_date, end_date,
                   name, initial_cash, fee_rate, slippage_rate, parameters, status,
                   summary, created_at, updated_at
            FROM backtest_runs
            {where_sql}
            ORDER BY updated_at DESC
            LIMIT ?
            """,
            tuple(parameters),
        ).fetchall()
    return [_row_to_backtest_run(row) for row in rows]


def get_backtest_result(run_id: str) -> BacktestResult | None:
    with _connect() as connection:
        run_row = connection.execute(
            """
            SELECT id, strategy_code, stock_code, period, start_date, end_date,
                   name, initial_cash, fee_rate, slippage_rate, parameters, status,
                   summary, created_at, updated_at
            FROM backtest_runs
            WHERE id = ?
            """,
            (run_id,),
        ).fetchone()
        if run_row is None:
            return None
        equity_rows = connection.execute(
            """
            SELECT run_id, time, equity, cash, position_quantity,
                   market_value, drawdown
            FROM backtest_equity_curve
            WHERE run_id = ?
            ORDER BY time ASC
            """,
            (run_id,),
        ).fetchall()
        trade_rows = connection.execute(
            """
            SELECT run_id, time, side, price, quantity, fee, slippage,
                   cash_after, position_after
            FROM backtest_trades
            WHERE run_id = ?
            ORDER BY time ASC
            """,
            (run_id,),
        ).fetchall()
    return BacktestResult(
        run=_row_to_backtest_run(run_row),
        equity_curve=[_row_to_backtest_equity_point(row) for row in equity_rows],
        trades=[_row_to_backtest_trade(row) for row in trade_rows],
    )


def delete_backtest_run(run_id: str) -> bool:
    with _connect() as connection:
        exists = connection.execute(
            "SELECT 1 FROM backtest_runs WHERE id = ?",
            (run_id,),
        ).fetchone()
        if exists is None:
            return False
        connection.execute(
            "DELETE FROM backtest_equity_curve WHERE run_id = ?",
            (run_id,),
        )
        connection.execute(
            "DELETE FROM backtest_trades WHERE run_id = ?",
            (run_id,),
        )
        connection.execute("DELETE FROM backtest_runs WHERE id = ?", (run_id,))
    return True


def rename_backtest_run(run_id: str, name: str) -> BacktestRun | None:
    normalized_name = name.strip()[:80]
    now = _now()
    with _connect() as connection:
        existing = connection.execute(
            "SELECT 1 FROM backtest_runs WHERE id = ?",
            (run_id,),
        ).fetchone()
        if existing is None:
            return None
        connection.execute(
            """
            UPDATE backtest_runs
            SET name = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (normalized_name, _datetime_to_text(now), run_id),
        )
        row = connection.execute(
            """
            SELECT id, name, strategy_code, stock_code, period, start_date, end_date,
                   initial_cash, fee_rate, slippage_rate, parameters, status,
                   summary, created_at, updated_at
            FROM backtest_runs
            WHERE id = ?
            """,
            (run_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_backtest_run(row)


def delete_all_backtest_runs() -> int:
    with _connect() as connection:
        rows = connection.execute("SELECT id FROM backtest_runs").fetchall()
        run_count = len(rows)
        if run_count == 0:
            return 0
        connection.execute("DELETE FROM backtest_equity_curve")
        connection.execute("DELETE FROM backtest_trades")
        connection.execute("DELETE FROM backtest_runs")
    return run_count


def _default_run_name(payload: BacktestCreate) -> str:
    return (
        f"{payload.stock_code.upper()} {payload.strategy_code} "
        f"{payload.start_date.isoformat()}-{payload.end_date.isoformat()}"
    )[:80]


def save_backtest_result(
    run: BacktestRun,
    equity_curve: list[BacktestEquityPoint],
    trades: list[BacktestTrade],
) -> BacktestResult:
    with _connect() as connection:
        connection.execute(
            """
            UPDATE backtest_runs
            SET status = ?,
                summary = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                run.status,
                _json_to_text(run.summary),
                _datetime_to_text(run.updated_at),
                run.id,
            ),
        )
        connection.execute(
            "DELETE FROM backtest_equity_curve WHERE run_id = ?",
            (run.id,),
        )
        connection.execute(
            "DELETE FROM backtest_trades WHERE run_id = ?",
            (run.id,),
        )
        connection.executemany(
            """
            INSERT INTO backtest_equity_curve (
                run_id, time, equity, cash, position_quantity,
                market_value, drawdown
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [_backtest_equity_values(point) for point in equity_curve],
        )
        connection.executemany(
            """
            INSERT INTO backtest_trades (
                run_id, time, side, price, quantity, fee, slippage,
                cash_after, position_after
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [_backtest_trade_values(trade) for trade in trades],
        )
    return BacktestResult(run=run, equity_curve=equity_curve, trades=trades)
