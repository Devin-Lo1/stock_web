from dataclasses import dataclass, replace


@dataclass(frozen=True)
class SignalScanConfig:
    strategy_code: str
    strategy_name: str
    parameters: dict[str, object]
    enabled: bool = True


_DEFAULT_SIGNAL_SCAN_CONFIGS = (
    SignalScanConfig(
        strategy_code="price_break_ma",
        strategy_name="Price Break MA",
        parameters={"ma_window": 5, "direction": "both"},
    ),
    SignalScanConfig(
        strategy_code="price_break_ma",
        strategy_name="Price Break MA",
        parameters={"ma_window": 10, "direction": "both"},
    ),
    SignalScanConfig(
        strategy_code="price_break_ma",
        strategy_name="Price Break MA",
        parameters={"ma_window": 20, "direction": "both"},
    ),
    SignalScanConfig(
        strategy_code="ma_cross",
        strategy_name="MA Cross",
        parameters={"short_window": 5, "long_window": 20},
    ),
    SignalScanConfig(
        strategy_code="rsi_reversal",
        strategy_name="RSI Reversal",
        parameters={"rsi_window": 14, "oversold": 30, "overbought": 70},
    ),
    SignalScanConfig(
        strategy_code="macd_trend",
        strategy_name="MACD Trend",
        parameters={"fast_window": 12, "slow_window": 26, "signal_window": 9},
    ),
)


def list_signal_scan_configs() -> list[SignalScanConfig]:
    return [
        replace(config, parameters=dict(config.parameters))
        for config in _DEFAULT_SIGNAL_SCAN_CONFIGS
        if config.enabled
    ]
