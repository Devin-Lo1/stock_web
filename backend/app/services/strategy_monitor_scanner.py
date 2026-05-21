from datetime import datetime, timedelta, timezone
from typing import Any

from ..repositories.market_data import list_candles, upsert_candles
from ..repositories.notifications import (
    create_signal_event,
    get_signal_event_by_dedupe_key,
)
from ..repositories.strategy_monitors import (
    list_strategy_monitors,
    update_strategy_monitor_scan_state,
)
from ..schemas import (
    Candle,
    SignalEvent,
    SignalEventCreate,
    SignalScanResult,
    StrategyMonitor,
)
from ..services.futu_client import (
    FutuDependencyError,
    FutuOpenDError,
    request_history_klines,
)
from ..services.push_service import dispatch_signal_event_to_devices
from ..services.signal_scanner import _condition_values, _latest_signal, _parameter_key
from ..strategies import get_strategy
from ..strategies.base import StrategyConfigurationError, StrategySignal


def scan_strategy_monitors(
    *,
    refresh: bool = False,
    force: bool = False,
) -> SignalScanResult:
    now = datetime.now(timezone.utc)
    events: list[SignalEvent] = []
    errors: list[dict[str, Any]] = []
    scanned_count = 0
    skipped_count = 0

    for monitor in list_strategy_monitors(enabled_only=True, limit=500):
        if not force and not _is_scan_due(monitor, now):
            skipped_count += 1
            continue
        if _is_in_cooldown(monitor, now):
            skipped_count += 1
            continue

        candles, load_error = _load_monitor_candles(monitor, refresh=refresh)
        if load_error:
            errors.append(
                {
                    "monitor_id": monitor.id,
                    "code": monitor.code,
                    "stage": "load_candles",
                    "message": load_error,
                },
            )
        if len(candles) < 2:
            update_strategy_monitor_scan_state(monitor.id, last_scanned_at=now)
            skipped_count += 1
            continue

        strategy = get_strategy(monitor.strategy_code)
        if strategy is None:
            update_strategy_monitor_scan_state(monitor.id, last_scanned_at=now)
            errors.append(
                {
                    "monitor_id": monitor.id,
                    "code": monitor.code,
                    "strategy_code": monitor.strategy_code,
                    "stage": "strategy_lookup",
                    "message": "strategy is not supported by backend registry",
                },
            )
            skipped_count += 1
            continue

        try:
            minimum_candles = strategy.minimum_candles(monitor.parameters)
        except StrategyConfigurationError as error:
            update_strategy_monitor_scan_state(monitor.id, last_scanned_at=now)
            errors.append(
                {
                    "monitor_id": monitor.id,
                    "code": monitor.code,
                    "strategy_code": monitor.strategy_code,
                    "stage": "minimum_candles",
                    "message": error.reason,
                },
            )
            skipped_count += 1
            continue
        if len(candles) < minimum_candles:
            update_strategy_monitor_scan_state(monitor.id, last_scanned_at=now)
            skipped_count += 1
            continue

        scanned_count += 1
        try:
            evaluation = strategy.evaluate(candles, monitor.parameters)
        except StrategyConfigurationError as error:
            update_strategy_monitor_scan_state(monitor.id, last_scanned_at=now)
            errors.append(
                {
                    "monitor_id": monitor.id,
                    "code": monitor.code,
                    "strategy_code": monitor.strategy_code,
                    "stage": "evaluate",
                    "message": error.reason,
                },
            )
            skipped_count += 1
            continue

        signal = _latest_signal(evaluation.signals, len(candles) - 1)
        if signal is None:
            update_strategy_monitor_scan_state(monitor.id, last_scanned_at=now)
            skipped_count += 1
            continue

        payload = _event_payload(monitor, candles, signal)
        existing = get_signal_event_by_dedupe_key(payload.dedupe_key)
        if existing is not None:
            update_strategy_monitor_scan_state(monitor.id, last_scanned_at=now)
            skipped_count += 1
            continue

        event = create_signal_event(payload)
        try:
            dispatch_signal_event_to_devices(event)
        except Exception as error:  # pragma: no cover - push must not hide signals
            errors.append(
                {
                    "monitor_id": monitor.id,
                    "code": monitor.code,
                    "strategy_code": monitor.strategy_code,
                    "stage": "dispatch_push",
                    "message": str(error),
                },
            )
        update_strategy_monitor_scan_state(
            monitor.id,
            last_scanned_at=now,
            last_triggered_at=event.triggered_at,
            last_signal_event_id=event.id,
        )
        events.append(event)

    return SignalScanResult(
        scanned_count=scanned_count,
        created_count=len(events),
        skipped_count=skipped_count,
        events=events,
        errors=errors,
    )


