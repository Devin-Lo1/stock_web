from datetime import date, datetime, timedelta, timezone
from typing import Any

from ..repositories.market_data import list_candles, upsert_candles
from ..repositories.notifications import (
    create_signal_event,
    get_signal_event_by_dedupe_key,
)
from ..repositories.positions import list_positions
from ..schemas import Candle, Position, SignalEvent, SignalEventCreate, SignalScanResult
from ..services.futu_client import (
    FutuDependencyError,
    FutuOpenDError,
    request_history_klines,
)
from ..services.signal_scan_config import (
    SignalScanConfig,
    list_signal_scan_configs,
)
from ..strategies import get_strategy
from ..strategies.base import StrategyConfigurationError, StrategySignal
from ..strategies.factors import (
    average_true_range,
    macd,
    moving_average,
    relative_strength_index,
    rolling_high,
    rolling_low,
)


def scan_strategy_signals(*, refresh: bool = False) -> SignalScanResult:
    events: list[SignalEvent] = []
    errors: list[dict[str, Any]] = []
    scanned_count = 0
    skipped_count = 0

    for position in list_positions():
        candles, load_error = _load_scan_candles(position, refresh=refresh)
        if load_error:
            errors.append(
                {
                    "code": position.code,
                    "stage": "load_candles",
                    "message": load_error,
                },
            )
        if len(candles) < 2:
            skipped_count += 1
            continue

        for config in list_signal_scan_configs():
            strategy = get_strategy(config.strategy_code)
            if strategy is None:
                skipped_count += 1
                continue
            try:
                minimum_candles = strategy.minimum_candles(config.parameters)
            except StrategyConfigurationError as error:
                errors.append(
                    {
                        "code": position.code,
                        "strategy_code": config.strategy_code,
                        "stage": "minimum_candles",
                        "message": error.reason,
                    },
                )
                skipped_count += 1
                continue
            if len(candles) < minimum_candles:
                skipped_count += 1
                continue

            scanned_count += 1
            try:
                evaluation = strategy.evaluate(candles, config.parameters)
            except StrategyConfigurationError as error:
                errors.append(
                    {
                        "code": position.code,
                        "strategy_code": config.strategy_code,
                        "stage": "evaluate",
                        "message": error.reason,
                    },
                )
                skipped_count += 1
                continue

            signal = _latest_signal(evaluation.signals, len(candles) - 1)
            if signal is None:
                skipped_count += 1
                continue

            payload = _event_payload(position, candles, config, signal)
            existing = get_signal_event_by_dedupe_key(payload.dedupe_key)
            if existing is not None:
                skipped_count += 1
                continue
            events.append(create_signal_event(payload))

    return SignalScanResult(
        scanned_count=scanned_count,
        created_count=len(events),
        skipped_count=skipped_count,
        events=events,
        errors=errors,
    )


def _load_scan_candles(
    position: Position,
    *,
    refresh: bool,
) -> tuple[list[Candle], str | None]:
    if refresh:
        today = datetime.now(timezone.utc).date()
        start = today - timedelta(days=420)
        try:
            refreshed = request_history_klines(
                code=position.code,
                period="day",
                max_count=260,
                start=start.isoformat(),
                end=today.isoformat(),
            )
        except (FutuDependencyError, FutuOpenDError) as error:
            return list_candles(position.code, "day", 260), str(error)
        if refreshed:
            upsert_candles(refreshed)
    return list_candles(position.code, "day", 260), None


def _latest_signal(signals: list[StrategySignal], latest_index: int) -> StrategySignal | None:
    for signal in reversed(signals):
        if signal.index == latest_index:
            return signal
        if signal.index < latest_index:
            return None
    return None


def _event_payload(
    position: Position,
    candles: list[Candle],
    config: SignalScanConfig,
    signal: StrategySignal,
) -> SignalEventCreate:
    latest = candles[signal.index]
    condition, trigger_value, threshold_value = _condition_values(
        candles,
        config,
        signal,
    )
    signal_date = latest.time.date()
    side_label = "转强" if signal.side == "buy" else "转弱"
    level = "important" if signal.side == "sell" else "warning"
    title = f"{position.name}触发{config.strategy_name}观察"
    message = (
        f"{condition}，当前值 {trigger_value:.2f}，阈值 {threshold_value:.2f}，"
        f"{signal_date.isoformat()} 触发{side_label}观察。"
    )
    dedupe_key = (
        f"{position.code}:{config.strategy_code}:"
        f"{_parameter_key(config.parameters)}:{signal.side}:{signal_date.isoformat()}"
    )
    return SignalEventCreate(
        source="strategy_scanner",
        code=position.code,
        signal_type=f"{config.strategy_code}_{signal.side}",
        level=level,
        title=title,
        message=message,
        trigger_value=trigger_value,
        threshold_value=threshold_value,
        dedupe_key=dedupe_key,
        payload={
            "source_category": "strategy",
            "stock_name": position.name,
            "strategy_code": config.strategy_code,
            "strategy_name": config.strategy_name,
            "condition_label": condition,
            "side": signal.side,
            "trigger_date": signal_date.isoformat(),
            "parameters": config.parameters,
            "push_candidate": config.push_candidate
            and level in {"important", "warning"},
        },
        triggered_at=_triggered_at(signal_date),
    )


