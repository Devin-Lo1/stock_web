from __future__ import annotations

import math
from collections import defaultdict
from datetime import date, datetime, time, timedelta

from ..repositories.market_data import list_candles_between, upsert_candles
from ..schemas import (
    Candle,
    VolumeProfileBacktestCreate,
    VolumeProfileBacktestResult,
    VolumeProfileBucket,
    VolumeProfileDayProfile,
    VolumeProfileSignal,
)
from ..services.futu_client import (
    FutuDependencyError,
    FutuOpenDError,
    request_history_klines_all,
)

_PERIOD = "1m"
_SESSION_START = time(9, 30)
_SESSION_END = time(16, 0)
_LOAD_LOOKBACK_DAYS = 10
_MAX_INTRADAY_CANDLES = 120000


def run_volume_profile_backtest(
    request: VolumeProfileBacktestCreate,
) -> VolumeProfileBacktestResult:
    candles = _load_intraday_candles(request)
    days = _group_regular_session_candles(candles)
    ordered_days = sorted(days)
    signals: list[VolumeProfileSignal] = []
    profiles: dict[date, VolumeProfileDayProfile] = {}

    for index in range(1, len(ordered_days)):
        signal_date = ordered_days[index]
        if signal_date < request.start_date or signal_date > request.end_date:
            continue
        profile_date = ordered_days[index - 1]
        profile = profiles.get(profile_date)
        if profile is None:
            profile = _build_profile(
                profile_date,
                days[profile_date],
                bucket_count=request.bucket_count,
                value_area_ratio=request.value_area_ratio,
            )
            profiles[profile_date] = profile
        signals.append(
            _evaluate_signal(
                signal_date=signal_date,
                signal_candles=days[signal_date],
                profile=profile,
                deviation_threshold=request.deviation_threshold,
                stop_loss_multiple=request.stop_loss_multiple,
            )
        )

    chart_signal = _latest_chart_signal(signals)
    chart_profile = profiles.get(chart_signal.profile_date) if chart_signal else None
    chart_candles = _chart_candles(days, chart_signal)

    return VolumeProfileBacktestResult(
        request=request,
        summary=_summary(signals),
        signals=signals,
        chart_profile=chart_profile,
        chart_signal=chart_signal,
        chart_candles=chart_candles,
    )


def _load_intraday_candles(request: VolumeProfileBacktestCreate) -> list[Candle]:
    load_start = request.start_date - timedelta(days=_LOAD_LOOKBACK_DAYS)
    cached = list_candles_between(
        request.stock_code,
        _PERIOD,
        load_start,
        request.end_date,
    )
    if _cached_range_is_usable(cached, request.start_date, request.end_date):
        return cached

    try:
        refreshed = request_history_klines_all(
            code=request.stock_code,
            period=_PERIOD,
            start=load_start.isoformat(),
            end=request.end_date.isoformat(),
            max_count=_MAX_INTRADAY_CANDLES,
        )
    except (FutuDependencyError, FutuOpenDError):
        if cached:
            return cached
        raise

    return upsert_candles(refreshed)


def _cached_range_is_usable(
    candles: list[Candle],
    start_date: date,
    end_date: date,
) -> bool:
    if not candles:
        return False
    available_days = sorted({candle.time.date() for candle in candles if candle.time})
    if len(available_days) < 2:
        return False
    calendar_days = (end_date - start_date).days + 1
    if calendar_days <= 5:
        return True
    expected_trading_days = max(2, int(calendar_days * 0.45))
    latest_allowed = end_date - timedelta(days=7)
    return len(available_days) >= expected_trading_days and available_days[-1] >= latest_allowed


def _group_regular_session_candles(candles: list[Candle]) -> dict[date, list[Candle]]:
    grouped: dict[date, list[Candle]] = defaultdict(list)
    for candle in candles:
        timestamp = candle.time
        if timestamp is None:
            continue
        if not _is_regular_session(timestamp):
            continue
        grouped[timestamp.date()].append(candle)
    return {
        day: sorted(day_candles, key=lambda candle: candle.time or datetime.min)
        for day, day_candles in grouped.items()
        if day_candles
    }


def _is_regular_session(timestamp: datetime) -> bool:
    current_time = timestamp.time()
    return _SESSION_START <= current_time <= _SESSION_END


