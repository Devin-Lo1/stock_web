import asyncio
from datetime import datetime, timedelta, timezone
from typing import Any

from ..repositories.fund_alert_scheduler import (
    get_fund_alert_scheduler_config,
    record_fund_alert_scan_result,
    update_fund_alert_scheduler_config,
)
from ..schemas import (
    FundAlertScanResult,
    FundAlertSchedulerStatus,
    FundAlertSchedulerUpdate,
)
from .fund_alert_scanner import scan_fund_alerts

CN_TZ = timezone(timedelta(hours=8))


class FundAlertScheduler:
    def __init__(self, *, poll_interval_seconds: int = 60) -> None:
        self.poll_interval_seconds = poll_interval_seconds
        self.last_started_at: datetime | None = None
        self.last_stopped_at: datetime | None = None
        self._task: asyncio.Task[None] | None = None
        self._scanning = False

    @property
    def running(self) -> bool:
        return self._task is not None and not self._task.done()

    @property
    def scanning(self) -> bool:
        return self._scanning

    async def start(self) -> FundAlertSchedulerStatus:
        if self.running:
            return self.status()
        self.last_started_at = _now()
        self.last_stopped_at = None
        self._task = asyncio.create_task(
            self._run_loop(),
            name="fund-alert-scheduler",
        )
        return self.status()

    async def stop(self) -> FundAlertSchedulerStatus:
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

    def configure(
        self,
        payload: FundAlertSchedulerUpdate,
    ) -> FundAlertSchedulerStatus:
        update_fund_alert_scheduler_config(payload)
        return self.status()

    def status(self) -> FundAlertSchedulerStatus:
        config = get_fund_alert_scheduler_config()
        return config.model_copy(
            update={
                "running": self.running,
                "scanning": self.scanning,
                "poll_interval_seconds": self.poll_interval_seconds,
                "next_run_at": _next_run_at(config),
                "last_started_at": self.last_started_at,
                "last_stopped_at": self.last_stopped_at,
            },
        )

    async def run_once(
        self,
        *,
        refresh: bool = True,
        scan_key: str = "",
    ) -> FundAlertScanResult | None:
        if self._scanning:
            return None
        self._scanning = True
        effective_key = scan_key or f"manual:{_now().isoformat()}"
        try:
            result = await asyncio.to_thread(
                scan_fund_alerts,
                refresh=refresh,
                scan_key=effective_key,
            )
            record_fund_alert_scan_result(
                scan_key=effective_key,
                scan_at=result.scanned_at,
                result=_result_payload(result),
            )
            return result
        except Exception as error:  # pragma: no cover - defensive task guard
            record_fund_alert_scan_result(
                scan_key=effective_key,
                scan_at=_now(),
                result={},
                error=str(error),
            )
            return None
        finally:
            self._scanning = False

    async def _run_loop(self) -> None:
        while True:
            await self._run_due_scan()
            await asyncio.sleep(self.poll_interval_seconds)

    async def _run_due_scan(self) -> None:
        config = get_fund_alert_scheduler_config()
        if not config.enabled:
            return
        due_key = _due_scan_key(config)
        if due_key is None or due_key == config.last_scan_key:
            return
        await self.run_once(refresh=True, scan_key=due_key)


def get_fund_alert_scheduler() -> FundAlertScheduler:
    return _SCHEDULER


async def start_fund_alert_scheduler() -> FundAlertSchedulerStatus:
    return await _SCHEDULER.start()


async def stop_fund_alert_scheduler() -> FundAlertSchedulerStatus:
    return await _SCHEDULER.stop()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _now_cn() -> datetime:
    return _now().astimezone(CN_TZ)


def _due_scan_key(config: FundAlertSchedulerStatus) -> str | None:
    now = _now_cn()
    current_minutes = now.hour * 60 + now.minute
    for reminder_time in sorted(config.reminder_times, reverse=True):
        target_minutes = _minutes(reminder_time)
        delta = current_minutes - target_minutes
        if 0 <= delta <= config.due_window_minutes:
            return f"{now.date().isoformat()}:{reminder_time}"
    return None


def _next_run_at(config: FundAlertSchedulerStatus) -> datetime | None:
    if not config.enabled:
        return None
    now = _now_cn()
    current_minutes = now.hour * 60 + now.minute
    for reminder_time in sorted(config.reminder_times):
        target_minutes = _minutes(reminder_time)
        scan_key = f"{now.date().isoformat()}:{reminder_time}"
        if target_minutes >= current_minutes and scan_key != config.last_scan_key:
            return _datetime_for_minutes(now, target_minutes).astimezone(timezone.utc)
    tomorrow = now + timedelta(days=1)
    first = _minutes(sorted(config.reminder_times)[0])
    return _datetime_for_minutes(tomorrow, first).astimezone(timezone.utc)


def _datetime_for_minutes(now: datetime, minutes: int) -> datetime:
    return now.replace(
        hour=minutes // 60,
        minute=minutes % 60,
        second=0,
        microsecond=0,
    )


def _minutes(value: str) -> int:
    hour, minute = value.split(":", maxsplit=1)
    return int(hour) * 60 + int(minute)


def _result_payload(result: FundAlertScanResult) -> dict[str, Any]:
    return {
        "scanned_count": result.scanned_count,
        "created_count": result.created_count,
        "skipped_count": result.skipped_count,
        "error_count": len(result.errors),
        "event_ids": [event.id for event in result.events],
    }


_SCHEDULER = FundAlertScheduler(poll_interval_seconds=60)
