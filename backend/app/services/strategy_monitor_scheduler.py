import asyncio
import os
from datetime import datetime, timezone
from typing import Any

from ..schemas import (
    SignalScanResult,
    StrategyMonitorSchedulerStatus,
    StrategyMonitorSchedulerUpdate,
)
from .strategy_monitor_scanner import scan_strategy_monitors


class StrategyMonitorScheduler:
    def __init__(
        self,
        *,
        enabled_by_env: bool,
        poll_interval_seconds: int,
        refresh: bool,
    ) -> None:
        self.enabled_by_env = enabled_by_env
        self.poll_interval_seconds = poll_interval_seconds
        self.refresh = refresh
        self.last_started_at: datetime | None = None
        self.last_stopped_at: datetime | None = None
        self.last_run_at: datetime | None = None
        self.last_error: str | None = None
        self.last_result: dict[str, Any] = {}
        self._task: asyncio.Task[None] | None = None
        self._scanning = False

    @property
    def running(self) -> bool:
        return self._task is not None and not self._task.done()

    @property
    def scanning(self) -> bool:
        return self._scanning

    async def start(
        self,
        payload: StrategyMonitorSchedulerUpdate | None = None,
    ) -> StrategyMonitorSchedulerStatus:
        if payload is not None:
            self.configure(payload)
        if self.running:
            return self.status()
        self.last_started_at = _now()
        self.last_stopped_at = None
        self._task = asyncio.create_task(
            self._run_loop(),
            name="strategy-monitor-scheduler",
        )
        return self.status()

    async def stop(self) -> StrategyMonitorSchedulerStatus:
        task = self._task
        if task is None or task.done():
            self._task = None
            self.last_stopped_at = _now()
            return self.status()
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
        self._task = None
        self.last_stopped_at = _now()
        return self.status()

    def configure(self, payload: StrategyMonitorSchedulerUpdate) -> None:
        if payload.poll_interval_seconds is not None:
            self.poll_interval_seconds = payload.poll_interval_seconds
        if payload.refresh is not None:
            self.refresh = payload.refresh

    def status(self) -> StrategyMonitorSchedulerStatus:
        return StrategyMonitorSchedulerStatus(
            enabled_by_env=self.enabled_by_env,
            running=self.running,
            scanning=self.scanning,
            poll_interval_seconds=self.poll_interval_seconds,
            refresh=self.refresh,
            last_started_at=self.last_started_at,
            last_stopped_at=self.last_stopped_at,
            last_run_at=self.last_run_at,
            last_error=self.last_error,
            last_result=dict(self.last_result),
        )

    async def run_once(self, *, force: bool = False) -> SignalScanResult | None:
        if self._scanning:
            return None
        self._scanning = True
        try:
            result = await asyncio.to_thread(
                scan_strategy_monitors,
                refresh=self.refresh,
                force=force,
            )
            self.last_run_at = _now()
            self.last_error = None
            self.last_result = {
                "scanned_count": result.scanned_count,
                "created_count": result.created_count,
                "skipped_count": result.skipped_count,
                "error_count": len(result.errors),
            }
            return result
        except Exception as error:  # pragma: no cover - defensive task guard
            self.last_run_at = _now()
            self.last_error = str(error)
            self.last_result = {}
            return None
        finally:
            self._scanning = False

    async def _run_loop(self) -> None:
        while True:
            await self.run_once(force=False)
            await asyncio.sleep(self.poll_interval_seconds)


def get_strategy_monitor_scheduler() -> StrategyMonitorScheduler:
    return _SCHEDULER


def configure_strategy_monitor_scheduler_from_env() -> None:
    _SCHEDULER.enabled_by_env = _env_bool(
        "STRATEGY_MONITOR_SCHEDULER_ENABLED",
        default=False,
    )
    _SCHEDULER.poll_interval_seconds = _env_int(
        "STRATEGY_MONITOR_SCHEDULER_INTERVAL_SECONDS",
        default=60,
        minimum=10,
        maximum=3600,
    )
    _SCHEDULER.refresh = _env_bool(
        "STRATEGY_MONITOR_SCHEDULER_REFRESH",
        default=False,
    )


async def start_strategy_monitor_scheduler_from_env() -> StrategyMonitorSchedulerStatus:
    configure_strategy_monitor_scheduler_from_env()
    if _SCHEDULER.enabled_by_env:
        return await _SCHEDULER.start()
    return _SCHEDULER.status()


async def stop_strategy_monitor_scheduler() -> StrategyMonitorSchedulerStatus:
    return await _SCHEDULER.stop()


def _env_bool(name: str, *, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    normalized = value.strip().lower()
    return normalized in {"1", "true", "yes", "on"}


def _env_int(name: str, *, default: int, minimum: int, maximum: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        parsed = int(value.strip())
    except ValueError:
        return default
    return max(minimum, min(maximum, parsed))


def _now() -> datetime:
    return datetime.now(timezone.utc)


_SCHEDULER = StrategyMonitorScheduler(
    enabled_by_env=False,
    poll_interval_seconds=60,
    refresh=False,
)