def _build_profile(
    profile_date: date,
    candles: list[Candle],
    *,
    bucket_count: int,
    value_area_ratio: float,
) -> VolumeProfileDayProfile:
    low_price = min(candle.low for candle in candles)
    high_price = max(candle.high for candle in candles)
    total_volume = sum(max(candle.volume, 0) for candle in candles)
    if low_price <= 0 or high_price <= low_price or total_volume <= 0:
        return _empty_profile(profile_date, bucket_count, value_area_ratio)

    bucket_size = (high_price - low_price) / bucket_count
    volumes = [0.0 for _ in range(bucket_count)]
    for candle in candles:
        _add_candle_volume(
            volumes,
            candle,
            min_price=low_price,
            bucket_size=bucket_size,
        )

    distributed_total = sum(volumes)
    if distributed_total <= 0:
        return _empty_profile(profile_date, bucket_count, value_area_ratio)

    poc_index = max(range(bucket_count), key=lambda index: volumes[index])
    value_low, value_high = _value_area_bounds(
        volumes,
        poc_index=poc_index,
        target_volume=distributed_total * value_area_ratio,
    )
    buckets = [
        VolumeProfileBucket(
            price_low=low_price + bucket_size * index,
            price_high=low_price + bucket_size * (index + 1),
            price_mid=low_price + bucket_size * (index + 0.5),
            volume=volume,
            volume_ratio=volume / distributed_total,
        )
        for index, volume in enumerate(volumes)
    ]
    return VolumeProfileDayProfile(
        date=profile_date,
        poc=buckets[poc_index].price_mid,
        vah=buckets[value_high].price_high,
        val=buckets[value_low].price_low,
        total_volume=distributed_total,
        bucket_count=bucket_count,
        value_area_ratio=value_area_ratio,
        buckets=buckets,
    )


def _empty_profile(
    profile_date: date,
    bucket_count: int,
    value_area_ratio: float,
) -> VolumeProfileDayProfile:
    return VolumeProfileDayProfile(
        date=profile_date,
        poc=0,
        vah=0,
        val=0,
        total_volume=0,
        bucket_count=bucket_count,
        value_area_ratio=value_area_ratio,
        buckets=[],
    )


def _add_candle_volume(
    volumes: list[float],
    candle: Candle,
    *,
    min_price: float,
    bucket_size: float,
) -> None:
    volume = max(candle.volume, 0)
    if volume <= 0 or bucket_size <= 0:
        return
    candle_low = min(candle.low, candle.high)
    candle_high = max(candle.low, candle.high)
    if candle_high <= candle_low:
        index = _bucket_index(candle.close, min_price, bucket_size, len(volumes))
        volumes[index] += volume
        return

    span = candle_high - candle_low
    start_index = _bucket_index(candle_low, min_price, bucket_size, len(volumes))
    end_index = _bucket_index(candle_high, min_price, bucket_size, len(volumes))
    for index in range(start_index, end_index + 1):
        bucket_low = min_price + bucket_size * index
        bucket_high = bucket_low + bucket_size
        overlap = max(0.0, min(candle_high, bucket_high) - max(candle_low, bucket_low))
        if overlap > 0:
            volumes[index] += volume * overlap / span


def _bucket_index(price: float, min_price: float, bucket_size: float, bucket_count: int) -> int:
    if bucket_size <= 0:
        return 0
    index = int(math.floor((price - min_price) / bucket_size))
    return max(0, min(bucket_count - 1, index))


def _value_area_bounds(
    volumes: list[float],
    *,
    poc_index: int,
    target_volume: float,
) -> tuple[int, int]:
    low_index = poc_index
    high_index = poc_index
    cumulative = volumes[poc_index]
    while cumulative < target_volume and (low_index > 0 or high_index < len(volumes) - 1):
        lower_volume = volumes[low_index - 1] if low_index > 0 else -1.0
        upper_volume = volumes[high_index + 1] if high_index < len(volumes) - 1 else -1.0
        if upper_volume >= lower_volume and high_index < len(volumes) - 1:
            high_index += 1
            cumulative += volumes[high_index]
        elif low_index > 0:
            low_index -= 1
            cumulative += volumes[low_index]
        else:
            break
    return low_index, high_index


