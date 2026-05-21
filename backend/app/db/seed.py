from uuid import uuid4

from ..schemas import (
    Position,
    PositionCreate,
    QuoteSnapshot,
    SignalScanConfig,
    StrategyDefinition,
)
from ..services.signal_scan_config import default_signal_scan_configs
from .core import _DatabaseConnection
from .converters import (
    _datetime_to_text,
    _now,
    _position_values,
    _quote_values,
    _signal_scan_config_values,
    _strategy_definition_values,
)


KNOWN_STOCK_NAMES = {
    "HK.00700": "????",
    "HK.02318": "????",
    "HK.02628": "????",
    "HK.03988": "????",
    "US.AAPL": "Apple",
}


def _seed_positions(connection: _DatabaseConnection) -> None:
    for payload in [
        PositionCreate(
            market="HK",
            code="HK.00700",
            name="腾讯控股",
            quantity=100,
            cost_price=350.0,
            currency="HKD",
        ),
        PositionCreate(
            market="HK",
            code="HK.02318",
            name="中国平安",
            quantity=500,
            cost_price=42.0,
            currency="HKD",
        ),
        PositionCreate(
            market="US",
            code="US.AAPL",
            name="Apple",
            quantity=20,
            cost_price=170.0,
            currency="USD",
        ),
    ]:
        now = _now()
        position = Position(
            id=str(uuid4()),
            avg_cost_price=payload.cost_price,
            adjusted_cost_price=payload.cost_price,
            realized_profit=0,
            created_at=now,
            updated_at=now,
            **payload.model_dump(),
        )
        connection.execute(
            """
            INSERT INTO positions (
                id, market, code, name, quantity, cost_price,
                avg_cost_price, adjusted_cost_price, realized_profit, currency,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _position_values(position),
        )


def _repair_position_names(connection: _DatabaseConnection) -> None:
    rows = connection.execute(
        """
        SELECT id, code, name
        FROM positions
        """,
    ).fetchall()
    for row in rows:
        code = str(row["code"]).strip().upper()
        expected_name = KNOWN_STOCK_NAMES.get(code)
        if expected_name is None:
            continue
        current_name = str(row["name"] or "").strip()
        if not _looks_corrupted_text(current_name):
            continue
        connection.execute(
            """
            UPDATE positions
            SET name = ?, updated_at = ?
            WHERE id = ?
            """,
            (expected_name, _datetime_to_text(_now()), row["id"]),
        )


def _looks_corrupted_text(value: str) -> bool:
    if not value:
        return True
    if "\ufffd" in value:
        return True
    if "?" in value:
        return True

    latin_extended_count = 0
    for character in value:
        code_point = ord(character)
        if 0x00C0 <= code_point <= 0x024F:
            latin_extended_count += 1
    return latin_extended_count >= 2


def _seed_quotes(connection: _DatabaseConnection) -> None:
    for quote in [
        QuoteSnapshot(
            code="HK.00700",
            market="HK",
            currency="HKD",
            current_price=382.4,
            previous_close=375.0,
            open=376.2,
            high=386.0,
            low=374.8,
            volume=12000000,
            turnover=4500000000,
            turnover_rate=0.12,
            pe_ratio=18.6,
            lot_size=100,
            change=7.4,
            change_rate=1.97,
            quote_time=_now(),
        ),
        QuoteSnapshot(
            code="HK.02318",
            market="HK",
            currency="HKD",
            current_price=44.1,
            previous_close=45.2,
            open=45.0,
            high=45.4,
            low=43.8,
            volume=8000000,
            turnover=352800000,
            turnover_rate=0.08,
            pe_ratio=7.2,
            lot_size=500,
            change=-1.1,
            change_rate=-2.43,
            quote_time=_now(),
        ),
        QuoteSnapshot(
            code="US.AAPL",
            market="US",
            currency="USD",
            current_price=183.2,
            previous_close=180.5,
            open=180.1,
            high=184.0,
            low=179.5,
            volume=82000000,
            turnover=15000000000,
            turnover_rate=0.0,
            pe_ratio=28.5,
            lot_size=1,
            change=2.7,
            change_rate=1.5,
            quote_time=_now(),
        ),
    ]:
        connection.execute(
            """
            INSERT INTO quote_snapshots (
                code, market, currency, current_price, previous_close, open,
                high, low, volume, turnover, turnover_rate, pe_ratio, lot_size,
                change, change_rate, quote_time
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _quote_values(quote),
        )


def _seed_strategy_definitions(connection: _DatabaseConnection) -> None:
    for strategy in [
        StrategyDefinition(
            id=str(uuid4()),
            code="ma_cross",
            name="MA Cross",
            description="Moving average crossover baseline strategy.",
            default_parameters={
                "short_window": 5,
                "long_window": 20,
            },
            created_at=_now(),
            updated_at=_now(),
        ),
        StrategyDefinition(
            id=str(uuid4()),
            code="rsi_reversal",
            name="RSI Reversal",
            description="RSI oversold rebound and overbought pullback strategy.",
            default_parameters={
                "rsi_window": 14,
                "oversold": 30,
                "overbought": 70,
            },
            created_at=_now(),
            updated_at=_now(),
        ),
        StrategyDefinition(
            id=str(uuid4()),
            code="macd_trend",
            name="MACD Trend",
            description="MACD histogram zero-crossing trend strategy.",
            default_parameters={
                "fast_window": 12,
                "slow_window": 26,
                "signal_window": 9,
            },
            created_at=_now(),
            updated_at=_now(),
        ),
        StrategyDefinition(
            id=str(uuid4()),
            code="price_break_ma",
            name="Price Break MA",
            description="Close price break-down and recovery around a moving average.",
            default_parameters={
                "ma_window": 10,
                "direction": "both",
            },
            created_at=_now(),
            updated_at=_now(),
        ),
    ]:
        connection.execute(
            """
            INSERT INTO strategy_definitions (
                id, code, name, description, default_parameters,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(code) DO NOTHING
            """,
            _strategy_definition_values(strategy),
        )


def _seed_signal_scan_configs(connection: _DatabaseConnection) -> None:
    for config_id, payload in default_signal_scan_configs():
        config = SignalScanConfig(
            id=config_id,
            created_at=_now(),
            updated_at=_now(),
            **payload.model_dump(),
        )
        connection.execute(
            """
            INSERT INTO signal_scan_configs (
                id, strategy_code, strategy_name, parameters, enabled,
                push_candidate, sort_order, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO NOTHING
            """,
            _signal_scan_config_values(config),
        )
