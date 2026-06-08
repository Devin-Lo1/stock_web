from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from typing import Any
from zoneinfo import ZoneInfo

from ..repositories.market_data import (
    get_quotes,
    list_candles_between,
    upsert_candles,
    upsert_quote,
)
from ..schemas import Candle, QuoteSnapshot
from ..schemas.personalized_strategies import (
    PersonalizedStrategyBulkScanResult,
    PersonalizedStrategyDecision,
    PersonalizedStrategyRecommendation,
    PersonalizedStrategyScanResult,
    PersonalizedStrategySegment,
    PersonalizedStrategyTemplate,
)
from .futu_client import (
    FutuDependencyError,
    FutuOpenDError,
    get_futu_quote,
    request_history_klines_all,
)


_DATA_START = date(2021, 1, 1)
_US_EASTERN = ZoneInfo("America/New_York")
_DEFAULT_TEMPLATE_CODES_BY_SYMBOL = {
    "HK.02628": "personal_chinalife_hk_channel67_steady",
    "HK.01398": "personal_icbc_hk_price_ema30_steady",
    "HK.09988": "personal_alibaba_hk_price_sma30_steady",
    "US.AAOI": "personal_aaoi_sma37_53_steady",
    "US.AMD": "personal_amd_ma10_20_steady",
    "US.DELL": "personal_dell_channel19_steady",
    "US.GOOGL": "personal_googl_sma5_113_steady",
    "US.MSFT": "personal_msft_channel61_steady",
    "US.MU": "personal_mu_sma24_40_steady",
    "US.NVDA": "personal_nvda_ma30_40_steady",
    "US.QQQ": "personal_qqq_sma7_111_steady",
}


@dataclass(frozen=True)
class _StrategyEvent:
    event_date: date
    action: str
    price: float
    reason: str


@dataclass
class _Position:
    side: str
    entry_price: float
    entry_date: date
    hold_days: int = 0
    high_since_entry: float = 0
    low_since_entry: float = 0
    highest_close_since_entry: float = 0
    lowest_close_since_entry: float = 0


def list_personalized_strategy_templates() -> list[PersonalizedStrategyTemplate]:
    return [_template_from_config(config) for config in _TEMPLATES]


def get_personalized_strategy_template(
    symbol: str,
) -> PersonalizedStrategyTemplate | None:
    normalized_symbol = symbol.strip().upper()
    config = _find_config(normalized_symbol)
    return _template_from_config(config) if config is not None else None


def scan_personalized_strategy(
    symbol: str,
    *,
    refresh: bool = False,
    _candle_cache: dict[tuple[str, bool], tuple[list[Candle], str | None]] | None = None,
    _quote_cache: dict[tuple[str, bool], tuple[QuoteSnapshot | None, str | None]]
    | None = None,
) -> PersonalizedStrategyScanResult | None:
    normalized_symbol = symbol.strip().upper()
    config = _find_config(normalized_symbol)
    if config is None:
        return None

    template = _template_from_config(config)
    candles, refresh_error = _load_day_candles_cached(
        template.symbol,
        refresh=refresh,
        cache=_candle_cache,
    )
    benchmark_candles, benchmark_error = _load_day_candles_cached(
        template.benchmark_symbol,
        refresh=refresh,
        cache=_candle_cache,
    )
    refresh_error = _merge_errors(refresh_error, benchmark_error)
    quote, quote_error = _load_quote_cached(
        template.symbol,
        refresh=refresh,
        cache=_quote_cache,
    )
    benchmark_quote, benchmark_quote_error = _load_quote_cached(
        template.benchmark_symbol,
        refresh=refresh,
        cache=_quote_cache,
    )
    refresh_error = _merge_errors(
        refresh_error,
        _merge_errors(quote_error, benchmark_quote_error),
    )

    if len(candles) < _minimum_candle_count(config):
        return PersonalizedStrategyScanResult(
            template=template,
            status="failed",
            action="failed",
            action_label="数据不足",
            reason="not_enough_symbol_candles",
            refresh_error=refresh_error,
            detail={
                "symbol_candle_count": len(candles),
                "required_candle_count": _minimum_candle_count(config),
            },
        )
    if len(benchmark_candles) < _minimum_benchmark_count(config):
        return PersonalizedStrategyScanResult(
            template=template,
            status="failed",
            action="failed",
            action_label="基准不足",
            reason="not_enough_benchmark_candles",
            refresh_error=refresh_error,
            detail={
                "benchmark_candle_count": len(benchmark_candles),
                "required_candle_count": _minimum_benchmark_count(config),
            },
        )

    previous_candles = _previous_close_candles(candles, quote)
    previous_benchmark_candles = _previous_close_candles(
        benchmark_candles,
        benchmark_quote,
    )
    previous_decision = None
    if (
        len(previous_candles) >= _minimum_candle_count(config)
        and len(previous_benchmark_candles) >= _minimum_benchmark_count(config)
    ):
        previous_replay = _replay_strategy(
            config,
            previous_candles,
            previous_benchmark_candles,
        )
        previous_decision = _decision_from_replay(
            template,
            previous_replay,
            kind="previous_close",
            title="昨日收盘信号",
            is_realtime=False,
            is_confirmed=True,
        )

    today_decision = None
    if quote is not None and benchmark_quote is not None:
        realtime_candles = _with_realtime_candle(candles, quote)
        realtime_benchmark_candles = _with_realtime_candle(
            benchmark_candles,
            benchmark_quote,
        )
        if (
            len(realtime_candles) >= _minimum_candle_count(config)
            and len(realtime_benchmark_candles) >= _minimum_benchmark_count(config)
        ):
            today_replay = _replay_strategy(
                config,
                realtime_candles,
                realtime_benchmark_candles,
            )
            signal_kind, is_confirmed = _intraday_signal_kind(quote)
            today_decision = _decision_from_replay(
                template,
                today_replay,
                kind=signal_kind,
                title="策略信号" if is_confirmed else "预估建议操作",
                is_realtime=True,
                is_confirmed=is_confirmed,
                detail={
                    "quote_time": quote.quote_time.isoformat(),
                    "benchmark_quote_time": benchmark_quote.quote_time.isoformat(),
                },
            )

    primary_decision = today_decision or previous_decision
    action = primary_decision.action if primary_decision is not None else "neutral"
    action_label = _action_label(action)
    current_position = (
        primary_decision.current_position if primary_decision is not None else "flat"
    )
    latest_date = primary_decision.latest_date if primary_decision is not None else None
    latest_close = (
        primary_decision.latest_price if primary_decision is not None else None
    )
    signal_date = (
        primary_decision.signal_date if primary_decision is not None else None
    )
    reason = primary_decision.reason if primary_decision is not None else "no_signal"

    return PersonalizedStrategyScanResult(
        template=template,
        status="completed",
        action=action,
        action_label=action_label,
        current_position=current_position,
        latest_date=latest_date,
        latest_close=latest_close,
        signal_date=signal_date,
        reason=reason,
        refresh_error=refresh_error,
        today_signal=today_decision,
        previous_close_signal=previous_decision,
        detail={
            "today_available": today_decision is not None,
            "previous_close_available": previous_decision is not None,
            "symbol_candle_count": len(candles),
            "benchmark_candle_count": len(benchmark_candles),
        },
    )


def scan_all_personalized_strategies(
    *,
    refresh: bool = False,
    limit: int = 3,
) -> PersonalizedStrategyBulkScanResult:
    results: list[PersonalizedStrategyScanResult] = []
    candle_cache: dict[tuple[str, bool], tuple[list[Candle], str | None]] = {}
    quote_cache: dict[tuple[str, bool], tuple[QuoteSnapshot | None, str | None]] = {}
    for config in _TEMPLATES:
        result = scan_personalized_strategy(
            config["code"],
            refresh=refresh,
            _candle_cache=candle_cache,
            _quote_cache=quote_cache,
        )
        if result is not None:
            results.append(result)
    recommendations = _rank_personalized_recommendations(results)[: max(1, limit)]
    return PersonalizedStrategyBulkScanResult(
        results=results,
        recommendations=recommendations,
    )


def _template_from_config(config: dict[str, Any]) -> PersonalizedStrategyTemplate:
    return PersonalizedStrategyTemplate(
        code=config["code"],
        symbol=config["symbol"],
        name=config["name"],
        description=config["description"],
        benchmark_symbol=config.get("benchmark_symbol", "US.QQQ"),
        direction_mode=config.get("direction_mode", "long_short"),
        risk_level=config.get("risk_level", "balanced"),
        position_ratio=config.get("position_ratio", 1.0),
        max_hold_days=config["parameters"].get("max_hold_days"),
        parameters=config["parameters"],
        entry_rules=config["entry_rules"],
        exit_rules=config["exit_rules"],
        segments=[
            PersonalizedStrategySegment(**segment)
            for segment in config.get("segments", [])
        ],
    )


def _find_config(symbol: str) -> dict[str, Any] | None:
    for config in _TEMPLATES:
        if config["code"].upper() == symbol:
            return config

    default_code = _DEFAULT_TEMPLATE_CODES_BY_SYMBOL.get(symbol)
    if default_code is not None:
        for config in _TEMPLATES:
            if config["code"].upper() == default_code.upper():
                return config

    for config in _TEMPLATES:
        if config["symbol"].upper() == symbol:
            return config
    return None


def _rank_personalized_recommendations(
    results: list[PersonalizedStrategyScanResult],
) -> list[PersonalizedStrategyRecommendation]:
    best_by_symbol: dict[str, PersonalizedStrategyRecommendation] = {}
    for result in results:
        recommendation = _recommendation_from_result(result)
        if recommendation is None:
            continue
        current = best_by_symbol.get(recommendation.symbol)
        if current is None or recommendation.score > current.score:
            best_by_symbol[recommendation.symbol] = recommendation
    return sorted(
        best_by_symbol.values(),
        key=lambda item: (
            item.score,
            item.signal_date or date.min,
            item.latest_date or date.min,
        ),
        reverse=True,
    )


