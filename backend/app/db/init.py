from .core import DATABASE_PATH, _connect, _ensure_column, _first_column, _uses_postgres
from .seed import _repair_position_names, _seed_positions, _seed_quotes, _seed_strategy_definitions


def init_database(*, seed_defaults: bool = True) -> None:
    if not _uses_postgres():
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
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS strategy_definitions (
                id TEXT PRIMARY KEY,
                code TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                description TEXT NOT NULL,
                default_parameters TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS strategy_parameters (
                id TEXT PRIMARY KEY,
                strategy_code TEXT NOT NULL,
                name TEXT NOT NULL,
                value_type TEXT NOT NULL,
                default_value TEXT NOT NULL,
                min_value REAL,
                max_value REAL,
                description TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS backtest_runs (
                id TEXT PRIMARY KEY,
                strategy_code TEXT NOT NULL,
                stock_code TEXT NOT NULL,
                period TEXT NOT NULL,
                start_date TEXT NOT NULL,
                end_date TEXT NOT NULL,
                initial_cash REAL NOT NULL,
                fee_rate REAL NOT NULL,
                slippage_rate REAL NOT NULL,
                parameters TEXT NOT NULL,
                status TEXT NOT NULL,
                summary TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS backtest_equity_curve (
                run_id TEXT NOT NULL,
                time TEXT NOT NULL,
                equity REAL NOT NULL,
                cash REAL NOT NULL,
                position_quantity REAL NOT NULL,
                market_value REAL NOT NULL,
                drawdown REAL NOT NULL,
                PRIMARY KEY (run_id, time)
            )
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS backtest_trades (
                run_id TEXT NOT NULL,
                time TEXT NOT NULL,
                side TEXT NOT NULL,
                price REAL NOT NULL,
                quantity REAL NOT NULL,
                fee REAL NOT NULL,
                slippage REAL NOT NULL,
                cash_after REAL NOT NULL,
                position_after REAL NOT NULL,
                PRIMARY KEY (run_id, time, side)
            )
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS strategy_signals (
                id TEXT PRIMARY KEY,
                strategy_code TEXT NOT NULL,
                stock_code TEXT NOT NULL,
                signal_type TEXT NOT NULL,
                signal_time TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """,
        )
        count = _first_column(connection.execute("SELECT COUNT(*) FROM positions").fetchone())
        if count == 0 and seed_defaults:
            _seed_positions(connection)
        _repair_position_names(connection)
        quote_count = connection.execute(
            "SELECT COUNT(*) FROM quote_snapshots",
        ).fetchone()
        quote_count = _first_column(quote_count)
        if quote_count == 0 and seed_defaults:
            _seed_quotes(connection)
        strategy_count = connection.execute(
            "SELECT COUNT(*) FROM strategy_definitions",
        ).fetchone()
        strategy_count = _first_column(strategy_count)
        if strategy_count == 0 and seed_defaults:
            _seed_strategy_definitions(connection)
