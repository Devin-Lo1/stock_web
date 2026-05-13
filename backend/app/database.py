import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from .schemas import Candle, Position, PositionCreate, PositionUpdate, QuoteSnapshot


DATABASE_PATH = Path(__file__).resolve().parents[1] / "data" / "stock_mvp.sqlite3"
UTC = timezone.utc

KNOWN_STOCK_NAMES = {
    "HK.00700": "腾讯控股",
    "HK.02318": "中国平安",
    "HK.02628": "中国人寿",
    "HK.03988": "中国银行",
    "US.AAPL": "Apple",
}


def init_database() -> None:
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with _connect() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS positions (
                id TEXT PRIMARY KEY,
                market TEXT NOT NULL,
                code TEXT NOT NULL,
                name TEXT NOT NULL,
                quantity REAL NOT NULL,
                cost_price REAL NOT NULL,
                currency TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS quote_snapshots (
                code TEXT PRIMARY KEY,
                market TEXT NOT NULL,
                currency TEXT NOT NULL,
                current_price REAL NOT NULL,
                previous_close REAL NOT NULL,
                open REAL NOT NULL,
                high REAL NOT NULL,
                low REAL NOT NULL,
                volume REAL NOT NULL,
                turnover REAL NOT NULL,
                turnover_rate REAL NOT NULL DEFAULT 0,
                pe_ratio REAL NOT NULL DEFAULT 0,
                lot_size REAL NOT NULL DEFAULT 0,
                change REAL NOT NULL,
                change_rate REAL NOT NULL,
                quote_time TEXT NOT NULL
            )
            """,
        )
        _ensure_column(connection, "quote_snapshots", "turnover_rate", "REAL NOT NULL DEFAULT 0")
        _ensure_column(connection, "quote_snapshots", "pe_ratio", "REAL NOT NULL DEFAULT 0")
        _ensure_column(connection, "quote_snapshots", "lot_size", "REAL NOT NULL DEFAULT 0")
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS klines (
                code TEXT NOT NULL,
                market TEXT NOT NULL,
                period TEXT NOT NULL,
                time TEXT NOT NULL,
                open REAL NOT NULL,
                high REAL NOT NULL,
                low REAL NOT NULL,
                close REAL NOT NULL,
                volume REAL NOT NULL,
                turnover REAL NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (code, period, time)
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_klines_code_period_time
            ON klines (code, period, time DESC)
            """,
        )
        count = connection.execute("SELECT COUNT(*) FROM positions").fetchone()[0]
        if count == 0:
            _seed_positions(connection)
        _repair_position_names(connection)
        quote_count = connection.execute(
            "SELECT COUNT(*) FROM quote_snapshots",
        ).fetchone()[0]
        if quote_count == 0:
            _seed_quotes(connection)


def list_positions() -> list[Position]:
    with _connect() as connection:
        rows = connection.execute(
            """
            SELECT id, market, code, name, quantity, cost_price, currency,
                   created_at, updated_at
            FROM positions
            ORDER BY created_at ASC
            """,
        ).fetchall()
    return [_row_to_position(row) for row in rows]


def create_position(payload: PositionCreate) -> Position:
    now = _now()
    position = Position(
        id=str(uuid4()),
        created_at=now,
        updated_at=now,
        **payload.model_dump(),
    )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO positions (
                id, market, code, name, quantity, cost_price, currency,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _position_values(position),
        )
    return position


def update_position(position_id: str, payload: PositionUpdate) -> Position | None:
    current = get_position(position_id)
    if current is None:
        return None

    update_data = payload.model_dump(exclude_unset=True)
    updated = current.model_copy(
        update={
            **update_data,
            "updated_at": _now(),
        },
    )
    with _connect() as connection:
        connection.execute(
            """
            UPDATE positions
            SET market = ?,
                code = ?,
                name = ?,
                quantity = ?,
                cost_price = ?,
                currency = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                updated.market,
                updated.code,
                updated.name,
                updated.quantity,
                updated.cost_price,
                updated.currency,
                _datetime_to_text(updated.updated_at),
                updated.id,
            ),
        )
    return updated


def delete_position(position_id: str) -> bool:
    with _connect() as connection:
        cursor = connection.execute(
            "DELETE FROM positions WHERE id = ?",
            (position_id,),
        )
    return cursor.rowcount > 0


def get_position(position_id: str) -> Position | None:
    with _connect() as connection:
        row = connection.execute(
            """
            SELECT id, market, code, name, quantity, cost_price, currency,
                   created_at, updated_at
            FROM positions
            WHERE id = ?
            """,
            (position_id,),
        ).fetchone()
    if row is None:
        return None
    return _row_to_position(row)


def get_quotes(codes: list[str]) -> list[QuoteSnapshot]:
    normalized_codes = [code.strip().upper() for code in codes if code.strip()]
    with _connect() as connection:
        if normalized_codes:
            placeholders = ",".join("?" for _ in normalized_codes)
            rows = connection.execute(
                f"""
                SELECT code, market, currency, current_price, previous_close,
                       open, high, low, volume, turnover, turnover_rate,
                       pe_ratio, lot_size, change, change_rate, quote_time
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
                       pe_ratio, lot_size, change, change_rate, quote_time
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
                change, change_rate, quote_time
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                quote_time = excluded.quote_time
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
            )
            ORDER BY time ASC
            """,
            (normalized_code, normalized_period, bounded_limit),
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


@contextmanager
def _connect() -> Iterator[sqlite3.Connection]:
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    try:
        yield connection
        connection.commit()
    finally:
        connection.close()


def _seed_positions(connection: sqlite3.Connection) -> None:
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
            created_at=now,
            updated_at=now,
            **payload.model_dump(),
        )
        connection.execute(
            """
            INSERT INTO positions (
                id, market, code, name, quantity, cost_price, currency,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            _position_values(position),
        )


def _repair_position_names(connection: sqlite3.Connection) -> None:
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


def _seed_quotes(connection: sqlite3.Connection) -> None:
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


def _row_to_position(row: sqlite3.Row) -> Position:
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


def _row_to_quote(row: sqlite3.Row) -> QuoteSnapshot:
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


def _row_to_candle(row: sqlite3.Row) -> Candle:
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


def _ensure_column(
    connection: sqlite3.Connection,
    table_name: str,
    column_name: str,
    column_definition: str,
) -> None:
    columns = {
        row["name"]
        for row in connection.execute(f"PRAGMA table_info({table_name})").fetchall()
    }
    if column_name in columns:
        return
    connection.execute(
        f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}",
    )


def _now() -> datetime:
    return datetime.now(UTC)


def _datetime_to_text(value: datetime) -> str:
    return value.astimezone(UTC).isoformat()


def _text_to_datetime(value: str) -> datetime:
    return datetime.fromisoformat(value)