def _recommendation_from_result(
    result: PersonalizedStrategyScanResult,
) -> PersonalizedStrategyRecommendation | None:
    if result.status != "completed":
        return None
    decision = result.today_signal or result.previous_close_signal
    if decision is None:
        return None
    if decision.action not in {"long_entry", "hold_long"}:
        return None

    template = result.template
    score = _recommendation_score(template, decision)
    summary = (
        "空仓优先观察买入"
        if decision.action == "long_entry"
        else "策略虚拟仓位仍在多头"
    )
    return PersonalizedStrategyRecommendation(
        symbol=template.symbol,
        template_code=template.code,
        template_name=template.name,
        risk_level=template.risk_level,
        action=decision.action,
        action_label=decision.action_label,
        score=score,
        latest_date=decision.latest_date,
        latest_price=decision.latest_price,
        signal_date=decision.signal_date,
        reason=decision.reason,
        summary=summary,
        result=result,
    )


def _recommendation_score(
    template: PersonalizedStrategyTemplate,
    decision: PersonalizedStrategyDecision,
) -> float:
    action_score = 100.0 if decision.action == "long_entry" else 72.0
    risk_score = 6.0 if template.risk_level == "steady" else 0.0
    segment_score = _segment_quality_score(template.segments)
    confirmed_score = 4.0 if decision.is_confirmed else 0.0
    return action_score + risk_score + segment_score + confirmed_score


def _segment_quality_score(segments: list[PersonalizedStrategySegment]) -> float:
    if not segments:
        return 0.0
    average_return = sum(segment.total_return for segment in segments) / len(segments)
    average_win_rate = sum(segment.win_rate for segment in segments) / len(segments)
    worst_drawdown = min(segment.max_drawdown for segment in segments)
    return average_return * 10 + average_win_rate * 8 + max(worst_drawdown, -0.3) * 6


def _load_day_candles(
    symbol: str,
    *,
    refresh: bool,
) -> tuple[list[Candle], str | None]:
    today = datetime.now(timezone.utc).date()
    candles = list_candles_between(symbol, "day", _DATA_START, today)
    refresh_error = None
    if refresh or len(candles) < 260:
        try:
            refreshed = request_history_klines_all(
                code=symbol,
                period="day",
                start=_DATA_START.isoformat(),
                end=today.isoformat(),
                max_count=3000,
            )
            if refreshed:
                upsert_candles(refreshed)
                candles = list_candles_between(symbol, "day", _DATA_START, today)
        except (FutuDependencyError, FutuOpenDError) as error:
            refresh_error = str(error)
    candles.sort(key=lambda item: item.time)
    return candles, refresh_error


def _load_day_candles_cached(
    symbol: str,
    *,
    refresh: bool,
    cache: dict[tuple[str, bool], tuple[list[Candle], str | None]] | None,
) -> tuple[list[Candle], str | None]:
    if cache is None:
        return _load_day_candles(symbol, refresh=refresh)
    key = (symbol.strip().upper(), refresh)
    if key not in cache:
        cache[key] = _load_day_candles(symbol, refresh=refresh)
    return cache[key]


def _load_quote(
    symbol: str,
    *,
    refresh: bool,
) -> tuple[QuoteSnapshot | None, str | None]:
    normalized_symbol = symbol.strip().upper()
    refresh_error = None
    if refresh:
        try:
            return upsert_quote(get_futu_quote(normalized_symbol)), None
        except (FutuDependencyError, FutuOpenDError) as error:
            refresh_error = str(error)

    quotes = get_quotes([normalized_symbol])
    return (quotes[0] if quotes else None), refresh_error


def _load_quote_cached(
    symbol: str,
    *,
    refresh: bool,
    cache: dict[tuple[str, bool], tuple[QuoteSnapshot | None, str | None]] | None,
) -> tuple[QuoteSnapshot | None, str | None]:
    if cache is None:
        return _load_quote(symbol, refresh=refresh)
    key = (symbol.strip().upper(), refresh)
    if key not in cache:
        cache[key] = _load_quote(symbol, refresh=refresh)
    return cache[key]


def _previous_close_candles(
    candles: list[Candle],
    quote: QuoteSnapshot | None,
) -> list[Candle]:
    if quote is None:
        return candles
    signal_date = _quote_signal_date(quote)
    prior_candles = [
        candle for candle in candles if candle.time.date() < signal_date
    ]
    return prior_candles or candles


def _with_realtime_candle(
    candles: list[Candle],
    quote: QuoteSnapshot,
) -> list[Candle]:
    base_candles = _previous_close_candles(candles, quote)
    return [
        *base_candles,
        _quote_to_realtime_candle(quote),
    ]


def _quote_to_realtime_candle(quote: QuoteSnapshot) -> Candle:
    current = quote.current_price
    open_price = _first_positive([quote.open, quote.previous_close, current])
    price_range = [value for value in [quote.high, quote.low, open_price, current] if value > 0]
    high = max(price_range) if price_range else 0
    low = min(price_range) if price_range else 0
    return Candle(
        code=quote.code,
        market=quote.market,
        period="day",
        time=datetime.combine(_quote_signal_date(quote), time.min, timezone.utc),
        open=open_price,
        high=high,
        low=low,
        close=current,
        volume=quote.volume,
        turnover=quote.turnover,
    )


def _first_positive(values: list[float]) -> float:
    for value in values:
        if value > 0:
            return value
    return 0


def _intraday_signal_kind(quote: QuoteSnapshot) -> tuple[str, bool]:
    eastern_time = quote.quote_time.astimezone(_US_EASTERN)
    if eastern_time.weekday() < 5 and eastern_time.time() >= time(15, 50):
        return "strategy_signal", True
    return "intraday_estimate", False


def _quote_signal_date(quote: QuoteSnapshot) -> date:
    if quote.code.strip().upper().startswith("US."):
        return quote.quote_time.astimezone(_US_EASTERN).date()
    return quote.quote_time.date()


def _decision_from_replay(
    template: PersonalizedStrategyTemplate,
    replay: dict[str, Any],
    *,
    kind: str,
    title: str,
    is_realtime: bool,
    is_confirmed: bool,
    detail: dict[str, Any] | None = None,
) -> PersonalizedStrategyDecision:
    latest = replay["latest_candle"]
    latest_event = replay["latest_event"]
    current_position = replay["current_position"]
    if latest_event is not None and latest_event.event_date == latest.time.date():
        action = latest_event.action
        reason = latest_event.reason
        signal_date = latest_event.event_date
    elif current_position == "long":
        action = "hold_long"
        reason = "position_still_long"
        signal_date = replay["position_entry_date"]
    elif current_position == "short":
        action = "hold_short"
        reason = "position_still_short"
        signal_date = replay["position_entry_date"]
    else:
        action = "neutral"
        reason = "no_active_signal"
        signal_date = None

    decisions = _decision_texts(action)
    return PersonalizedStrategyDecision(
        kind=kind,
        title=title,
        action=action,
        action_label=_action_label(action),
        current_position=current_position,
        latest_date=latest.time.date(),
        latest_price=latest.close,
        signal_date=signal_date,
        reason=reason,
        flat_decision=decisions["flat"],
        long_decision=decisions["long"],
        short_decision=decisions["short"],
        is_realtime=is_realtime,
        is_confirmed=is_confirmed,
        detail={
            **(detail or {}),
            "template_code": template.code,
            "event_count": len(replay["events"]),
            "last_event": _event_to_detail(latest_event),
            "position_entry_date": replay["position_entry_date"].isoformat()
            if replay["position_entry_date"] is not None
            else None,
            "position_entry_price": replay["position_entry_price"],
            "position_hold_days": replay["position_hold_days"],
        },
    )


def _replay_strategy(
    config: dict[str, Any],
    candles: list[Candle],
    benchmark_candles: list[Candle],
) -> dict[str, Any]:
    benchmark_index_by_date = {
        candle.time.date(): index for index, candle in enumerate(benchmark_candles)
    }
    benchmark_closes = [candle.close for candle in benchmark_candles]
    closes = [candle.close for candle in candles]
    position: _Position | None = None
    events: list[_StrategyEvent] = []

    for index, candle in enumerate(candles):
        benchmark_index = benchmark_index_by_date.get(candle.time.date())
        if benchmark_index is None:
            continue

        if position is not None:
            position.hold_days += 1
            position.high_since_entry = max(position.high_since_entry, candle.high)
            position.low_since_entry = min(position.low_since_entry, candle.low)
            position.highest_close_since_entry = max(
                position.highest_close_since_entry,
                candle.close,
            )
            position.lowest_close_since_entry = min(
                position.lowest_close_since_entry,
                candle.close,
            )
            exit_reason = _exit_reason(
                config,
                candles,
                closes,
                benchmark_candles,
                benchmark_closes,
                index,
                benchmark_index,
                position,
            )
            if exit_reason is not None:
                action = "long_exit" if position.side == "long" else "short_exit"
                events.append(
                    _StrategyEvent(
                        event_date=candle.time.date(),
                        action=action,
                        price=candle.close,
                        reason=exit_reason,
                    )
                )
                position = None
                continue

        if position is None:
            entry_reason = _entry_reason(
                config,
                candles,
                closes,
                benchmark_candles,
                benchmark_closes,
                index,
                benchmark_index,
            )
            if entry_reason is None:
                continue
            side, reason = entry_reason
            position = _Position(
                side=side,
                entry_price=candle.close,
                entry_date=candle.time.date(),
                high_since_entry=candle.high,
                low_since_entry=candle.low,
                highest_close_since_entry=candle.close,
                lowest_close_since_entry=candle.close,
            )
            events.append(
                _StrategyEvent(
                    event_date=candle.time.date(),
                    action="long_entry" if side == "long" else "short_entry",
                    price=candle.close,
                    reason=reason,
                )
            )

    return {
        "events": events,
        "latest_event": events[-1] if events else None,
        "latest_candle": candles[-1],
        "current_position": position.side if position is not None else "flat",
        "position_entry_date": position.entry_date if position is not None else None,
        "position_entry_price": position.entry_price if position is not None else None,
        "position_hold_days": position.hold_days if position is not None else 0,
    }


