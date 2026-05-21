import sqlite3
import json
from datetime import date, datetime, time, timezone
from typing import Any

from ..schemas import (
    BacktestEquityPoint,
    BacktestRun,
    BacktestTrade,
    Candle,
    NotificationDevice,
    Position,
    PositionTrade,
    PushRecord,
    QuoteSnapshot,
    SignalEvent,
    SignalScanConfig,
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
        position.avg_cost_price,
        position.adjusted_cost_price,
        position.realized_profit,
        position.currency,
        _datetime_to_text(position.created_at),
        _datetime_to_text(position.updated_at),
    )


def _position_trade_values(trade: PositionTrade) -> tuple[object, ...]:
    return (
        trade.id,
        trade.position_id,
        trade.market,
        trade.code,
        trade.name,
        trade.currency,
        trade.action,
        trade.quantity,
        trade.price,
        trade.fee,
        _datetime_to_text(trade.trade_time),
        trade.note,
        _datetime_to_text(trade.created_at),
        _datetime_to_text(trade.updated_at),
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


def _signal_scan_config_values(config: SignalScanConfig) -> tuple[object, ...]:
    return (
        config.id,
        config.strategy_code,
        config.strategy_name,
        _json_to_text(config.parameters),
        _bool_to_int(config.enabled),
        _bool_to_int(config.push_candidate),
        config.sort_order,
        _datetime_to_text(config.created_at),
        _datetime_to_text(config.updated_at),
    )


def _backtest_run_values(run: BacktestRun) -> tuple[object, ...]:
    return (
        run.id,
        run.name,
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


def _signal_event_values(event: SignalEvent) -> tuple[object, ...]:
    return (
        event.id,
        event.source,
        event.code,
        event.signal_type,
        event.level,
        event.title,
        event.message,
        event.trigger_value,
        event.threshold_value,
        event.dedupe_key,
        _json_to_text(event.payload),
        event.read_status,
        _optional_datetime_to_text(event.read_at),
        _datetime_to_text(event.triggered_at),
        _datetime_to_text(event.created_at),
        _datetime_to_text(event.updated_at),
    )


def _notification_device_values(device: NotificationDevice) -> tuple[object, ...]:
    return (
        device.id,
        device.platform,
        device.push_provider,
        device.push_token,
        device.device_name,
        device.app_version,
        _bool_to_int(device.enabled),
        _bool_to_int(device.important_enabled),
        _datetime_to_text(device.last_seen_at),
        _datetime_to_text(device.created_at),
        _datetime_to_text(device.updated_at),
    )


def _push_record_values(record: PushRecord) -> tuple[object, ...]:
    return (
        record.id,
        record.signal_event_id,
        record.device_id,
        record.provider,
        record.status,
        _json_to_text(record.request_payload),
        _json_to_text(record.response_payload),
        record.error_message,
        record.attempt_count,
        _optional_datetime_to_text(record.sent_at),
        _datetime_to_text(record.created_at),
        _datetime_to_text(record.updated_at),
    )


def _row_to_position(row: sqlite3.Row | dict[str, Any]) -> Position:
    return Position(
        id=row["id"],
        market=row["market"],
        code=row["code"],
        name=row["name"],
        quantity=row["quantity"],
        cost_price=row["cost_price"],
        avg_cost_price=_position_metric(row, "avg_cost_price", row["cost_price"]),
        adjusted_cost_price=_position_metric(
            row,
            "adjusted_cost_price",
            row["cost_price"],
        ),
        realized_profit=_position_metric(row, "realized_profit", 0),
        currency=row["currency"],
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_position_trade(row: sqlite3.Row | dict[str, Any]) -> PositionTrade:
    return PositionTrade(
        id=row["id"],
        position_id=row["position_id"],
        market=row["market"],
        code=row["code"],
        name=row["name"],
        currency=row["currency"],
        action=row["action"],
        quantity=row["quantity"],
        price=row["price"],
        fee=row["fee"],
        trade_time=_text_to_datetime(row["trade_time"]),
        note=row["note"],
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


def _row_to_signal_scan_config(
    row: sqlite3.Row | dict[str, Any],
) -> SignalScanConfig:
    return SignalScanConfig(
        id=row["id"],
        strategy_code=row["strategy_code"],
        strategy_name=row["strategy_name"],
        parameters=_json_from_text(row["parameters"]),
        enabled=_int_to_bool(row["enabled"]),
        push_candidate=_int_to_bool(row["push_candidate"]),
        sort_order=row["sort_order"],
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_backtest_run(row: sqlite3.Row | dict[str, Any]) -> BacktestRun:
    return BacktestRun(
        id=row["id"],
        name=row["name"] if "name" in row.keys() else "",
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


def _row_to_signal_event(row: sqlite3.Row | dict[str, Any]) -> SignalEvent:
    return SignalEvent(
        id=row["id"],
        source=row["source"],
        code=row["code"],
        signal_type=row["signal_type"],
        level=row["level"],
        title=row["title"],
        message=row["message"],
        trigger_value=row["trigger_value"],
        threshold_value=row["threshold_value"],
        dedupe_key=row["dedupe_key"],
        payload=_json_from_text(row["payload"]),
        read_status=row["read_status"],
        read_at=_optional_text_to_datetime(row["read_at"]),
        triggered_at=_text_to_datetime(row["triggered_at"]),
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_notification_device(
    row: sqlite3.Row | dict[str, Any],
) -> NotificationDevice:
    return NotificationDevice(
        id=row["id"],
        platform=row["platform"],
        push_provider=row["push_provider"],
        push_token=row["push_token"],
        device_name=row["device_name"],
        app_version=row["app_version"],
        enabled=_int_to_bool(row["enabled"]),
        important_enabled=_int_to_bool(row["important_enabled"]),
        last_seen_at=_text_to_datetime(row["last_seen_at"]),
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _row_to_push_record(row: sqlite3.Row | dict[str, Any]) -> PushRecord:
    return PushRecord(
        id=row["id"],
        signal_event_id=row["signal_event_id"],
        device_id=row["device_id"],
        provider=row["provider"],
        status=row["status"],
        request_payload=_json_from_text(row["request_payload"]),
        response_payload=_json_from_text(row["response_payload"]),
        error_message=row["error_message"],
        attempt_count=row["attempt_count"],
        sent_at=_optional_text_to_datetime(row["sent_at"]),
        created_at=_text_to_datetime(row["created_at"]),
        updated_at=_text_to_datetime(row["updated_at"]),
    )


def _now() -> datetime:
    return datetime.now(UTC)


def _datetime_to_text(value: datetime) -> str:
    return value.astimezone(UTC).isoformat()


def _optional_datetime_to_text(value: datetime | None) -> str | None:
    if value is None:
        return None
    return _datetime_to_text(value)


def _text_to_datetime(value: str | datetime) -> datetime:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)
    return datetime.fromisoformat(value)


def _optional_text_to_datetime(value: str | datetime | None) -> datetime | None:
    if value is None:
        return None
    return _text_to_datetime(value)


def _bool_to_int(value: bool) -> int:
    return 1 if value else 0


def _int_to_bool(value: bool | int) -> bool:
    return bool(value)


def _json_to_text(value: dict[str, Any]) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def _json_from_text(value: str | dict[str, Any]) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    return json.loads(value)


def _position_metric(
    row: sqlite3.Row | dict[str, Any],
    key: str,
    default: float,
) -> float:
    if key not in row.keys():
        return float(default)
    value = row[key]
    if value is None:
        return float(default)
    return float(value)
