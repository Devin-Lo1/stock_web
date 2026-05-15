import sqlite3
import json
from datetime import date, datetime, time, timezone
from typing import Any

from ..schemas import (
    BacktestEquityPoint,
    BacktestRun,
    BacktestTrade,
    Candle,
    Position,
    QuoteSnapshot,
    StrategyDefinition,
)


UTC = timezone.utc


def _position_values(position: Position) -> tuple[object, ...]:
    return (
        position.id,
        position.market,
        position.code,
        position.name,
        position.quantity,
        position.cost_price,
        position.currency,
        _datetime_to_text(position.created_at),
        _datetime_to_text(position.updated_at),
    )


def _quote_values(quote: QuoteSnapshot) -> tuple[object, ...]:
    return (
        quote.code,
        quote.market,
        quote.currency,
        quote.current_price,
        quote.previous_close,
        quote.open,
        quote.high,
        quote.low,
        quote.volume,
        quote.turnover,
        quote.turnover_rate,
        quote.pe_ratio,
        quote.lot_size,
        quote.change,
        quote.change_rate,
        _datetime_to_text(quote.quote_time),
    )


def _candle_values(candle: Candle, now_text: str) -> tuple[object, ...]:
    return (
        candle.code,
        candle.market,
        candle.period,
        _datetime_to_text(candle.time),
        candle.open,
        candle.high,
        candle.low,
        candle.close,
        candle.volume,
        candle.turnover,
        now_text,
        now_text,
    )


def _strategy_definition_values(
    strategy: StrategyDefinition,
) -> tuple[object, ...]:
    return (
        strategy.id,
        strategy.code,
        strategy.name,
        strategy.description,
        _json_to_text(strategy.default_parameters),
        _datetime_to_text(strategy.created_at),
        _datetime_to_text(strategy.updated_at),
    )


def _backtest_run_values(run: BacktestRun) -> tuple[object, ...]:
    return (
        run.id,
        run.strategy_code,
        run.stock_code,
        run.period,
        run.start_date.isoformat(),
        run.end_date.isoformat(),
        run.initial_cash,
        run.fee_rate,
        run.slippage_rate,
        _json_to_text(run.parameters),
        run.status,
        _json_to_text(run.summary),
        _datetime_to_text(run.created_at),
        _datetime_to_text(run.updated_at),
    )


def _backtest_equity_values(point: BacktestEquityPoint) -> tuple[object, ...]:
    return (
        point.run_id,
        _datetime_to_text(point.time),
        point.equity,
        point.cash,
        point.position_quantity,
        point.market_value,
        point.drawdown,
    )


def _backtest_trade_values(trade: BacktestTrade) -> tuple[object, ...]:
    return (
        trade.run_id,
        _datetime_to_text(trade.time),
        trade.side,
        trade.price,
        trade.quantity,
        trade.fee,
        trade.slippage,
        trade.cash_after,
        trade.position_after,
    )


def _row_to_position(row: sqlite3.Row | dict[str, Any]) -> Position:
    return Position(
        id=row["id"],
        market=row["market"],
        code=row["code"],
        name=row["name"],
        quantity=row["quantity"],
        cost_price=row["cost_price"],
        currency=row["currency"],
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_quote(row: sqlite3.Row | dict[str, Any]) -> QuoteSnapshot:
    return QuoteSnapshot(
        code=row["code"],
        market=row["market"],
        currency=row["currency"],
        current_price=row["current_price"],
        previous_close=row["previous_close"],
        open=row["open"],
        high=row["high"],
        low=row["low"],
        volume=row["volume"],
        turnover=row["turnover"],
        turnover_rate=row["turnover_rate"],
        pe_ratio=row["pe_ratio"],
        lot_size=row["lot_size"],
        change=row["change"],
        change_rate=row["change_rate"],
        quote_time=_text_to_datetime(row["quote_time"]),
    )


def _row_to_candle(row: sqlite3.Row | dict[str, Any]) -> Candle:
    return Candle(
        code=row["code"],
        market=row["market"],
        period=row["period"],
        time=_text_to_datetime(row["time"]),
        open=row["open"],
        high=row["high"],
        low=row["low"],
        close=row["close"],
        volume=row["volume"],
        turnover=row["turnover"],
    )


def _row_to_strategy_definition(
    row: sqlite3.Row | dict[str, Any],
) -> StrategyDefinition:
    return StrategyDefinition(
        id=row["id"],
        code=row["code"],
        name=row["name"],
        description=row["description"],
        default_parameters=_json_from_text(row["default_parameters"]),
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_backtest_run(row: sqlite3.Row | dict[str, Any]) -> BacktestRun:
    return BacktestRun(
        id=row["id"],
        strategy_code=row["strategy_code"],
        stock_code=row["stock_code"],
        period=row["period"],
        start_date=row["start_date"],
        end_date=row["end_date"],
        initial_cash=row["initial_cash"],
        fee_rate=row["fee_rate"],
        slippage_rate=row["slippage_rate"],
        parameters=_json_from_text(row["parameters"]),
        status=row["status"],
        summary=_json_from_text(row["summary"]),
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_backtest_equity_point(
    row: sqlite3.Row | dict[str, Any],
) -> BacktestEquityPoint:
    return BacktestEquityPoint(
        run_id=row["run_id"],
        time=_text_to_datetime(row["time"]),
        equity=row["equity"],
        cash=row["cash"],
        position_quantity=row["position_quantity"],
        market_value=row["market_value"],
        drawdown=row["drawdown"],
    )


def _row_to_backtest_trade(row: sqlite3.Row | dict[str, Any]) -> BacktestTrade:
    return BacktestTrade(
        run_id=row["run_id"],
        time=_text_to_datetime(row["time"]),
        side=row["side"],
        price=row["price"],
        quantity=row["quantity"],
        fee=row["fee"],
        slippage=row["slippage"],
        cash_after=row["cash_after"],
        position_after=row["position_after"],
    )

def _now() -> datetime:
    return datetime.now(UTC)


def _datetime_to_text(value: datetime) -> str:
    return value.astimezone(UTC).isoformat()


def _text_to_datetime(value: str | datetime) -> datetime:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)
    return datetime.fromisoformat(value)


def _json_to_text(value: dict[str, Any]) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def _json_from_text(value: str | dict[str, Any]) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    return json.loads(value)
