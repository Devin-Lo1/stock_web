from .core import DATABASE_PATH, _connect, _ensure_column, _first_column, _uses_postgres
from .seed import (
    _repair_position_names,
    _seed_positions,
    _seed_quotes,
    _seed_signal_scan_configs,
    _seed_strategy_definitions,
)


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
                avg_cost_price REAL NOT NULL DEFAULT 0,
                adjusted_cost_price REAL NOT NULL DEFAULT 0,
                realized_profit REAL NOT NULL DEFAULT 0,
                currency TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        _ensure_column(connection, "positions", "avg_cost_price", "REAL NOT NULL DEFAULT 0")
        _ensure_column(
            connection,
            "positions",
            "adjusted_cost_price",
            "REAL NOT NULL DEFAULT 0",
        )
        _ensure_column(connection, "positions", "realized_profit", "REAL NOT NULL DEFAULT 0")
        connection.execute(
            """
            UPDATE positions
            SET avg_cost_price = cost_price
            WHERE quantity > 0 AND avg_cost_price = 0 AND cost_price != 0
            """,
        )
        connection.execute(
            """
            UPDATE positions
            SET adjusted_cost_price = cost_price
            WHERE quantity > 0 AND adjusted_cost_price = 0 AND cost_price != 0
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS position_trades (
                id TEXT PRIMARY KEY,
                position_id TEXT NOT NULL,
                market TEXT NOT NULL,
                code TEXT NOT NULL,
                name TEXT NOT NULL,
                currency TEXT NOT NULL,
                action TEXT NOT NULL,
                quantity REAL NOT NULL,
                price REAL NOT NULL,
                fee REAL NOT NULL,
                trade_time TEXT NOT NULL,
                note TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_position_trades_position_time
            ON position_trades (position_id, trade_time DESC)
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_position_trades_code_time
            ON position_trades (code, trade_time DESC)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS position_snapshots (
                id TEXT PRIMARY KEY,
                position_id TEXT NOT NULL,
                market TEXT NOT NULL,
                code TEXT NOT NULL,
                name TEXT NOT NULL,
                currency TEXT NOT NULL,
                quantity REAL NOT NULL,
                avg_cost_price REAL NOT NULL,
                adjusted_cost_price REAL NOT NULL,
                realized_profit REAL NOT NULL,
                current_price REAL NOT NULL,
                previous_close REAL NOT NULL,
                market_value REAL NOT NULL,
                day_profit REAL NOT NULL,
                day_profit_rate REAL NOT NULL,
                holding_profit REAL NOT NULL,
                holding_profit_rate REAL NOT NULL,
                total_profit REAL NOT NULL,
                total_profit_rate REAL NOT NULL,
                position_weight REAL NOT NULL,
                snapshot_time TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_position_snapshots_position_time
            ON position_snapshots (position_id, snapshot_time DESC)
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_position_snapshots_code_time
            ON position_snapshots (code, snapshot_time DESC)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS fund_positions (
                id TEXT PRIMARY KEY,
                fund_code TEXT NOT NULL,
                name TEXT NOT NULL,
                fund_type TEXT NOT NULL,
                shares REAL NOT NULL,
                avg_cost_nav REAL NOT NULL,
                invested_amount REAL NOT NULL,
                realized_profit REAL NOT NULL,
                currency TEXT NOT NULL,
                alert_enabled INTEGER NOT NULL DEFAULT 1,
                alert_threshold_percent REAL NOT NULL DEFAULT 5,
                alert_buy_amount REAL NOT NULL DEFAULT 5000,
                alert_sell_ratio REAL NOT NULL DEFAULT 0.25,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        _ensure_column(connection, "fund_positions", "alert_enabled", "INTEGER NOT NULL DEFAULT 1")
        _ensure_column(
            connection,
            "fund_positions",
            "alert_threshold_percent",
            "REAL NOT NULL DEFAULT 5",
        )
        _ensure_column(
            connection,
            "fund_positions",
            "alert_buy_amount",
            "REAL NOT NULL DEFAULT 5000",
        )
        _ensure_column(
            connection,
            "fund_positions",
            "alert_sell_ratio",
            "REAL NOT NULL DEFAULT 0.25",
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_fund_positions_code
            ON fund_positions (fund_code)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS fund_trades (
                id TEXT PRIMARY KEY,
                fund_position_id TEXT NOT NULL,
                fund_code TEXT NOT NULL,
                name TEXT NOT NULL,
                action TEXT NOT NULL,
                shares REAL NOT NULL,
                nav REAL NOT NULL,
                fee REAL NOT NULL,
                trade_date TEXT NOT NULL,
                note TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_fund_trades_position_date
            ON fund_trades (fund_position_id, trade_date DESC)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS fund_navs (
                fund_code TEXT NOT NULL,
                nav_date TEXT NOT NULL,
                unit_nav REAL NOT NULL,
                accumulated_nav REAL NOT NULL,
                daily_growth_rate REAL NOT NULL,
                subscribe_status TEXT NOT NULL,
                redeem_status TEXT NOT NULL,
                source TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (fund_code, nav_date)
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_fund_navs_code_date
            ON fund_navs (fund_code, nav_date DESC)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS fund_alert_scheduler (
                id TEXT PRIMARY KEY,
                enabled INTEGER NOT NULL,
                reminder_times TEXT NOT NULL,
                due_window_minutes INTEGER NOT NULL,
                last_scan_at TEXT,
                last_scan_key TEXT NOT NULL,
                last_error TEXT NOT NULL,
                last_result TEXT NOT NULL,
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
                name TEXT NOT NULL DEFAULT '',
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
            CREATE TABLE IF NOT EXISTS signal_scan_configs (
                id TEXT PRIMARY KEY,
                strategy_code TEXT NOT NULL,
                strategy_name TEXT NOT NULL,
                parameters TEXT NOT NULL,
                enabled INTEGER NOT NULL,
                push_candidate INTEGER NOT NULL,
                sort_order INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_signal_scan_configs_enabled_order
            ON signal_scan_configs (enabled, sort_order)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS strategy_monitors (
                id TEXT PRIMARY KEY,
                position_id TEXT,
                market TEXT NOT NULL,
                code TEXT NOT NULL,
                name TEXT NOT NULL,
                strategy_code TEXT NOT NULL,
                strategy_name TEXT NOT NULL,
                parameters TEXT NOT NULL,
                period TEXT NOT NULL,
                scan_interval_minutes INTEGER NOT NULL,
                cooldown_minutes INTEGER NOT NULL,
                enabled INTEGER NOT NULL,
                push_candidate INTEGER NOT NULL,
                source_backtest_run_id TEXT,
                last_scanned_at TEXT,
                last_triggered_at TEXT,
                last_signal_event_id TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_strategy_monitors_enabled_code
            ON strategy_monitors (enabled, code)
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_strategy_monitors_position
            ON strategy_monitors (position_id)
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_strategy_monitors_strategy
            ON strategy_monitors (strategy_code)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS strategy_monitor_scan_logs (
                id TEXT PRIMARY KEY,
                monitor_id TEXT NOT NULL,
                code TEXT NOT NULL,
                strategy_code TEXT NOT NULL,
                stage TEXT NOT NULL,
                status TEXT NOT NULL,
                message TEXT NOT NULL,
                detail TEXT NOT NULL,
                scanned_at TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_strategy_monitor_scan_logs_monitor_time
            ON strategy_monitor_scan_logs (monitor_id, scanned_at DESC)
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_strategy_monitor_scan_logs_code_time
            ON strategy_monitor_scan_logs (code, scanned_at DESC)
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_strategy_monitor_scan_logs_status_time
            ON strategy_monitor_scan_logs (status, scanned_at DESC)
            """,
        )
        _ensure_column(connection, "backtest_runs", "name", "TEXT NOT NULL DEFAULT ''")
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
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS signal_events (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                code TEXT NOT NULL,
                signal_type TEXT NOT NULL,
                level TEXT NOT NULL,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                trigger_value REAL,
                threshold_value REAL,
                dedupe_key TEXT NOT NULL,
                payload TEXT NOT NULL,
                read_status TEXT NOT NULL,
                read_at TEXT,
                triggered_at TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_signal_events_dedupe_time
            ON signal_events (dedupe_key, triggered_at DESC)
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_signal_events_code_time
            ON signal_events (code, triggered_at DESC)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS notification_devices (
                id TEXT PRIMARY KEY,
                platform TEXT NOT NULL,
                push_provider TEXT NOT NULL,
                push_token TEXT NOT NULL,
                device_name TEXT NOT NULL,
                app_version TEXT NOT NULL,
                enabled INTEGER NOT NULL,
                important_enabled INTEGER NOT NULL,
                last_seen_at TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_devices_provider_token
            ON notification_devices (push_provider, push_token)
            """,
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS push_records (
                id TEXT PRIMARY KEY,
                signal_event_id TEXT,
                device_id TEXT NOT NULL,
                provider TEXT NOT NULL,
                status TEXT NOT NULL,
                request_payload TEXT NOT NULL,
                response_payload TEXT NOT NULL,
                error_message TEXT NOT NULL,
                attempt_count INTEGER NOT NULL,
                sent_at TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_push_records_signal_event
            ON push_records (signal_event_id)
            """,
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_push_records_device_status
            ON push_records (device_id, status)
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
        if seed_defaults:
            _seed_strategy_definitions(connection)
            scan_config_count = _first_column(
                connection.execute("SELECT COUNT(*) FROM signal_scan_configs").fetchone(),
            )
            if scan_config_count == 0:
                _seed_signal_scan_configs(connection)