def _condition_values(
    candles: list[Candle],
    config: SignalScanConfig,
    signal: StrategySignal,
) -> tuple[str, float, float]:
    closes = [candle.close for candle in candles]
    index = signal.index
    side = signal.side
    if config.strategy_code == "price_break_ma":
        window = int(config.parameters["ma_window"])
        ma_values = moving_average(closes, window)
        label = "站回" if side == "buy" else "跌破"
        return (
            f"收盘价{label} MA{window}",
            closes[index],
            float(ma_values[index] or 0),
        )
    if config.strategy_code == "ma_cross":
        short_window = int(config.parameters["short_window"])
        long_window = int(config.parameters["long_window"])
        short_ma = moving_average(closes, short_window)
        long_ma = moving_average(closes, long_window)
        label = "上穿" if side == "buy" else "下穿"
        return (
            f"MA{short_window} {label} MA{long_window}",
            float(short_ma[index] or 0),
            float(long_ma[index] or 0),
        )
    if config.strategy_code == "rsi_reversal":
        window = int(config.parameters["rsi_window"])
        oversold = float(config.parameters["oversold"])
        overbought = float(config.parameters["overbought"])
        rsi_values = relative_strength_index(closes, window)
        if side == "buy":
            return ("RSI 超卖后回升", float(rsi_values[index] or 0), oversold)
        return ("RSI 高位回落", float(rsi_values[index] or 0), overbought)
    if config.strategy_code == "rsi_oversold_rebound":
        window = int(config.parameters["rsi_window"])
        oversold = float(config.parameters["oversold"])
        overbought = float(config.parameters["overbought"])
        rsi_values = relative_strength_index(closes, window)
        if side == "buy":
            return ("RSI 超跌反弹", float(rsi_values[index] or 0), oversold)
        return ("RSI 高位回落止盈", float(rsi_values[index] or 0), overbought)
    if config.strategy_code == "macd_trend":
        fast_window = int(config.parameters["fast_window"])
        slow_window = int(config.parameters["slow_window"])
        signal_window = int(config.parameters["signal_window"])
        _, _, histogram = macd(closes, fast_window, slow_window, signal_window)
        label = "转正" if side == "buy" else "转负"
        return (f"MACD 柱体{label}", float(histogram[index] or 0), 0)
    if config.strategy_code == "volume_breakout":
        lookback_window = int(config.parameters["lookback_window"])
        highs = rolling_high(closes, lookback_window)
        lows = rolling_low(closes, lookback_window)
        label = "放量突破" if side == "buy" else "放量跌破"
        threshold = highs[index - 1] if side == "buy" else lows[index - 1]
        return (f"收盘价{label}{lookback_window}期区间", closes[index], float(threshold or 0))
    if config.strategy_code == "ma_breakdown_stop":
        window = int(config.parameters["ma_window"])
        buffer_pct = float(config.parameters.get("stop_buffer_pct", 0))
        ma_values = moving_average(closes, window)
        label = "站回" if side == "buy" else "跌破止损线"
        threshold = float(ma_values[index] or 0)
        if side == "sell":
            threshold *= 1 - buffer_pct / 100
        return (f"收盘价{label} MA{window}", closes[index], threshold)
    if config.strategy_code == "atr_trailing_stop":
        atr_window = int(config.parameters["atr_window"])
        atr_multiplier = float(config.parameters["atr_multiplier"])
        highs = [candle.high for candle in candles]
        lows = [candle.low for candle in candles]
        atr_values = average_true_range(highs, lows, closes, atr_window)
        recent_peak = max(closes[max(0, index - atr_window + 1) : index + 1])
        stop_value = recent_peak - float(atr_values[index] or 0) * atr_multiplier
        label = "站回入场均线" if side == "buy" else "跌破 ATR 动态止损"
        return (label, closes[index], stop_value)
    if config.strategy_code == "trend_score":
        ma_window = int(config.parameters["ma_window"])
        momentum_window = int(config.parameters["momentum_window"])
        volume_window = int(config.parameters["volume_window"])
        ma_values = moving_average(closes, ma_window)
        volume_ma = moving_average([candle.volume for candle in candles], volume_window)
        threshold = float(
            config.parameters["buy_score" if side == "buy" else "sell_score"],
        )
        label = "趋势评分转强" if side == "buy" else "趋势评分转弱"
        score = _trend_score_value(
            index,
            closes,
            [candle.volume for candle in candles],
            ma_values,
            volume_ma,
            momentum_window,
        )
        return (label, float(score), threshold)
    if config.strategy_code == "composite_factor":
        factor_codes = config.parameters.get("factor_codes", [])
        factor_count = len(factor_codes) if isinstance(factor_codes, list) else 0
        label = "组合因子确认转强" if side == "buy" else "组合因子确认转弱"
        return (label, float(factor_count), float(factor_count))
    return ("策略条件触发", closes[index], 0)


def _parameter_key(parameters: dict[str, object]) -> str:
    return ",".join(f"{key}={parameters[key]}" for key in sorted(parameters))


def _trend_score_value(
    index: int,
    closes: list[float],
    volumes: list[float],
    ma_values: list[float | None],
    volume_ma: list[float | None],
    momentum_window: int,
) -> int:
    if index <= 0:
        return 0
    score = 0
    current_ma = ma_values[index]
    previous_ma = ma_values[index - 1]
    average_volume = volume_ma[index]
    if current_ma is not None and closes[index] > current_ma:
        score += 1
    if current_ma is not None and previous_ma is not None and current_ma > previous_ma:
        score += 1
    if index >= momentum_window and closes[index] > closes[index - momentum_window]:
        score += 1
    if average_volume is not None and volumes[index] >= average_volume:
        score += 1
    return score


def _triggered_at(signal_date: date) -> datetime:
    return datetime(
        signal_date.year,
        signal_date.month,
        signal_date.day,
        tzinfo=timezone.utc,
    )