def _load_monitor_candles(
    monitor: StrategyMonitor,
    *,
    refresh: bool,
) -> tuple[list[Candle], str | None]:
    limit = _scan_limit(monitor.period)
    if refresh:
        try:
            refreshed = request_history_klines(
                code=monitor.code,
                period=monitor.period,
                max_count=limit,
            )
        except (FutuDependencyError, FutuOpenDError) as error:
            return list_candles(monitor.code, monitor.period, limit), str(error)
        if refreshed:
            upsert_candles(refreshed)
    return list_candles(monitor.code, monitor.period, limit), None


def _event_payload(
    monitor: StrategyMonitor,
    candles: list[Candle],
    signal: StrategySignal,
) -> SignalEventCreate:
    latest = candles[signal.index]
    condition, trigger_value, threshold_value = _condition_values(
        candles,
        monitor,
        signal,
    )
    signal_time = latest.time.astimezone(timezone.utc)
    side_label = "strength" if signal.side == "buy" else "weakness"
    level = "important" if signal.side == "sell" else "warning"
    dedupe_key = (
        f"strategy_monitor:{monitor.id}:{monitor.strategy_code}:"
        f"{_parameter_key(monitor.parameters)}:{signal.side}:{signal_time.isoformat()}"
    )
    return SignalEventCreate(
        source="strategy_monitor",
        code=monitor.code,
        signal_type=f"{monitor.strategy_code}_{signal.side}",
        level=level,
        title=f"{monitor.name} {monitor.strategy_name} observation",
        message=(
            f"{condition}; value {trigger_value:.2f}, "
            f"threshold {threshold_value:.2f}; "
            f"{signal_time.isoformat()} triggered {side_label} condition."
        ),
        trigger_value=trigger_value,
        threshold_value=threshold_value,
        dedupe_key=dedupe_key,
        payload={
            "source_category": "strategy",
            "monitor_id": monitor.id,
            "position_id": monitor.position_id,
            "stock_name": monitor.name,
            "strategy_code": monitor.strategy_code,
            "strategy_name": monitor.strategy_name,
            "condition_label": condition,
            "side": signal.side,
            "period": monitor.period,
            "trigger_time": signal_time.isoformat(),
            "parameters": monitor.parameters,
            "source_backtest_run_id": monitor.source_backtest_run_id,
            "push_candidate": monitor.push_candidate
            and level in {"important", "warning"},
        },
        triggered_at=signal_time,
    )


def _is_scan_due(monitor: StrategyMonitor, now: datetime) -> bool:
    if monitor.last_scanned_at is None:
        return True
    return now - monitor.last_scanned_at >= timedelta(
        minutes=monitor.scan_interval_minutes,
    )


def _is_in_cooldown(monitor: StrategyMonitor, now: datetime) -> bool:
    if monitor.cooldown_minutes <= 0 or monitor.last_triggered_at is None:
        return False
    return now - monitor.last_triggered_at < timedelta(minutes=monitor.cooldown_minutes)


def _scan_limit(period: str) -> int:
    if period in {"1m", "60m"}:
        return 1000
    return 260
