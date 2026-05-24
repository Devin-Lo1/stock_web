from datetime import datetime, timezone
from typing import Any

from ..repositories.notifications import (
    create_signal_event,
    get_signal_event_by_dedupe_key,
)
from ..schemas import (
    FundAlertScanResult,
    FundGridRecommendation,
    SignalEvent,
    SignalEventCreate,
)
from .funds import list_fund_position_summaries
from .push_service import dispatch_signal_event_to_devices


def scan_fund_alerts(
    *,
    refresh: bool = True,
    scan_key: str = "",
    dispatch_push: bool = True,
) -> FundAlertScanResult:
    now = datetime.now(timezone.utc)
    events: list[SignalEvent] = []
    errors: list[dict[str, Any]] = []
    skipped_count = 0
    summaries = list_fund_position_summaries(refresh=refresh)
    for summary in summaries:
        recommendation = summary.grid_recommendation
        if recommendation is None:
            skipped_count += 1
            continue
        payload = _event_payload(recommendation, scan_key=scan_key, now=now)
        if get_signal_event_by_dedupe_key(payload.dedupe_key) is not None:
            skipped_count += 1
            continue
        event = create_signal_event(payload)
        if dispatch_push:
            try:
                dispatch_signal_event_to_devices(event)
            except Exception as error:  # pragma: no cover - push must not hide signals
                errors.append(
                    {
                        "fund_code": recommendation.fund_code,
                        "stage": "dispatch_push",
                        "message": str(error),
                    },
                )
        events.append(event)
    return FundAlertScanResult(
        scanned_count=len(summaries),
        created_count=len(events),
        skipped_count=skipped_count,
        events=events,
        errors=errors,
        scanned_at=now,
        scan_key=scan_key,
    )


def _event_payload(
    recommendation: FundGridRecommendation,
    *,
    scan_key: str,
    now: datetime,
) -> SignalEventCreate:
    side_label = "下跌" if recommendation.action == "buy" else "上涨"
    level = "important"
    dedupe_key = (
        f"fund_alert:{scan_key or now.isoformat()}:"
        f"{recommendation.position_id}:{recommendation.action}"
    )
    return SignalEventCreate(
        source="fund_alert_scheduler",
        code=recommendation.fund_code,
        signal_type=f"fund_grid_{recommendation.action}",
        level=level,
        title=f"{recommendation.name} {side_label}触线提醒",
        message=(
            f"{recommendation.reason}，触发阈值 "
            f"{recommendation.threshold_percent:.2f}%。"
        ),
        trigger_value=recommendation.change_rate,
        threshold_value=recommendation.threshold_percent,
        dedupe_key=dedupe_key,
        payload={
            "source_category": "fund",
            "position_id": recommendation.position_id,
            "stock_name": recommendation.name,
            "strategy_code": "fund_grid_alert",
            "strategy_name": "基金涨跌提醒",
            "condition_label": recommendation.reason,
            "side": recommendation.action,
            "fund_code": recommendation.fund_code,
            "baseline_nav": recommendation.baseline_nav,
            "current_nav": recommendation.current_nav,
            "recommended_amount": recommendation.recommended_amount,
            "recommended_shares": recommendation.recommended_shares,
            "valuation_mode": recommendation.valuation_mode,
            "valuation_time": recommendation.valuation_time.isoformat()
            if recommendation.valuation_time
            else None,
            "scan_key": scan_key,
            "push_candidate": True,
        },
        triggered_at=now,
    )