def _entry_reason(
    config: dict[str, Any],
    candles: list[Candle],
    closes: list[float],
    benchmark_candles: list[Candle],
    benchmark_closes: list[float],
    index: int,
    benchmark_index: int,
) -> tuple[str, str] | None:
    params = {**config["parameters"], "_direction_mode": config.get("direction_mode")}
    engine = params["engine"]
    if engine == "ma_cross":
        return _ma_cross_entry_reason(
            params,
            candles,
            closes,
            benchmark_candles,
            benchmark_closes,
            index,
            benchmark_index,
        )
    if engine == "channel":
        return _channel_entry_reason(
            params,
            candles,
            closes,
            benchmark_candles,
            benchmark_closes,
            index,
            benchmark_index,
        )
    if engine == "price_ma":
        return _price_ma_entry_reason(
            params,
            candles,
            closes,
            benchmark_candles,
            benchmark_closes,
            index,
            benchmark_index,
        )
    return None


def _ma_cross_entry_reason(
    params: dict[str, Any],
    candles: list[Candle],
    closes: list[float],
    benchmark_candles: list[Candle],
    benchmark_closes: list[float],
    index: int,
    benchmark_index: int,
) -> tuple[str, str] | None:
    short_window = params["short_window"]
    long_window = params["long_window"]

    if _cross_above(closes, index, short_window, long_window) and _passes_long_filters(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        index,
        benchmark_index,
    ):
        return "long", "ma_cross_up_with_filters"
    if (
        params.get("_direction_mode") != "long_only"
        and _cross_below(closes, index, short_window, long_window)
        and _passes_short_filters(
            params,
            candles,
            closes,
            benchmark_candles,
            benchmark_closes,
            index,
            benchmark_index,
        )
    ):
        return "short", "ma_cross_down_with_filters"
    return None


def _channel_entry_reason(
    params: dict[str, Any],
    candles: list[Candle],
    closes: list[float],
    benchmark_candles: list[Candle],
    benchmark_closes: list[float],
    index: int,
    benchmark_index: int,
) -> tuple[str, str] | None:
    channel_days = params["entry_channel_days"]
    prior_high = _prior_high(candles, index, channel_days)
    prior_low = _prior_low(candles, index, channel_days)
    if prior_high is None or prior_low is None:
        return None

    close = candles[index].close
    if close > prior_high and _passes_long_filters(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        index,
        benchmark_index,
    ):
        return "long", "channel_breakout_with_filters"
    if (
        params.get("_direction_mode") != "long_only"
        and close < prior_low
        and _passes_short_filters(
            params,
            candles,
            closes,
            benchmark_candles,
            benchmark_closes,
            index,
            benchmark_index,
        )
    ):
        return "short", "channel_breakdown_with_filters"
    return None


def _price_ma_entry_reason(
    params: dict[str, Any],
    candles: list[Candle],
    closes: list[float],
    benchmark_candles: list[Candle],
    benchmark_closes: list[float],
    index: int,
    benchmark_index: int,
) -> tuple[str, str] | None:
    entry_ma = params["entry_ma"]
    ma_kind = params.get("entry_ma_kind", "sma")
    if _price_cross_above_ma(closes, index, entry_ma, ma_kind) and _passes_long_filters(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        index,
        benchmark_index,
    ):
        return "long", "price_ma_cross_up_with_filters"
    if (
        params.get("_direction_mode") != "long_only"
        and _price_cross_below_ma(closes, index, entry_ma, ma_kind)
        and _passes_short_filters(
            params,
            candles,
            closes,
            benchmark_candles,
            benchmark_closes,
            index,
            benchmark_index,
        )
    ):
        return "short", "price_ma_cross_down_with_filters"
    return None


def _passes_long_filters(
    params: dict[str, Any],
    candles: list[Candle],
    closes: list[float],
    benchmark_candles: list[Candle],
    benchmark_closes: list[float],
    index: int,
    benchmark_index: int,
) -> bool:
    close = candles[index].close
    trend_ma = params.get("trend_ma")
    if trend_ma is not None:
        value = _ma(closes, index, trend_ma, params.get("trend_ma_kind", "sma"))
        if value is None or close <= value:
            return False

    benchmark_ma = params.get("benchmark_ma")
    if benchmark_ma is not None:
        value = _ma(
            benchmark_closes,
            benchmark_index,
            benchmark_ma,
            params.get("benchmark_ma_kind", "sma"),
        )
        if value is None or benchmark_candles[benchmark_index].close <= value:
            return False

    benchmark_roc_days = params.get("benchmark_roc_days")
    if benchmark_roc_days is not None:
        value = _roc(benchmark_closes, benchmark_index, benchmark_roc_days)
        if value is None or value <= params.get("benchmark_roc_min", 0):
            return False

    own_roc_days = params.get("own_roc_days")
    if own_roc_days is not None:
        value = _roc(closes, index, own_roc_days)
        if value is None or value <= params.get("own_roc_min", 0):
            return False

    relative_days = params.get("relative_strength_days")
    if relative_days is not None:
        own_value = _roc(closes, index, relative_days)
        benchmark_value = _roc(benchmark_closes, benchmark_index, relative_days)
        if own_value is None or benchmark_value is None:
            return False
        minimum_spread = params.get("relative_strength_min", 0)
        if own_value - benchmark_value <= minimum_spread:
            return False

    own_slope_days = params.get("own_slope_days", params.get("qqq_slope_days"))
    if own_slope_days is not None:
        value = _linear_regression_slope(closes, index, own_slope_days)
        if value is None or value < params.get("own_slope_min", params.get("qqq_slope_min", 0)):
            return False

    benchmark_slope_days = params.get("benchmark_slope_days")
    if benchmark_slope_days is not None:
        value = _linear_regression_slope(
            benchmark_closes,
            benchmark_index,
            benchmark_slope_days,
        )
        if value is None or value < params.get("benchmark_slope_min", 0):
            return False

    if not _passes_atr_pct_filter(params, candles, index):
        return False

    if not _passes_realized_vol_filter(params, closes, index):
        return False

    if not _passes_volume_filter(params, candles, index):
        return False

    return True


def _passes_short_filters(
    params: dict[str, Any],
    candles: list[Candle],
    closes: list[float],
    benchmark_candles: list[Candle],
    benchmark_closes: list[float],
    index: int,
    benchmark_index: int,
) -> bool:
    close = candles[index].close
    trend_ma = params.get("trend_ma")
    if trend_ma is not None:
        value = _ma(closes, index, trend_ma, params.get("trend_ma_kind", "sma"))
        if value is None or close >= value:
            return False

    benchmark_ma = params.get("benchmark_ma")
    if benchmark_ma is not None:
        value = _ma(
            benchmark_closes,
            benchmark_index,
            benchmark_ma,
            params.get("benchmark_ma_kind", "sma"),
        )
        if value is None or benchmark_candles[benchmark_index].close >= value:
            return False

    benchmark_roc_days = params.get("benchmark_roc_days")
    if benchmark_roc_days is not None:
        value = _roc(benchmark_closes, benchmark_index, benchmark_roc_days)
        if value is None or value >= -params.get("benchmark_roc_min", 0):
            return False

    own_roc_days = params.get("own_roc_days")
    if own_roc_days is not None:
        value = _roc(closes, index, own_roc_days)
        if value is None or value >= -params.get("own_roc_min", 0):
            return False

    relative_days = params.get("relative_strength_days")
    if relative_days is not None:
        own_value = _roc(closes, index, relative_days)
        benchmark_value = _roc(benchmark_closes, benchmark_index, relative_days)
        if own_value is None or benchmark_value is None:
            return False
        minimum_spread = params.get("relative_strength_min", 0)
        if own_value - benchmark_value >= -minimum_spread:
            return False

    own_slope_days = params.get("own_slope_days", params.get("qqq_slope_days"))
    if own_slope_days is not None:
        value = _linear_regression_slope(closes, index, own_slope_days)
        if value is None or value > -params.get("own_slope_min", params.get("qqq_slope_min", 0)):
            return False

    benchmark_slope_days = params.get("benchmark_slope_days")
    if benchmark_slope_days is not None:
        value = _linear_regression_slope(
            benchmark_closes,
            benchmark_index,
            benchmark_slope_days,
        )
        if value is None or value > -params.get("benchmark_slope_min", 0):
            return False

    if not _passes_atr_pct_filter(params, candles, index):
        return False

    if not _passes_realized_vol_filter(params, closes, index):
        return False

    if not _passes_volume_filter(params, candles, index):
        return False

    return True


