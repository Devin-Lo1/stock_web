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
                id, strategy_code, stock_code, period, start_date, end_date,
                initial_cash, fee_rate, slippage_rate, parameters, status,
                summary, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _backtest_run_values(run),
        )
    return run


def get_backtest_result(run_id: str) -> BacktestResult | None:
    with _connect() as connection:
        run_row = connection.execute(
            """
            SELECT id, strategy_code, stock_code, period, start_date, end_date,
                   initial_cash, fee_rate, slippage_rate, parameters, status,
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
