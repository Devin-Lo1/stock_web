from .db.core import _connect
from .db.init import init_database
from .repositories.backtests import (
    create_backtest_run,
    delete_all_backtest_runs,
    delete_backtest_run,
    get_backtest_result,
    list_backtest_runs,
    rename_backtest_run,
    save_backtest_result,
)
from .repositories.market_data import (
    get_quotes,
    list_candles,
    list_candles_between,
    upsert_candles,
    upsert_quote,
)
from .repositories.notifications import (
    create_push_record,
    create_signal_event,
    get_notification_device_by_token,
    list_notification_devices,
    list_push_records,
    list_signal_events,
    mark_signal_event_ignored,
    mark_signal_event_read,
    upsert_notification_device,
)
from .repositories.positions import (
    create_position,
    delete_position,
    get_position,
    list_positions,
    update_position,
)
from .repositories.signal_scan_configs import (
    create_signal_scan_config,
    list_signal_scan_configs,
    update_signal_scan_config,
)
from .repositories.strategies import (
    create_strategy_definition,
    list_strategy_definitions,
)

__all__ = [
    "_connect",
    "init_database",
    "list_positions",
    "create_position",
    "update_position",
    "delete_position",
    "get_position",
    "get_quotes",
    "upsert_quote",
    "list_candles",
    "list_candles_between",
    "upsert_candles",
    "list_strategy_definitions",
    "create_strategy_definition",
    "create_backtest_run",
    "list_backtest_runs",
    "get_backtest_result",
    "delete_all_backtest_runs",
    "delete_backtest_run",
    "rename_backtest_run",
    "save_backtest_result",
    "create_signal_event",
    "list_signal_events",
    "mark_signal_event_read",
    "mark_signal_event_ignored",
    "upsert_notification_device",
    "get_notification_device_by_token",
    "list_notification_devices",
    "create_push_record",
    "list_push_records",
    "list_signal_scan_configs",
    "create_signal_scan_config",
    "update_signal_scan_config",
]