def _exit_reason(
    config: dict[str, Any],
    candles: list[Candle],
    closes: list[float],
    benchmark_candles: list[Candle],
    benchmark_closes: list[float],
    index: int,
    benchmark_index: int,
    position: _Position,
) -> str | None:
    params = config["parameters"]
    close = candles[index].close
    if params["engine"] == "ma_cross" and params.get("reverse_exit", True):
        if params.get("filtered_reverse_exit"):
            reverse_entry = _ma_cross_entry_reason(
                params,
                candles,
                closes,
                benchmark_candles,
                benchmark_closes,
                index,
                benchmark_index,
            )
            reverse = reverse_entry is not None and reverse_entry[0] != position.side
        else:
            reverse = (
                _cross_below(closes, index, params["short_window"], params["long_window"])
                if position.side == "long"
                else _cross_above(
                    closes,
                    index,
                    params["short_window"],
                    params["long_window"],
                )
            )
        if reverse:
            return "reverse_ma_cross"

    if (
        params["engine"] == "channel"
        and params.get("reverse_exit", True)
        and "filtered_reverse_exit" in params
    ):
        if params.get("filtered_reverse_exit"):
            reverse_entry = _channel_entry_reason(
                params,
                candles,
                closes,
                benchmark_candles,
                benchmark_closes,
                index,
                benchmark_index,
            )
            reverse = reverse_entry is not None and reverse_entry[0] != position.side
            if reverse:
                return (
                    "reverse_channel_breakdown"
                    if position.side == "long"
                    else "reverse_channel_breakout"
                )
        else:
            entry_channel_days = params.get("entry_channel_days")
            if entry_channel_days is not None:
                prior_high = _prior_high(candles, index, entry_channel_days)
                prior_low = _prior_low(candles, index, entry_channel_days)
                if position.side == "long" and prior_low is not None and close < prior_low:
                    return "reverse_channel_breakdown"
                if position.side == "short" and prior_high is not None and close > prior_high:
                    return "reverse_channel_breakout"

    if params["engine"] == "price_ma" and params.get("reverse_exit", True):
        entry_ma = params["entry_ma"]
        ma_kind = params.get("entry_ma_kind", "sma")
        if params.get("filtered_reverse_exit"):
            reverse_entry = _price_ma_entry_reason(
                params,
                candles,
                closes,
                benchmark_candles,
                benchmark_closes,
                index,
                benchmark_index,
            )
            reverse = reverse_entry is not None and reverse_entry[0] != position.side
        else:
            reverse = (
                _price_cross_below_ma(closes, index, entry_ma, ma_kind)
                if position.side == "long"
                else _price_cross_above_ma(closes, index, entry_ma, ma_kind)
            )
        if reverse:
            return "reverse_price_ma"

    exit_channel_days = params.get("exit_channel_days")
    if exit_channel_days is not None:
        prior_high = _prior_high(candles, index, exit_channel_days)
        prior_low = _prior_low(candles, index, exit_channel_days)
        if position.side == "long" and prior_low is not None and close < prior_low:
            return "reverse_channel_breakdown"
        if position.side == "short" and prior_high is not None and close > prior_high:
            return "reverse_channel_breakout"

    exit_ma = params.get("exit_ma")
    if exit_ma is None and params.get("use_trend_ma_as_exit", True):
        exit_ma = params.get("trend_ma")
    if exit_ma is not None:
        value = _ma(closes, index, exit_ma, params.get("exit_ma_kind", "sma"))
        if value is not None:
            if position.side == "long" and close < value:
                return "price_below_exit_ma"
            if position.side == "short" and close > value:
                return "price_above_exit_ma"

    fixed_stop = params.get("fixed_stop")
    if fixed_stop is not None:
        if position.side == "long" and close <= position.entry_price * (1 - fixed_stop):
            return "fixed_stop"
        if position.side == "short" and close >= position.entry_price * (1 + fixed_stop):
            return "fixed_stop"

    trailing_stop = params.get("trailing_stop")
    if trailing_stop is not None:
        if position.side == "long" and close <= position.high_since_entry * (1 - trailing_stop):
            return "trailing_stop"
        if position.side == "short" and close >= position.low_since_entry * (1 + trailing_stop):
            return "trailing_stop"

    take_profit = params.get("take_profit")
    if take_profit is not None:
        if position.side == "long" and close >= position.entry_price * (1 + take_profit):
            return "take_profit"
        if position.side == "short" and close <= position.entry_price * (1 - take_profit):
            return "take_profit"

    atr_days = params.get("atr_days")
    atr_value = _atr(candles, index, atr_days) if atr_days is not None else None
    if atr_value is not None:
        atr_stop_mult = params.get("atr_stop_mult")
        if atr_stop_mult is not None:
            if position.side == "long" and close <= position.entry_price - atr_stop_mult * atr_value:
                return "atr_stop"
            if position.side == "short" and close >= position.entry_price + atr_stop_mult * atr_value:
                return "atr_stop"

        atr_trail_mult = params.get("atr_trail_mult")
        if atr_trail_mult is not None:
            if (
                position.side == "long"
                and close <= position.highest_close_since_entry - atr_trail_mult * atr_value
            ):
                return "atr_trailing_stop"
            if (
                position.side == "short"
                and close >= position.lowest_close_since_entry + atr_trail_mult * atr_value
            ):
                return "atr_trailing_stop"

    max_hold_days = params.get("max_hold_days")
    if max_hold_days is not None and position.hold_days >= max_hold_days:
        return "max_hold_days"

    return None


def _ma(
    values: list[float],
    index: int,
    window: int,
    kind: str | None = "sma",
) -> float | None:
    if str(kind).lower() == "ema":
        return _ema(values, index, window)
    return _sma(values, index, window)


def _sma(values: list[float], index: int, window: int) -> float | None:
    if window <= 0 or index + 1 < window:
        return None
    window_values = values[index - window + 1 : index + 1]
    return sum(window_values) / window


def _ema(values: list[float], index: int, window: int) -> float | None:
    if window <= 0 or index + 1 < window:
        return None
    ema_value = sum(values[:window]) / window
    alpha = 2 / (window + 1)
    for value in values[window : index + 1]:
        ema_value = alpha * value + (1 - alpha) * ema_value
    return ema_value


def _roc(values: list[float], index: int, window: int) -> float | None:
    if window <= 0 or index < window:
        return None
    base = values[index - window]
    if base == 0:
        return None
    return values[index] / base - 1


def _cross_above(values: list[float], index: int, short_window: int, long_window: int) -> bool:
    if index <= 0:
        return False
    current_short = _sma(values, index, short_window)
    current_long = _sma(values, index, long_window)
    previous_short = _sma(values, index - 1, short_window)
    previous_long = _sma(values, index - 1, long_window)
    if None in {current_short, current_long, previous_short, previous_long}:
        return False
    return previous_short <= previous_long and current_short > current_long


def _cross_below(values: list[float], index: int, short_window: int, long_window: int) -> bool:
    if index <= 0:
        return False
    current_short = _sma(values, index, short_window)
    current_long = _sma(values, index, long_window)
    previous_short = _sma(values, index - 1, short_window)
    previous_long = _sma(values, index - 1, long_window)
    if None in {current_short, current_long, previous_short, previous_long}:
        return False
    return previous_short >= previous_long and current_short < current_long


def _price_cross_above_ma(
    values: list[float],
    index: int,
    window: int,
    kind: str | None = "sma",
) -> bool:
    if index <= 0:
        return False
    current_ma = _ma(values, index, window, kind)
    previous_ma = _ma(values, index - 1, window, kind)
    if current_ma is None or previous_ma is None:
        return False
    return values[index - 1] <= previous_ma and values[index] > current_ma


def _price_cross_below_ma(
    values: list[float],
    index: int,
    window: int,
    kind: str | None = "sma",
) -> bool:
    if index <= 0:
        return False
    current_ma = _ma(values, index, window, kind)
    previous_ma = _ma(values, index - 1, window, kind)
    if current_ma is None or previous_ma is None:
        return False
    return values[index - 1] >= previous_ma and values[index] < current_ma


def _prior_high(candles: list[Candle], index: int, window: int) -> float | None:
    if window <= 0 or index < window:
        return None
    return max(candle.high for candle in candles[index - window : index])


def _prior_low(candles: list[Candle], index: int, window: int) -> float | None:
    if window <= 0 or index < window:
        return None
    return min(candle.low for candle in candles[index - window : index])


def _linear_regression_slope(
    values: list[float],
    index: int,
    window: int,
) -> float | None:
    if window <= 1 or index + 1 < window:
        return None
    sample = values[index - window + 1 : index + 1]
    base = sample[-1]
    if base == 0:
        return None
    x_values = [item - (window - 1) / 2 for item in range(window)]
    y_mean = sum(sample) / window
    denominator = sum(item * item for item in x_values)
    if denominator == 0:
        return None
    slope = sum(x * (y - y_mean) for x, y in zip(x_values, sample)) / denominator
    return slope / base


def _true_range(candles: list[Candle], index: int) -> float:
    candle = candles[index]
    if index == 0:
        return candle.high - candle.low
    previous_close = candles[index - 1].close
    return max(
        candle.high - candle.low,
        abs(candle.high - previous_close),
        abs(candle.low - previous_close),
    )


def _atr(candles: list[Candle], index: int, window: int | None) -> float | None:
    if window is None or window <= 0 or index + 1 < window:
        return None
    ranges = [_true_range(candles, item) for item in range(index - window + 1, index + 1)]
    return sum(ranges) / window


def _passes_atr_pct_filter(
    params: dict[str, Any],
    candles: list[Candle],
    index: int,
) -> bool:
    atr_pct_min = params.get("atr_pct_min")
    atr_pct_max = params.get("atr_pct_max")
    if atr_pct_min is None and atr_pct_max is None:
        return True
    atr_value = _atr(candles, index, params.get("atr_days"))
    close = candles[index].close
    if atr_value is None or close == 0:
        return False
    atr_pct = atr_value / close
    if atr_pct_min is not None and atr_pct < atr_pct_min:
        return False
    if atr_pct_max is not None and atr_pct > atr_pct_max:
        return False
    return True


def _realized_vol(values: list[float], index: int, window: int | None) -> float | None:
    if window is None or window <= 0 or index < window:
        return None
    returns: list[float] = []
    for item in range(index - window + 1, index + 1):
        previous = values[item - 1]
        if previous == 0:
            return None
        returns.append(values[item] / previous - 1)
    mean = sum(returns) / window
    variance = sum((item - mean) ** 2 for item in returns) / window
    return math.sqrt(variance) * math.sqrt(252)


def _passes_realized_vol_filter(
    params: dict[str, Any],
    closes: list[float],
    index: int,
) -> bool:
    realized_vol_min = params.get("realized_vol_min")
    realized_vol_max = params.get("realized_vol_max")
    if realized_vol_min is None and realized_vol_max is None:
        return True
    value = _realized_vol(closes, index, params.get("realized_vol_days"))
    if value is None:
        return False
    if realized_vol_min is not None and value < realized_vol_min:
        return False
    if realized_vol_max is not None and value > realized_vol_max:
        return False
    return True


