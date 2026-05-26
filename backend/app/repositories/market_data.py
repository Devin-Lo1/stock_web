from datetime import date, datetime, time

from ..schemas import Candle, QuoteSnapshot
from ..db.core import _connect
from ..db.converters import (
    UTC,
    _candle_values,
    _datetime_to_text,
    _now,
    _quote_values,
    _row_to_candle,
    _row_to_quote,
)


def get_quotes(codes: list[str]) -> list[QuoteSnapshot]:
    normalized_codes = [code.strip().upper() for code in codes if code.strip()]
    with _connect() as connection:
        if normalized_codes:
            placeholders = ",".join("?" for _ in normalized_codes)
            rows = connection.execute(
                f"""
                SELECT code, market, currency, current_price, previous_close,
                       open, high, low, volume, turnover, turnover_rate,
                       pe_ratio, lot_size, change, change_rate, quote_time,
                       extended_session, extended_price, extended_change,
                       extended_change_rate, extended_volume, extended_turnover
                FROM quote_snapshots
                WHERE UPPER(code) IN ({placeholders})
                ORDER BY code ASC
                """,
                normalized_codes,
            ).fetchall()
        else:
            rows = connection.execute(
                """
                SELECT code, market, currency, current_price, previous_close,
                       open, high, low, volume, turnover, turnover_rate,
                       pe_ratio, lot_size, change, change_rate, quote_time,
                       extended_session, extended_price, extended_change,
                       extended_change_rate, extended_volume, extended_turnover
                FROM quote_snapshots
                ORDER BY code ASC
                """,
            ).fetchall()
    return [_row_to_quote(row) for row in rows]


def upsert_quote(quote: QuoteSnapshot) -> QuoteSnapshot:
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO quote_snapshots (
                code, market, currency, current_price, previous_close, open,
                high, low, volume, turnover, turnover_rate, pe_ratio, lot_size,
                change, change_rate, quote_time, extended_session,
                extended_price, extended_change, extended_change_rate,
                extended_volume, extended_turnover
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(code) DO UPDATE SET
                market = excluded.market,
                currency = excluded.currency,
                current_price = excluded.current_price,
                previous_close = excluded.previous_close,
                open = excluded.open,
                high = excluded.high,
                low = excluded.low,
                volume = excluded.volume,
                turnover = excluded.turnover,
                turnover_rate = excluded.turnover_rate,
                pe_ratio = excluded.pe_ratio,
                lot_size = excluded.lot_size,
                change = excluded.change,
                change_rate = excluded.change_rate,
                quote_time = excluded.quote_time,
                extended_session = excluded.extended_session,
                extended_price = excluded.extended_price,
                extended_change = excluded.extended_change,
                extended_change_rate = excluded.extended_change_rate,
                extended_volume = excluded.extended_volume,
                extended_turnover = excluded.extended_turnover
            """,
            _quote_values(quote),
        )
    return quote


def list_candles(code: str, period: str, limit: int) -> list[Candle]:
    normalized_code = code.strip().upper()
    normalized_period = period.strip().lower()
    bounded_limit = max(1, min(limit, 1000))
    with _connect() as connection:
        rows = connection.execute(
            """
            SELECT code, market, period, time, open, high, low, close, volume, turnover
            FROM (
                SELECT code, market, period, time, open, high, low, close, volume, turnover
                FROM klines
                WHERE UPPER(code) = ? AND period = ?
                ORDER BY time DESC
                LIMIT ?
            ) latest_candles
            ORDER BY time ASC
            """,
            (normalized_code, normalized_period, bounded_limit),
        ).fetchall()
    return [_row_to_candle(row) for row in rows]


def list_candles_between(
    code: str,
    period: str,
    start_date: date,
    end_date: date,
) -> list[Candle]:
    normalized_code = code.strip().upper()
    normalized_period = period.strip().lower()
    start_text = _datetime_to_text(datetime.combine(start_date, time.min, UTC))
    end_text = _datetime_to_text(datetime.combine(end_date, time.max, UTC))
    with _connect() as connection:
        rows = connection.execute(
            """
            SELECT code, market, period, time, open, high, low, close, volume, turnover
            FROM klines
            WHERE UPPER(code) = ?
              AND period = ?
              AND time >= ?
              AND time <= ?
            ORDER BY time ASC
            """,
            (normalized_code, normalized_period, start_text, end_text),
        ).fetchall()
    return [_row_to_candle(row) for row in rows]


def upsert_candles(candles: list[Candle]) -> list[Candle]:
    if not candles:
        return []

    now_text = _datetime_to_text(_now())
    with _connect() as connection:
        connection.executemany(
            """
            INSERT INTO klines (
                code, market, period, time, open, high, low, close, volume, turnover,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(code, period, time) DO UPDATE SET
                market = excluded.market,
                open = excluded.open,
                high = excluded.high,
                low = excluded.low,
                close = excluded.close,
                volume = excluded.volume,
                turnover = excluded.turnover,
                updated_at = excluded.updated_at
            """,
            [_candle_values(candle, now_text) for candle in candles],
        )
    return candles
