import os

import pytest


TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql://stock_web:stock_web_dev_2026@127.0.0.1:5432/stock_web_test",
)
os.environ["DATABASE_URL"] = TEST_DATABASE_URL

from app import database  # noqa: E402


TABLES = (
    "push_records",
    "notification_devices",
    "signal_events",
    "signal_scan_configs",
    "strategy_signals",
    "backtest_trades",
    "backtest_equity_curve",
    "backtest_runs",
    "strategy_parameters",
    "strategy_definitions",
    "klines",
    "quote_snapshots",
    "position_trades",
    "positions",
)


@pytest.fixture(autouse=True)
def clean_database():
    database.init_database(seed_defaults=False)
    _clear_tables()
    yield
    _clear_tables()


def _clear_tables() -> None:
    with database._connect() as connection:
        for table_name in TABLES:
            connection.execute(f"DELETE FROM {table_name}")