def _passes_volume_filter(
    params: dict[str, Any],
    candles: list[Candle],
    index: int,
) -> bool:
    volume_window = params.get("volume_window")
    volume_ratio_min = params.get("volume_ratio_min")
    if volume_window is None or volume_ratio_min is None:
        return True
    if volume_window <= 0 or index + 1 < volume_window:
        return False
    volume_avg = (
        sum(candle.volume for candle in candles[index - volume_window + 1 : index + 1])
        / volume_window
    )
    if volume_avg <= 0:
        return False
    return candles[index].volume / volume_avg >= volume_ratio_min


def _minimum_candle_count(config: dict[str, Any]) -> int:
    params = config["parameters"]
    windows = [
        value
        for key, value in params.items()
        if isinstance(value, int) and key.endswith(("days", "window", "ma"))
    ]
    return max(windows + [120]) + 5


def _minimum_benchmark_count(config: dict[str, Any]) -> int:
    params = config["parameters"]
    windows = [
        params.get("benchmark_ma", 0),
        params.get("benchmark_roc_days", 0),
        params.get("benchmark_slope_days", 0),
        params.get("relative_strength_days", 0),
    ]
    return max([value for value in windows if isinstance(value, int)] + [120]) + 5


def _merge_errors(first: str | None, second: str | None) -> str | None:
    errors = [item for item in [first, second] if item]
    return " | ".join(errors) if errors else None


def _event_to_detail(event: _StrategyEvent | None) -> dict[str, Any] | None:
    if event is None:
        return None
    return {
        "date": event.event_date.isoformat(),
        "action": event.action,
        "price": event.price,
        "reason": event.reason,
    }


def _decision_texts(action: str) -> dict[str, str]:
    return {
        "long_entry": {
            "flat": "可关注做多",
            "long": "继续持有，可观察加仓",
            "short": "平空观察，谨慎反手做多",
        },
        "short_entry": {
            "flat": "可关注做空",
            "long": "减仓或平多观察",
            "short": "继续持空，可观察加仓",
        },
        "long_exit": {
            "flat": "等待，不追多",
            "long": "退出或减仓观察",
            "short": "继续观察空头机会",
        },
        "short_exit": {
            "flat": "等待，不追空",
            "long": "继续观察多头机会",
            "short": "平空观察",
        },
        "hold_long": {
            "flat": "买点已过，等待新信号",
            "long": "继续持有多头",
            "short": "不宜继续持空",
        },
        "hold_short": {
            "flat": "做空点已过，等待新信号",
            "long": "不宜继续持多",
            "short": "继续持有空头",
        },
        "neutral": {
            "flat": "等待",
            "long": "暂无退出信号，按成本/止损管理",
            "short": "暂无平空信号，按成本/止损管理",
        },
        "failed": {
            "flat": "不参考",
            "long": "不参考",
            "short": "不参考",
        },
    }.get(
        action,
        {
            "flat": "等待",
            "long": "暂无退出信号，按成本/止损管理",
            "short": "暂无平空信号，按成本/止损管理",
        },
    )


def _action_label(action: str) -> str:
    return {
        "long_entry": "做多观察",
        "short_entry": "做空观察",
        "long_exit": "多头退出观察",
        "short_exit": "空头退出观察",
        "hold_long": "持有多头",
        "hold_short": "持有空头",
        "neutral": "无信号",
        "failed": "扫描失败",
    }.get(action, action)


