def mean(values: list[float]) -> float:
    return sum(values) / len(values)


def moving_average(values: list[float], window: int) -> list[float | None]:
    averages: list[float | None] = []
    for index in range(len(values)):
        if index + 1 < window:
            averages.append(None)
            continue
        averages.append(mean(values[index + 1 - window : index + 1]))
    return averages


def rolling_high(values: list[float], window: int) -> list[float | None]:
    highs: list[float | None] = []
    for index in range(len(values)):
        if index + 1 < window:
            highs.append(None)
            continue
        highs.append(max(values[index + 1 - window : index + 1]))
    return highs


def rolling_low(values: list[float], window: int) -> list[float | None]:
    lows: list[float | None] = []
    for index in range(len(values)):
        if index + 1 < window:
            lows.append(None)
            continue
        lows.append(min(values[index + 1 - window : index + 1]))
    return lows


def average_true_range(
    highs: list[float],
    lows: list[float],
    closes: list[float],
    window: int,
) -> list[float | None]:
    result: list[float | None] = [None] * len(closes)
    if window <= 0 or len(closes) < window:
        return result

    true_ranges: list[float] = []
    for index in range(len(closes)):
        if index == 0:
            true_ranges.append(highs[index] - lows[index])
            continue
        true_ranges.append(
            max(
                highs[index] - lows[index],
                abs(highs[index] - closes[index - 1]),
                abs(lows[index] - closes[index - 1]),
            ),
        )

    for index in range(window - 1, len(closes)):
        result[index] = mean(true_ranges[index + 1 - window : index + 1])
    return result


def exponential_moving_average(
    values: list[float],
    window: int,
) -> list[float | None]:
    result: list[float | None] = [None] * len(values)
    if window <= 0 or len(values) < window:
        return result

    multiplier = 2 / (window + 1)
    current = mean(values[:window])
    result[window - 1] = current
    for index in range(window, len(values)):
        current = (values[index] - current) * multiplier + current
        result[index] = current
    return result


def macd(
    values: list[float],
    fast_window: int,
    slow_window: int,
    signal_window: int,
) -> tuple[list[float | None], list[float | None], list[float | None]]:
    fast_ema = exponential_moving_average(values, fast_window)
    slow_ema = exponential_moving_average(values, slow_window)
    dif: list[float | None] = []
    for fast, slow in zip(fast_ema, slow_ema):
        dif.append(None if fast is None or slow is None else fast - slow)

    valid_dif = [value for value in dif if value is not None]
    valid_signal = exponential_moving_average(valid_dif, signal_window)
    signal: list[float | None] = [None] * len(values)
    first_valid_index = next(
        (index for index, value in enumerate(dif) if value is not None),
        len(values),
    )
    for offset, value in enumerate(valid_signal):
        index = first_valid_index + offset
        if index < len(signal):
            signal[index] = value

    histogram: list[float | None] = []
    for dif_value, signal_value in zip(dif, signal):
        histogram.append(
            None
            if dif_value is None or signal_value is None
            else dif_value - signal_value
        )
    return dif, signal, histogram


def relative_strength_index(values: list[float], window: int) -> list[float | None]:
    result: list[float | None] = [None] * len(values)
    if window <= 0 or len(values) <= window:
        return result

    gains: list[float] = []
    losses: list[float] = []
    for index in range(1, window + 1):
        change = values[index] - values[index - 1]
        gains.append(max(change, 0))
        losses.append(max(-change, 0))

    average_gain = mean(gains)
    average_loss = mean(losses)
    result[window] = _rsi_from_averages(average_gain, average_loss)

    for index in range(window + 1, len(values)):
        change = values[index] - values[index - 1]
        gain = max(change, 0)
        loss = max(-change, 0)
        average_gain = (average_gain * (window - 1) + gain) / window
        average_loss = (average_loss * (window - 1) + loss) / window
        result[index] = _rsi_from_averages(average_gain, average_loss)

    return result


def _rsi_from_averages(average_gain: float, average_loss: float) -> float:
    if average_loss == 0:
        return 100
    relative_strength = average_gain / average_loss
    return 100 - 100 / (1 + relative_strength)
