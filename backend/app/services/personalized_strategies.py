from __future__ import annotations

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
    PersonalizedStrategyDecision,
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
    "US.AMD": "personal_amd_ma10_20_steady",
    "US.DELL": "personal_dell_channel19_steady",
    "US.GOOGL": "personal_googl_sma5_113_steady",
    "US.MU": "personal_mu_sma24_40_steady",
    "US.NVDA": "personal_nvda_ma30_40_steady",
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
) -> PersonalizedStrategyScanResult | None:
    normalized_symbol = symbol.strip().upper()
    config = _find_config(normalized_symbol)
    if config is None:
        return None

    template = _template_from_config(config)
    candles, refresh_error = _load_day_candles(template.symbol, refresh=refresh)
    benchmark_candles, benchmark_error = _load_day_candles(
        template.benchmark_symbol,
        refresh=refresh,
    )
    refresh_error = _merge_errors(refresh_error, benchmark_error)
    quote, quote_error = _load_quote(template.symbol, refresh=refresh)
    benchmark_quote, benchmark_quote_error = _load_quote(
        template.benchmark_symbol,
        refresh=refresh,
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
        value = _sma(closes, index, trend_ma)
        if value is None or close <= value:
            return False

    benchmark_ma = params.get("benchmark_ma")
    if benchmark_ma is not None:
        value = _sma(benchmark_closes, benchmark_index, benchmark_ma)
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
        value = _sma(closes, index, trend_ma)
        if value is None or close >= value:
            return False

    benchmark_ma = params.get("benchmark_ma")
    if benchmark_ma is not None:
        value = _sma(benchmark_closes, benchmark_index, benchmark_ma)
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
    if params["engine"] == "ma_cross":
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

    exit_channel_days = params.get("exit_channel_days")
    if exit_channel_days is not None:
        prior_high = _prior_high(candles, index, exit_channel_days)
        prior_low = _prior_low(candles, index, exit_channel_days)
        if position.side == "long" and prior_low is not None and close < prior_low:
            return "reverse_channel_breakdown"
        if position.side == "short" and prior_high is not None and close > prior_high:
            return "reverse_channel_breakout"

    exit_ma = params.get("exit_ma") or params.get("trend_ma")
    if exit_ma is not None:
        value = _sma(closes, index, exit_ma)
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

    max_hold_days = params.get("max_hold_days")
    if max_hold_days is not None and position.hold_days >= max_hold_days:
        return "max_hold_days"

    return None


def _sma(values: list[float], index: int, window: int) -> float | None:
    if window <= 0 or index + 1 < window:
        return None
    window_values = values[index - window + 1 : index + 1]
    return sum(window_values) / window


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


def _prior_high(candles: list[Candle], index: int, window: int) -> float | None:
    if window <= 0 or index < window:
        return None
    return max(candle.high for candle in candles[index - window : index])


def _prior_low(candles: list[Candle], index: int, window: int) -> float | None:
    if window <= 0 or index < window:
        return None
    return min(candle.low for candle in candles[index - window : index])


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
        "code": "personal_googl_sma5_113_aggressive",
        "symbol": "US.GOOGL",
        "name": "GOOGL SMA5/113 趋势交叉（进取型）",
        "description": "适合 GOOGL 的进取型均线交叉策略，叠加自身 SMA100、QQQ SMA200 与 QQQ 120 日动量过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 5,
            "long_window": 113,
            "trend_ma": 100,
            "benchmark_ma": 200,
            "benchmark_roc_days": 120,
            "benchmark_roc_min": 0.0,
            "fixed_stop": 0.12,
            "trailing_stop": 0.12,
            "take_profit": 0.20,
            "max_hold_days": 60,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：SMA5 上穿 SMA113，且 GOOGL 高于 SMA100，QQQ 高于 SMA200。",
            "QQQ 120 日动量大于 0，做空为对称条件：SMA5 下穿 SMA113，趋势与 QQQ 动量均转弱。",
        ],
        "exit_rules": [
            "出现合格反向均线交叉信号。",
            "固定止损 12%，移动止损 12%，止盈 20%，或虚拟持仓满 60 个交易日。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.4641,
                "max_drawdown": -0.0674,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.2696,
                "max_drawdown": -0.0667,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.3125,
                "max_drawdown": -0.0930,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.2730,
                "max_drawdown": -0.0829,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1025,
                "max_drawdown": -0.1401,
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
        "code": "personal_nvda_channel35",
        "symbol": "US.NVDA",
        "name": "NVDA 35日通道趋势突破（进取型）",
        "description": "适合 NVDA 的强趋势突破策略，叠加 SMA200、QQQ 动量与相对强弱，定位为进取型参考。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 35,
            "exit_channel_days": 50,
            "trend_ma": 200,
            "benchmark_ma": 80,
            "benchmark_roc_days": 40,
            "benchmark_roc_min": 0.03,
            "own_roc_days": 80,
            "own_roc_min": 0.0,
            "relative_strength_days": 80,
            "relative_strength_min": 0.0,
            "exit_ma": 120,
            "fixed_stop": 0.24,
            "trailing_stop": 0.12,
            "max_hold_days": 20,
        },
        "entry_rules": [
            "收盘突破过去 35 日高点，且价格高于 SMA200。",
            "QQQ 高于 SMA80，QQQ 40 日动量大于 3%，NVDA 80 日强于 QQQ。",
        ],
        "exit_rules": [
            "反向 50 日通道突破，或跌破/站回 SMA120。",
            "固定止损 24%，移动止损 12%，或持仓满 20 个交易日。",
        ],
        "segments": [
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.8903,
                "max_drawdown": -0.1010,
                "win_rate": 0.8,
                "round_trip_count": 5,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.9294,
                "max_drawdown": -0.1290,
                "win_rate": 1.0,
                "round_trip_count": 4,
            },
            {
                "label": "2025-2026",
                "start_date": date(2025, 1, 1),
                "end_date": date(2026, 6, 1),
                "total_return": 0.6323,
                "max_drawdown": -0.1396,
                "win_rate": 1.0,
                "round_trip_count": 5,
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
        "name": "AMD SMA10/20 稳健型",
        "description": "适合 AMD 的稳健型均线交叉策略，优先控制回撤，叠加 AMD/QQQ 趋势、QQQ 动量和相对强弱过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "steady",
        "position_ratio": 0.8,
        "parameters": {
            "engine": "ma_cross",
            "short_window": 10,
            "long_window": 20,
            "trend_ma": 100,
            "benchmark_ma": 100,
            "benchmark_roc_days": 120,
            "benchmark_roc_min": 0.06,
            "own_roc_days": 20,
            "own_roc_min": -0.04,
            "relative_strength_days": 80,
            "relative_strength_min": -0.06,
            "exit_ma": 120,
            "fixed_stop": 0.10,
            "trailing_stop": 0.12,
            "take_profit": 0.08,
            "filtered_reverse_exit": True,
        },
        "entry_rules": [
            "做多：SMA10 上穿 SMA20，且 AMD 高于 SMA100，QQQ 高于 SMA100，QQQ 120 日动量大于 6%。",
            "AMD 20 日动量大于 -4%，且 AMD 80 日相对 QQQ 强弱大于 -6%。",
            "做空为对称条件：SMA10 下穿 SMA20，AMD 低于 SMA100，QQQ 低于 SMA100，QQQ 120 日动量小于 -6%。",
        ],
        "exit_rules": [
            "出现合格反向均线交叉信号，或价格跌破/站回 SMA120。",
            "固定止损 10%，移动止损 12%，止盈 8%。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1697,
                "max_drawdown": -0.0534,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.1313,
                "max_drawdown": -0.0251,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1147,
                "max_drawdown": -0.0139,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.3449,
                "max_drawdown": -0.0241,
                "win_rate": 1.0,
                "round_trip_count": 2,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.1010,
                "max_drawdown": -0.0717,
                "win_rate": 1.0,
                "round_trip_count": 1,
            },
        ],
    },
    {
        "code": "personal_amd_channel66_aggressive",
        "symbol": "US.AMD",
        "name": "AMD 66 日通道进取型",
        "description": "适合 AMD 的进取型通道突破策略，追求更高全周期收益，叠加 AMD/QQQ 趋势、QQQ 动量、AMD 动量和相对强弱过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 66,
            "exit_channel_days": 43,
            "trend_ma": 80,
            "benchmark_ma": 50,
            "benchmark_roc_days": 120,
            "benchmark_roc_min": 0.04,
            "own_roc_days": 60,
            "own_roc_min": 0.08,
            "relative_strength_days": 80,
            "relative_strength_min": 0.06,
            "fixed_stop": 0.24,
            "trailing_stop": 0.10,
            "take_profit": 0.20,
        },
        "entry_rules": [
            "做多：收盘突破过去 66 日高点，且 AMD 高于 SMA80，QQQ 高于 SMA50。",
            "QQQ 120 日动量大于 4%，AMD 60 日动量大于 8%，且 AMD 80 日相对 QQQ 强弱大于 6%。",
            "做空为对称条件：跌破过去 66 日低点，趋势、市场动量、AMD 动量与相对强弱均转弱。",
        ],
        "exit_rules": [
            "反向 43 日通道突破。",
            "固定止损 24%，移动止损 10%，止盈 20%。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.1071,
                "max_drawdown": -0.1693,
                "win_rate": 0.6667,
                "round_trip_count": 3,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.5499,
                "max_drawdown": -0.1039,
                "win_rate": 1.0,
                "round_trip_count": 4,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.1169,
                "max_drawdown": -0.1274,
                "win_rate": 0.5,
                "round_trip_count": 2,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 0.4643,
                "max_drawdown": -0.1831,
                "win_rate": 0.75,
                "round_trip_count": 4,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 0.9276,
                "max_drawdown": -0.0802,
                "win_rate": 1.0,
                "round_trip_count": 3,
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
        "name": "MU 48 日通道进取型",
        "description": "适合 MU 的高收益通道突破模板，叠加 SMA100、QQQ SMA150、QQQ 120 日动量、MU 短动量和相对 QQQ 强弱过滤。",
        "benchmark_symbol": "US.QQQ",
        "direction_mode": "long_short",
        "risk_level": "aggressive",
        "position_ratio": 1.0,
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 48,
            "exit_channel_days": 25,
            "trend_ma": 100,
            "benchmark_ma": 150,
            "benchmark_roc_days": 120,
            "benchmark_roc_min": 0.08,
            "own_roc_days": 20,
            "own_roc_min": -0.08,
            "relative_strength_days": 20,
            "relative_strength_min": -0.06,
            "exit_ma": 100,
            "trailing_stop": 0.24,
            "take_profit": 0.08,
        },
        "entry_rules": [
            "做多：收盘突破过去 48 日高点，且 MU 高于 SMA100。",
            "QQQ 高于 SMA150，QQQ 120 日动量大于 8%，MU 20 日动量不弱于 -8%，且 MU 20 日相对 QQQ 强弱不弱于 -6%。",
            "做空为对称条件：跌破过去 48 日低点，且趋势、QQQ 趋势/动量、MU 动量与相对强弱均转弱。",
        ],
        "exit_rules": [
            "反向 25 日通道突破。",
            "跌破或站回 SMA100，移动止损 24%，或止盈 8%。",
        ],
        "segments": [
            {
                "label": "2022",
                "start_date": date(2022, 1, 1),
                "end_date": date(2022, 12, 31),
                "total_return": 0.3883,
                "max_drawdown": -0.1711,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2023",
                "start_date": date(2023, 1, 1),
                "end_date": date(2023, 12, 31),
                "total_return": 0.2927,
                "max_drawdown": -0.0426,
                "win_rate": 1.0,
                "round_trip_count": 3,
            },
            {
                "label": "2024",
                "start_date": date(2024, 1, 1),
                "end_date": date(2024, 12, 31),
                "total_return": 0.2986,
                "max_drawdown": -0.1661,
                "win_rate": 0.8,
                "round_trip_count": 5,
            },
            {
                "label": "2025",
                "start_date": date(2025, 1, 1),
                "end_date": date(2025, 12, 31),
                "total_return": 1.1040,
                "max_drawdown": -0.1580,
                "win_rate": 0.875,
                "round_trip_count": 8,
            },
            {
                "label": "2026YTD",
                "start_date": date(2026, 1, 1),
                "end_date": date(2026, 6, 3),
                "total_return": 1.4268,
                "max_drawdown": -0.1521,
                "win_rate": 0.8571,
                "round_trip_count": 7,
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
]