def _evaluate_signal(
    *,
    signal_date: date,
    signal_candles: list[Candle],
    profile: VolumeProfileDayProfile,
    deviation_threshold: float,
    stop_loss_multiple: float,
) -> VolumeProfileSignal:
    if not signal_candles or profile.total_volume <= 0:
        return VolumeProfileSignal(date=signal_date, profile_date=profile.date, outcome="no_profile")

    open_price = signal_candles[0].open
    width = profile.vah - profile.val
    if width <= 0:
        return VolumeProfileSignal(
            date=signal_date,
            profile_date=profile.date,
            open_price=open_price,
            outcome="no_profile",
            poc=profile.poc,
            vah=profile.vah,
            val=profile.val,
        )

    if open_price > profile.vah:
        direction = "short"
        target_price = profile.vah
        distance = open_price - target_price
        stop_price = open_price + distance * stop_loss_multiple
        deviation = distance / width
    elif open_price < profile.val:
        direction = "long"
        target_price = profile.val
        distance = target_price - open_price
        stop_price = open_price - distance * stop_loss_multiple
        deviation = distance / width
    else:
        return VolumeProfileSignal(
            date=signal_date,
            profile_date=profile.date,
            open_price=open_price,
            outcome="no_signal",
            poc=profile.poc,
            vah=profile.vah,
            val=profile.val,
        )

    if deviation > deviation_threshold:
        return VolumeProfileSignal(
            date=signal_date,
            profile_date=profile.date,
            direction=direction,
            open_price=open_price,
            target_price=target_price,
            stop_price=stop_price,
            deviation=deviation,
            outcome="skipped",
            poc=profile.poc,
            vah=profile.vah,
            val=profile.val,
        )

    outcome, outcome_time, outcome_price = _resolve_outcome(
        signal_candles,
        direction=direction,
        target_price=target_price,
        stop_price=stop_price,
    )
    return VolumeProfileSignal(
        date=signal_date,
        profile_date=profile.date,
        direction=direction,
        open_price=open_price,
        target_price=target_price,
        stop_price=stop_price,
        deviation=deviation,
        outcome=outcome,
        outcome_time=outcome_time,
        outcome_price=outcome_price,
        poc=profile.poc,
        vah=profile.vah,
        val=profile.val,
    )


def _resolve_outcome(
    candles: list[Candle],
    *,
    direction: str,
    target_price: float,
    stop_price: float,
) -> tuple[str, datetime | None, float | None]:
    for candle in candles:
        if direction == "long":
            hit_target = candle.high >= target_price
            hit_stop = candle.low <= stop_price
        else:
            hit_target = candle.low <= target_price
            hit_stop = candle.high >= stop_price
        if hit_stop:
            return "failed", candle.time, stop_price
        if hit_target:
            return "success", candle.time, target_price
    return "no_result", None, None


def _summary(signals: list[VolumeProfileSignal]) -> dict[str, object]:
    total_days = len(signals)
    triggered = [signal for signal in signals if signal.direction is not None and signal.outcome != "skipped"]
    success_count = sum(1 for signal in signals if signal.outcome == "success")
    failed_count = sum(1 for signal in signals if signal.outcome == "failed")
    resolved_count = success_count + failed_count
    return {
        "total_days": total_days,
        "triggered_count": len(triggered),
        "success_count": success_count,
        "failed_count": failed_count,
        "no_signal_count": sum(1 for signal in signals if signal.outcome == "no_signal"),
        "skipped_count": sum(1 for signal in signals if signal.outcome == "skipped"),
        "no_result_count": sum(1 for signal in signals if signal.outcome == "no_result"),
        "no_profile_count": sum(1 for signal in signals if signal.outcome == "no_profile"),
        "success_rate": success_count / resolved_count if resolved_count else 0,
        "trigger_rate": len(triggered) / total_days if total_days else 0,
        "resolved_count": resolved_count,
        "rule": "1m_volume_profile_previous_day_68_value_area_1r_stop",
    }


def _latest_chart_signal(signals: list[VolumeProfileSignal]) -> VolumeProfileSignal | None:
    for signal in reversed(signals):
        if signal.profile_date is not None and signal.direction is not None:
            return signal
    for signal in reversed(signals):
        if signal.profile_date is not None:
            return signal
    return None


def _chart_candles(
    days: dict[date, list[Candle]],
    signal: VolumeProfileSignal | None,
) -> list[Candle]:
    if signal is None or signal.profile_date is None:
        return []
    return [
        *days.get(signal.profile_date, []),
        *days.get(signal.date, []),
    ]
