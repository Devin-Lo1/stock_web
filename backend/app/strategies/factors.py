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