_TEMPLATES: list[dict[str, Any]] = [
    {
        "code": "personal_chinalife_hk_channel67_steady",
        "symbol": "HK.02628",
        "name": "中国人寿 67/42 通道稳健型",
        "description": "中国人寿港股稳健型专属模板，使用 67 日通道突破，叠加自身 EMA80、恒生 EMA200/动量、相对恒生强弱、ATR% 过滤、SMA100 退出、12% 止盈和 80 日最长持仓。",
        "benchmark_symbol": "HK.800000",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 67,
            "exit_channel_days": 42,
            "trend_ma": 80,
            "trend_ma_kind": "ema",
            "benchmark_ma": 200,
            "benchmark_ma_kind": "ema",
            "benchmark_roc_days": 80,
            "benchmark_roc_min": 0.02,
            "own_roc_days": 40,
            "own_roc_min": 0.08,
            "relative_strength_days": 20,
            "relative_strength_min": 0.02,
            "atr_days": 14,
            "atr_pct_max": 0.035,
            "exit_ma": 100,
            "exit_ma_kind": "sma",
            "take_profit": 0.12,
            "max_hold_days": 80,
        },
        "entry_rules": [
            "做多：中国人寿收盘价突破过去 67 日高点，且中国人寿高于 EMA80。",
            "恒生指数高于 EMA200，恒生 80 日动量大于 2%，中国人寿 40 日动量大于 8%，且 20 日相对恒生强弱大于 2%。",
            "ATR14/收盘价不高于 3.5%；做空为对称条件：跌破过去 67 日低点，趋势、恒生过滤、动量和相对强弱均转弱。",
        ],
        "exit_rules": [
            "反向 42 日通道突破，或价格跌破/站回 SMA100。",
            "单笔达到 12% 止盈，或虚拟持仓满 80 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.2470,
                "max_drawdown": -0.0476,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1172,
                "max_drawdown": -0.0430,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.2835,
                "max_drawdown": -0.0313,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.4802,
                "max_drawdown": -0.0855,
                "win_rate": 1.0,
                "round_trip_count": 4,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 5),
                "total_return": 0.1094,
                "max_drawdown": -0.0557,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_chinalife_hk_channel72_aggressive",
        "symbol": "HK.02628",
        "name": "中国人寿 72/54 通道进取型",
        "description": "中国人寿港股进取型专属模板，使用 72 日通道突破，叠加自身 EMA100、恒生 80 日动量、相对恒生强弱、ATR% 过滤、SMA80 退出、12% 止损/止盈和 18% 移动止损。",
        "benchmark_symbol": "HK.800000",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 72,
            "exit_channel_days": 54,
            "trend_ma": 100,
            "trend_ma_kind": "ema",
            "benchmark_roc_days": 80,
            "benchmark_roc_min": 0.02,
            "own_roc_days": 40,
            "own_roc_min": 0.08,
            "relative_strength_days": 40,
            "relative_strength_min": 0.0,
            "atr_days": 20,
            "atr_pct_max": 0.035,
            "exit_ma": 80,
            "exit_ma_kind": "sma",
            "fixed_stop": 0.12,
            "trailing_stop": 0.18,
            "take_profit": 0.12,
        },
        "entry_rules": [
            "做多：中国人寿收盘价突破过去 72 日高点，且中国人寿高于 EMA100。",
            "恒生 80 日动量大于 2%，中国人寿 40 日动量大于 8%，且中国人寿 40 日相对恒生强弱大于 0。",
            "ATR20/收盘价不高于 3.5%；做空为对称条件：跌破过去 72 日低点，趋势、恒生动量和相对强弱均转弱。",
        ],
        "exit_rules": [
            "反向 54 日通道突破，或价格跌破/站回 SMA80。",
            "固定止损 12%，移动止损 18%，或单笔达到 12% 止盈。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1867,
                "max_drawdown": -0.0448,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1172,
                "max_drawdown": -0.0430,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.5842,
                "max_drawdown": -0.0313,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.4468,
                "max_drawdown": -0.0754,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 5),
                "total_return": 0.1094,
                "max_drawdown": -0.0557,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_icbc_hk_price_ema30_steady",
        "symbol": "HK.01398",
        "name": "工商银行 EMA30 价格突破稳健型",
        "description": "工商银行港股稳健型 Top2 模板，使用收盘价上穿/下穿 EMA30，叠加工商银行自身 SMA80、恒生 EMA200、恒生 40 日动量和相对恒生强弱过滤，仅用 12% 止盈退出。",
        "benchmark_symbol": "HK.800000",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "price_ma",
            "entry_ma": 30,
            "entry_ma_kind": "ema",
            "trend_ma": 80,
            "trend_ma_kind": "sma",
            "benchmark_ma": 200,
            "benchmark_ma_kind": "ema",
            "benchmark_roc_days": 40,
            "benchmark_roc_min": -0.10,
            "relative_strength_days": 20,
            "relative_strength_min": 0.03,
            "take_profit": 0.12,
            "reverse_exit": False,
            "use_trend_ma_as_exit": False,
        },
        "entry_rules": [
            "做多：工商银行收盘价上穿 EMA30，且工商银行高于 SMA80。",
            "恒生指数高于 EMA200，恒生 40 日动量大于 -10%，且工商银行 20 日相对恒生强弱大于 3%。",
            "做空为对称条件：收盘价下穿 EMA30，工商银行低于 SMA80，恒生低于 EMA200，且相对恒生强弱转弱。",
        ],
        "exit_rules": [
            "不使用反向 EMA30 穿越退出，也不把 SMA80 入场过滤当作退出均线。",
            "单笔达到 12% 止盈时退出；区间结束仍持仓则按最后收盘价强制平仓。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1287,
                "max_drawdown": -0.0710,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1225,
                "max_drawdown": -0.0715,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.2745,
                "max_drawdown": -0.0830,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.1166,
                "max_drawdown": -0.0570,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 5),
                "total_return": 0.1232,
                "max_drawdown": -0.0396,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_icbc_hk_price_ema10_aggressive",
        "symbol": "HK.01398",
        "name": "工商银行 EMA10 价格突破进取型",
        "description": "工商银行港股进取型 Top2 模板，使用收盘价上穿/下穿 EMA10，叠加工商银行自身 EMA50、ROC20、相对恒生 ROC80 和 40 日年化波动率过滤，保留 18% 止盈与 95 日最长持仓。",
        "benchmark_symbol": "HK.800000",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "price_ma",
            "entry_ma": 10,
            "entry_ma_kind": "ema",
            "trend_ma": 50,
            "trend_ma_kind": "ema",
            "own_roc_days": 20,
            "own_roc_min": 0.0,
            "relative_strength_days": 80,
            "relative_strength_min": 0.0,
            "realized_vol_days": 40,
            "realized_vol_max": 0.36,
            "take_profit": 0.18,
            "max_hold_days": 95,
            "reverse_exit": False,
            "use_trend_ma_as_exit": False,
        },
        "entry_rules": [
            "做多：工商银行收盘价上穿 EMA10，且工商银行高于 EMA50，20 日动量大于 0。",
            "工商银行 80 日相对恒生强弱大于 0，且 40 日年化历史波动率不高于 36%。",
            "做空为对称条件：收盘价下穿 EMA10，工商银行低于 EMA50，20 日动量小于 0，且相对恒生强弱转弱。",
        ],
        "exit_rules": [
            "不使用反向 EMA10 穿越退出，也不把 EMA50 入场过滤当作退出均线。",
            "单笔达到 18% 止盈，或虚拟持仓满 95 个交易日时退出。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1270,
                "max_drawdown": -0.1637,
                "win_rate": 0.5,
                "round_trip_count": 2,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1818,
                "max_drawdown": -0.1974,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.2560,
                "max_drawdown": -0.1636,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.4099,
                "max_drawdown": -0.1337,
                "win_rate": 0.75,
                "round_trip_count": 4,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 5),
                "total_return": 0.1120,
                "max_drawdown": -0.0673,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_alibaba_hk_price_sma30_steady",
        "symbol": "HK.09988",
        "name": "阿里巴巴 SMA30 价格突破稳健型",
        "description": "阿里巴巴港股稳健型专属模板，使用收盘价上穿/下穿 SMA30，叠加自身 ROC20 与 20 日价格斜率过滤，使用合格反向信号、15% 固定止损、12% 止盈和 69 日最长持仓退出。本稳健型按允许放宽到 18% 最大回撤的口径写入。",
        "benchmark_symbol": "HK.800000",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "price_ma",
            "entry_ma": 30,
            "entry_ma_kind": "sma",
            "own_roc_days": 20,
            "own_roc_min": 0.02,
            "own_slope_days": 20,
            "own_slope_min": 0.002,
            "fixed_stop": 0.15,
            "take_profit": 0.12,
            "max_hold_days": 69,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：阿里巴巴收盘价上穿 SMA30，且阿里巴巴 20 日动量大于 2%，20 日价格斜率不低于 0.2%。",
            "做空为对称条件：阿里巴巴收盘价下穿 SMA30，且 20 日动量小于 -2%，20 日价格斜率不高于 -0.2%。",
            "本策略最终未使用恒生趋势/动量过滤；恒生指数仅作为港股基准和扫描配套数据。",
        ],
        "exit_rules": [
            "出现合格反向 SMA30 价格穿越信号。",
            "固定止损 15%，止盈 12%，或虚拟持仓满 69 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1445,
                "max_drawdown": -0.1737,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.2382,
                "max_drawdown": -0.0459,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1173,
                "max_drawdown": -0.1410,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.3016,
                "max_drawdown": -0.0749,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 5),
                "total_return": 0.1279,
                "max_drawdown": -0.1419,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
        ],
    },
    {
        "code": "personal_alibaba_hk_price_sma30_aggressive",
        "symbol": "HK.09988",
        "name": "阿里巴巴 SMA30 价格突破进取型",
        "description": "阿里巴巴港股进取型专属模板，使用收盘价上穿/下穿 SMA30，叠加自身 ROC20 与 20 日价格斜率过滤，使用合格反向信号、15% 固定止损、12% 止盈和 69 日最长持仓退出。",
        "benchmark_symbol": "HK.800000",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "price_ma",
            "entry_ma": 30,
            "entry_ma_kind": "sma",
            "own_roc_days": 20,
            "own_roc_min": 0.02,
            "own_slope_days": 20,
            "own_slope_min": 0.002,
            "fixed_stop": 0.15,
            "take_profit": 0.12,
            "max_hold_days": 69,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：阿里巴巴收盘价上穿 SMA30，且阿里巴巴 20 日动量大于 2%，20 日价格斜率不低于 0.2%。",
            "做空为对称条件：阿里巴巴收盘价下穿 SMA30，且 20 日动量小于 -2%，20 日价格斜率不高于 -0.2%。",
            "本策略最终未使用恒生趋势/动量过滤；恒生指数仅作为港股基准和扫描配套数据。",
        ],
        "exit_rules": [
            "出现合格反向 SMA30 价格穿越信号。",
            "固定止损 15%，止盈 12%，或虚拟持仓满 69 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1445,
                "max_drawdown": -0.1737,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.2382,
                "max_drawdown": -0.0459,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1173,
                "max_drawdown": -0.1410,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.3016,
                "max_drawdown": -0.0749,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 5),
                "total_return": 0.1279,
                "max_drawdown": -0.1419,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
        ],
    },
    {
        "code": "personal_googl_sma5_113_aggressive",
        "symbol": "US.GOOGL",
        "name": "GOOGL SMA5/116 样本增强进取型",
        "description": "适合 GOOGL 的进取型均线交叉策略，叠加自身 SMA100、QQQ SMA200 与 QQQ 120 日动量过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 5,
            "long_window": 116,
            "trend_ma": 100,
            "benchmark_ma": 200,
            "benchmark_roc_days": 120,
            "benchmark_roc_min": -0.02,
            "fixed_stop": 0.06,
            "trailing_stop": 0.16,
            "take_profit": 0.24,
            "max_hold_days": 60,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：SMA5 上穿 SMA116，且 GOOGL 高于 SMA100，QQQ 高于 SMA200。",
            "QQQ 120 日动量大于 -2%，做空为对称条件：SMA5 下穿 SMA116，趋势与 QQQ 动量均转弱。",
        ],
        "exit_rules": [
            "出现合格反向均线交叉信号。",
            "固定止损 6%，移动止损 16%，止盈 24%，或虚拟持仓满 60 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.4481,
                "max_drawdown": -0.0745,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.3134,
                "max_drawdown": -0.0666,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.3736,
                "max_drawdown": -0.0928,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.2300,
                "max_drawdown": -0.0662,
                "win_rate": 0.5,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1461,
                "max_drawdown": -0.1459,
                "win_rate": 0.5,
                "round_trip_count": 2,
            },
        ],
    },
    {
        "code": "personal_googl_sma5_113_steady",
        "symbol": "US.GOOGL",
        "name": "GOOGL SMA5/113 相对强弱（稳健型）",
        "description": "适合 GOOGL 的稳健型均线交叉策略，叠加自身 SMA100、QQQ SMA120、80 日动量和相对 QQQ 强弱过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 5,
            "long_window": 113,
            "trend_ma": 100,
            "benchmark_ma": 120,
            "own_roc_days": 80,
            "own_roc_min": 0.02,
            "relative_strength_days": 20,
            "relative_strength_min": -0.08,
            "exit_ma": 150,
            "fixed_stop": 0.12,
            "trailing_stop": 0.10,
            "take_profit": 0.20,
            "max_hold_days": 40,
        },
        "entry_rules": [
            "做多：SMA5 上穿 SMA113，且 GOOGL 高于 SMA100，QQQ 高于 SMA120。",
            "GOOGL 80 日动量大于 2%，且 GOOGL 20 日相对 QQQ 强弱不弱于 -8%。",
            "做空为对称条件：SMA5 下穿 SMA113，趋势、动量与相对强弱均转弱。",
        ],
        "exit_rules": [
            "反向均线交叉，或跌破/站回 SMA150。",
            "固定止损 12%，移动止损 10%，止盈 20%，或虚拟持仓满 40 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.2249,
                "max_drawdown": -0.0517,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.2227,
                "max_drawdown": -0.0667,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.3016,
                "max_drawdown": -0.0421,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.1437,
                "max_drawdown": -0.0377,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.2172,
                "max_drawdown": -0.0275,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
        ],
    },
    {
        "code": "personal_qqq_sma7_111_steady",
        "symbol": "US.QQQ",
        "name": "QQQ SMA7/111 稳健型",
        "description": "QQQ 稳健型专属模板，使用 SMA7/111 多空交叉，叠加 QQQ SMA120、20 日动量、SMA150 退出线、10% 止损/移动止损和 14% 止盈。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 7,
            "long_window": 111,
            "benchmark_ma": 120,
            "own_roc_days": 20,
            "own_roc_min": 0.02,
            "exit_ma": 150,
            "fixed_stop": 0.10,
            "trailing_stop": 0.10,
            "take_profit": 0.14,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：SMA7 上穿 SMA111，且 QQQ 高于 SMA120。",
            "QQQ 20 日动量大于 2%。",
            "做空为对称条件：SMA7 下穿 SMA111，且 QQQ 低于 SMA120，QQQ 20 日动量低于 -2%。",
        ],
        "exit_rules": [
            "出现合格反向 SMA7/SMA111 均线交叉信号，或跌破/站回 SMA150。",
            "固定止损 10%，移动止损 10%，止盈 14%。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1621,
                "max_drawdown": -0.0681,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1563,
                "max_drawdown": -0.0743,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1292,
                "max_drawdown": -0.0342,
                "win_rate": 0.5,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.1457,
                "max_drawdown": -0.0294,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1423,
                "max_drawdown": -0.0254,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_qqq_sma12_101_aggressive",
        "symbol": "US.QQQ",
        "name": "QQQ SMA12/101 进取型",
        "description": "QQQ 进取型专属模板，使用 SMA12/101 多空交叉，叠加 QQQ 自身 SMA50/SMA150、80 日动量和 12% 止盈。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 12,
            "long_window": 101,
            "trend_ma": 50,
            "benchmark_ma": 150,
            "own_roc_days": 80,
            "own_roc_min": -0.12,
            "take_profit": 0.12,
            "filtered_reverse_exit": True,
            "use_trend_ma_as_exit": False,
        },
        "entry_rules": [
            "做多：SMA12 上穿 SMA101，且 QQQ 高于 SMA50 与 SMA150。",
            "QQQ 80 日动量大于 -12%。",
            "做空为对称条件：SMA12 下穿 SMA101，且 QQQ 低于 SMA50 与 SMA150，QQQ 80 日动量低于 12%。",
        ],
        "exit_rules": [
            "出现合格反向 SMA12/SMA101 均线交叉信号。",
            "止盈 12%；不启用固定止损、移动止损、退出均线或最大持仓天数。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.2660,
                "max_drawdown": -0.1337,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1824,
                "max_drawdown": -0.0743,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.2523,
                "max_drawdown": -0.0701,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.3071,
                "max_drawdown": -0.0512,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1268,
                "max_drawdown": -0.0254,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_nvda_channel35",
        "symbol": "US.NVDA",
        "name": "NVDA 15日通道 ATR 趋势突破（进取型）",
        "description": "适合 NVDA 的进取型通道突破策略，叠加 EMA80、QQQ 动量、相对强弱、斜率、ATR% 与 ATR 止损过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 15,
            "exit_channel_days": 57,
            "benchmark_ma": 80,
            "benchmark_ma_kind": "ema",
            "benchmark_roc_days": 60,
            "benchmark_roc_min": 0.02,
            "own_roc_days": 80,
            "own_roc_min": -0.08,
            "relative_strength_days": 80,
            "relative_strength_min": 0.0,
            "own_slope_days": 20,
            "own_slope_min": 0.0015,
            "benchmark_slope_days": 20,
            "benchmark_slope_min": 0.0005,
            "atr_days": 50,
            "atr_pct_min": 0.01,
            "atr_pct_max": 0.06,
            "volume_window": 20,
            "volume_ratio_min": 0.8,
            "exit_ma": 40,
            "exit_ma_kind": "sma",
            "fixed_stop": 0.2,
            "trailing_stop": 0.24,
            "take_profit": 0.2,
            "atr_stop_mult": 2.0,
            "atr_trail_mult": 4.0,
            "max_hold_days": 20,
            "filtered_reverse_exit": False,
        },
        "entry_rules": [
            "做多：收盘突破过去 15 日高点，NVDA 80 日动量不低于 -8%，且 20 日价格斜率不低于 0.15%。",
            "QQQ 高于 EMA80，QQQ 60 日动量大于 2%，20 日价格斜率不低于 0.05%，且 NVDA 80 日相对 QQQ 强弱不低于 0。",
            "ATR50/收盘价位于 1% 到 6%，成交量不低于 20 日均量的 80%；做空为对称条件。",
        ],
        "exit_rules": [
            "反向 15 日通道突破、57 日退出通道、跌破/站回 SMA40，或持仓满 20 个交易日。",
            "固定止损 20%，移动止损 24%，止盈 20%，ATR 止损 2.0 倍，ATR 移动止损 4.0 倍。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.2183,
                "max_drawdown": -0.0567,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.7198,
                "max_drawdown": -0.1109,
                "win_rate": 0.8333,
                "round_trip_count": 6,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 1.2525,
                "max_drawdown": -0.1289,
                "win_rate": 1.0,
                "round_trip_count": 6,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.3632,
                "max_drawdown": -0.0662,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1249,
                "max_drawdown": -0.0960,
                "win_rate": 0.5,
                "round_trip_count": 2,
            },
        ],
    },
    {
        "code": "personal_nvda_ma30_40_steady",
        "symbol": "US.NVDA",
        "name": "NVDA MA30/40 稳定型",
        "description": "适合 NVDA 的稳定型均线交叉策略，叠加 SMA150、QQQ SMA50、20 日动量和相对 QQQ 强弱过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 30,
            "long_window": 40,
            "trend_ma": 150,
            "benchmark_ma": 50,
            "own_roc_days": 20,
            "own_roc_min": 0.04,
            "relative_strength_days": 80,
            "relative_strength_min": -0.02,
            "exit_ma": 80,
            "fixed_stop": 0.10,
            "trailing_stop": 0.24,
            "take_profit": 0.16,
            "max_hold_days": 15,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：SMA30 上穿 SMA40，且 NVDA 高于 SMA150，QQQ 高于 SMA50。",
            "NVDA 20 日动量大于 4%，且 NVDA 80 日动量相对 QQQ 不弱于 -2%。",
            "做空为对称条件：SMA30 下穿 SMA40，趋势、基准、动量和相对强弱均转弱。",
        ],
        "exit_rules": [
            "出现合格反向均线交叉信号，或跌破/站回 SMA80。",
            "固定止损 10%，移动止损 24%，止盈 16%，或虚拟持仓满 15 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1826,
                "max_drawdown": -0.0282,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1229,
                "max_drawdown": -0.1008,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.5622,
                "max_drawdown": -0.0762,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.3793,
                "max_drawdown": -0.0286,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1310,
                "max_drawdown": -0.0928,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_amd_ma10_20_steady",
        "symbol": "US.AMD",
        "name": "AMD SMA8/44 稳健型",
        "description": "适合 AMD 的稳健型均线交叉策略，叠加 QQQ 动量、相对强弱、退出均线、移动止损、止盈和 ATR 止损。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 8,
            "long_window": 44,
            "benchmark_roc_days": 60,
            "benchmark_roc_min": -0.04,
            "relative_strength_days": 40,
            "relative_strength_min": -0.03,
            "exit_ma": 30,
            "exit_ma_kind": "sma",
            "trailing_stop": 0.10,
            "take_profit": 0.06,
            "atr_days": 10,
            "atr_stop_mult": 2.0,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：SMA8 上穿 SMA44，且 QQQ 60 日动量大于 -4%。",
            "AMD 40 日相对 QQQ 强弱大于 -3%。",
            "做空为对称条件：SMA8 下穿 SMA44，且 QQQ 60 日动量小于 4%、AMD 相对 QQQ 强弱转弱。",
        ],
        "exit_rules": [
            "出现合格反向均线交叉信号，或价格跌破/站回 SMA30。",
            "移动止损 10%，止盈 6%，ATR10 止损 2.0 倍。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1261,
                "max_drawdown": -0.0766,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1103,
                "max_drawdown": -0.0233,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1034,
                "max_drawdown": -0.0191,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.1408,
                "max_drawdown": -0.0441,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1982,
                "max_drawdown": -0.0060,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
        ],
    },
    {
        "code": "personal_amd_channel66_aggressive",
        "symbol": "US.AMD",
        "name": "AMD 20 日通道进取型",
        "description": "适合 AMD 的进取型通道突破策略，叠加 AMD 长趋势、QQQ 动量、AMD 动量、相对强弱、ATR% 过滤和多重退出。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 20,
            "exit_channel_days": 16,
            "trend_ma": 200,
            "trend_ma_kind": "sma",
            "benchmark_roc_days": 120,
            "benchmark_roc_min": 0.0,
            "own_roc_days": 60,
            "own_roc_min": 0.04,
            "relative_strength_days": 60,
            "relative_strength_min": 0.06,
            "atr_days": 20,
            "atr_pct_max": 0.06,
            "exit_ma": 200,
            "exit_ma_kind": "ema",
            "fixed_stop": 0.10,
            "trailing_stop": 0.12,
        },
        "entry_rules": [
            "做多：收盘突破过去 20 日高点，且 AMD 高于 SMA200。",
            "QQQ 120 日动量大于 0%，AMD 60 日动量大于 4%，AMD 60 日相对 QQQ 强弱大于 6%，ATR20% 不高于 6%。",
            "做空为对称条件：跌破过去 20 日低点，且趋势、动量、相对强弱和 ATR% 过滤均转弱或可接受。",
        ],
        "exit_rules": [
            "反向 16 日通道突破，或价格跌破/站回 EMA200。",
            "固定止损 10%，移动止损 12%。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.3700,
                "max_drawdown": -0.1289,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.4394,
                "max_drawdown": -0.1454,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.2614,
                "max_drawdown": -0.0889,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.7629,
                "max_drawdown": -0.1828,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 1.3195,
                "max_drawdown": -0.0975,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_mu_sma24_40_steady",
        "symbol": "US.MU",
        "name": "MU SMA24/40 稳健型",
        "description": "适合 MU 的低回撤均线交叉模板，叠加 SMA150、QQQ SMA120、MU 长动量与相对 QQQ 强弱过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 0.8,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 24,
            "long_window": 40,
            "trend_ma": 150,
            "benchmark_ma": 120,
            "own_roc_days": 120,
            "own_roc_min": 0.02,
            "relative_strength_days": 80,
            "relative_strength_min": 0.06,
            "exit_ma": 150,
            "trailing_stop": 0.10,
            "take_profit": 0.16,
        },
        "entry_rules": [
            "做多：SMA24 上穿 SMA40，且 MU 高于 SMA150。",
            "QQQ 高于 SMA120，MU 120 日动量大于 2%，且 MU 80 日相对 QQQ 强弱大于 6%。",
            "做空为对称条件：SMA24 下穿 SMA40，且 MU 低于 SMA150、QQQ 低于 SMA120、MU 动量与相对强弱转弱。",
        ],
        "exit_rules": [
            "反向 SMA24/SMA40 均线交叉。",
            "跌破或站回 SMA150，移动止损 10%，或止盈 16%。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1915,
                "max_drawdown": -0.0654,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1457,
                "max_drawdown": -0.0568,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1628,
                "max_drawdown": -0.0401,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.1634,
                "max_drawdown": 0.0,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.2455,
                "max_drawdown": -0.0020,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_mu_channel48_aggressive",
        "symbol": "US.MU",
        "name": "MU SMA22/30 进取型",
        "description": "适合 MU 的高收益均线交叉模板，使用 SMA22/SMA30 多空交叉，叠加 QQQ SMA150 过滤与 8% 止盈。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 22,
            "long_window": 30,
            "benchmark_ma": 150,
            "take_profit": 0.08,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：SMA22 上穿 SMA30，且 QQQ 高于 SMA150。",
            "做空为对称条件：SMA22 下穿 SMA30，且 QQQ 低于 SMA150。",
        ],
        "exit_rules": [
            "出现合格反向 SMA22/SMA30 均线交叉信号。",
            "单笔达到 8% 止盈时退出；区间结束仍持仓则按最后收盘价强制平仓。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.7255,
                "max_drawdown": -0.1820,
                "win_rate": 1.0,
                "round_trip_count": 6,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.3296,
                "max_drawdown": -0.1561,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.3056,
                "max_drawdown": -0.0863,
                "win_rate": 0.8,
                "round_trip_count": 5,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.5820,
                "max_drawdown": -0.0535,
                "win_rate": 1.0,
                "round_trip_count": 5,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.4134,
                "max_drawdown": -0.0369,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
        ],
    },
    {
        "code": "personal_dell_channel19_steady",
        "symbol": "US.DELL",
        "name": "DELL 19 日通道稳健型",
        "description": "DELL 做多专属稳健候选，使用 19 日通道突破，叠加 SMA100、QQQ 20 日动量、DELL 20 日动量和相对 QQQ 强弱过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_only",
        "risk_level": "steady",
        "position_ratio": 0.8,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 19,
            "exit_channel_days": 73,
            "trend_ma": 100,
            "benchmark_roc_days": 20,
            "benchmark_roc_min": 0.06,
            "own_roc_days": 20,
            "own_roc_min": 0.06,
            "relative_strength_days": 20,
            "relative_strength_min": 0.02,
            "trailing_stop": 0.10,
            "take_profit": 0.16,
            "max_hold_days": 20,
        },
        "entry_rules": [
            "做多：DELL 收盘价突破过去 19 日高点，且 DELL 高于 SMA100。",
            "QQQ 20 日动量大于 6%，DELL 20 日动量大于 6%，且 DELL 20 日相对 QQQ 强弱大于 2%。",
            "该模板只做多，不生成做空信号。",
        ],
        "exit_rules": [
            "跌破过去 73 日低点。",
            "移动止损 10%，止盈 16%，或虚拟持仓满 20 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.0476,
                "max_drawdown": -0.0555,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1309,
                "max_drawdown": -0.0622,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1470,
                "max_drawdown": -0.0283,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.2748,
                "max_drawdown": -0.0484,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.6140,
                "max_drawdown": -0.0801,
                "win_rate": 0.75,
                "round_trip_count": 4,
            },
        ],
    },
    {
        "code": "personal_dell_channel42_aggressive",
        "symbol": "US.DELL",
        "name": "DELL 42 日通道进取型",
        "description": "DELL 做多专属进取模板，使用 42 日通道突破，叠加 QQQ 20 日动量过滤，并通过通道、止损、移动止损、止盈和持仓天数退出。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_only",
        "risk_level": "aggressive",
        "position_ratio": 0.9,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 42,
            "exit_channel_days": 70,
            "benchmark_roc_days": 20,
            "benchmark_roc_min": 0.0,
            "fixed_stop": 0.16,
            "trailing_stop": 0.16,
            "take_profit": 0.12,
            "max_hold_days": 50,
        },
        "entry_rules": [
            "做多：DELL 收盘价突破过去 42 日高点。",
            "QQQ 20 日动量大于 0%。",
            "该模板只做多，不生成做空信号。",
        ],
        "exit_rules": [
            "跌破过去 70 日低点。",
            "固定止损 16%，移动止损 16%，止盈 12%，或虚拟持仓满 50 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1116,
                "max_drawdown": -0.0342,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.3920,
                "max_drawdown": -0.0980,
                "win_rate": 1.0,
                "round_trip_count": 4,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.6549,
                "max_drawdown": -0.1530,
                "win_rate": 0.8,
                "round_trip_count": 5,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.4693,
                "max_drawdown": -0.1319,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.6558,
                "max_drawdown": -0.0886,
                "win_rate": 0.75,
                "round_trip_count": 4,
            },
        ],
    },
    {
        "code": "personal_msft_channel61_steady",
        "symbol": "US.MSFT",
        "name": "MSFT 54 Day Channel Steady",
        "description": "MSFT closest steady long-short template from the 2021-2026 walk-forward research run; the research run found no strict steady candidate that satisfied all hard constraints.",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 54,
            "exit_channel_days": 58,
            "trend_ma": 150,
            "trend_ma_kind": "ema",
            "benchmark_roc_days": 80,
            "benchmark_roc_min": -0.08,
            "own_roc_days": 120,
            "own_roc_min": -0.02,
            "relative_strength_days": 60,
            "relative_strength_min": 0.06,
            "fixed_stop": 0.08,
            "take_profit": 0.10,
        },
        "entry_rules": [
            "Long: MSFT close breaks above the prior 54-day high and MSFT close is above EMA150.",
            "QQQ ROC80 is greater than -8%, MSFT ROC120 is greater than -2%, and MSFT ROC60 minus QQQ ROC60 is greater than 6%.",
            "Short: symmetric 54-day breakdown with MSFT below EMA150, QQQ ROC80 below 8%, MSFT ROC120 below 2%, and MSFT ROC60 minus QQQ ROC60 below -6%.",
        ],
        "exit_rules": [
            "Reverse 58-day channel break.",
            "Fixed stop 8% or take profit 10%.",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1061,
                "max_drawdown": -0.0961,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.3371,
                "max_drawdown": -0.0560,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.0945,
                "max_drawdown": -0.0933,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.2174,
                "max_drawdown": -0.1014,
                "win_rate": 0.75,
                "round_trip_count": 4,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1106,
                "max_drawdown": -0.1139,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
        ],
    },
    {
        "code": "personal_msft_channel59_aggressive",
        "symbol": "US.MSFT",
        "name": "MSFT 59 Day Channel ATR Aggressive",
        "description": "MSFT aggressive long-short template from the 2021-2026 walk-forward research run.",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 59,
            "exit_channel_days": 73,
            "trend_ma": 200,
            "trend_ma_kind": "sma",
            "own_roc_days": 120,
            "own_roc_min": -0.04,
            "relative_strength_days": 60,
            "relative_strength_min": 0.04,
            "atr_days": 50,
            "atr_pct_max": 0.03,
            "exit_ma": 200,
            "exit_ma_kind": "ema",
            "take_profit": 0.10,
            "max_hold_days": 60,
        },
        "entry_rules": [
            "Long: MSFT close breaks above the prior 59-day high and MSFT close is above SMA200.",
            "MSFT ROC120 is greater than -4%, MSFT ROC60 minus QQQ ROC60 is greater than 4%, and ATR50/close is no more than 3%.",
            "Short: symmetric 59-day breakdown with MSFT below SMA200, MSFT ROC120 below 4%, MSFT ROC60 minus QQQ ROC60 below -4%, and ATR50/close is no more than 3%.",
        ],
        "exit_rules": [
            "Reverse 73-day channel break or price crosses the EMA200 exit line.",
            "Take profit 10% or virtual hold reaches 60 trading days.",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1061,
                "max_drawdown": -0.0962,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.3496,
                "max_drawdown": -0.0560,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1005,
                "max_drawdown": -0.0933,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.3115,
                "max_drawdown": -0.0744,
                "win_rate": 0.75,
                "round_trip_count": 4,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1311,
                "max_drawdown": -0.0822,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
        ],
    },
    {
        "code": "personal_aaoi_sma37_53_steady",
        "symbol": "US.AAOI",
        "name": "AAOI SMA37/53 Steady",
        "description": "AAOI long-only steady template from the 2021-2026 research run.",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_only",
        "risk_level": "steady",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 37,
            "long_window": 53,
            "trend_ma": 50,
            "benchmark_ma": 80,
            "relative_strength_days": 40,
            "relative_strength_min": 0.0,
            "exit_ma": 120,
            "fixed_stop": 0.08,
            "take_profit": 0.08,
            "max_hold_days": 60,
        },
        "entry_rules": [
            "Long: SMA37 crosses above SMA53.",
            "AAOI close is above SMA50, QQQ close is above SMA80, and AAOI ROC40 minus QQQ ROC40 is greater than 0.",
            "This template is long-only and does not generate short signals.",
        ],
        "exit_rules": [
            "SMA37 crosses below SMA53.",
            "AAOI close falls below SMA120, fixed stop 8%, take profit 8%, or virtual hold reaches 60 trading days.",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1247,
                "max_drawdown": 0.0,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.4425,
                "max_drawdown": -0.0499,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1261,
                "max_drawdown": 0.0,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.1143,
                "max_drawdown": -0.0239,
                "win_rate": 0.5,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1450,
                "max_drawdown": 0.0,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_aaoi_sma5_30_aggressive",
        "symbol": "US.AAOI",
        "name": "AAOI SMA5/30 Aggressive",
        "description": "AAOI long-only aggressive template from the 2021-2026 research run.",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_only",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 5,
            "long_window": 30,
            "trend_ma": 100,
            "own_roc_days": 60,
            "own_roc_min": 0.0,
            "exit_ma": 120,
            "fixed_stop": 0.12,
            "trailing_stop": 0.16,
            "take_profit": 0.20,
            "max_hold_days": 60,
        },
        "entry_rules": [
            "Long: SMA5 crosses above SMA30.",
            "AAOI close is above SMA100 and AAOI ROC60 is greater than 0.",
            "This template is long-only and does not generate short signals.",
        ],
        "exit_rules": [
            "SMA5 crosses below SMA30.",
            "AAOI close falls below SMA120, fixed stop 12%, trailing stop 16%, take profit 20%, or virtual hold reaches 60 trading days.",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.3892,
                "max_drawdown": -0.0565,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.2599,
                "max_drawdown": -0.0323,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.4840,
                "max_drawdown": -0.1066,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.4527,
                "max_drawdown": -0.0969,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1826,
                "max_drawdown": -0.0156,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
]
