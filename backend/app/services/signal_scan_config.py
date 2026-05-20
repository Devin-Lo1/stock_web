from dataclasses import dataclass
from datetime import datetime, timezone

from ..repositories.signal_scan_configs import (
    list_signal_scan_configs as list_persisted_signal_scan_configs,
)
from ..schemas import SignalScanConfig, SignalScanConfigCreate


@dataclass(frozen=True)
class DefaultSignalScanConfig:
    id: str
    strategy_code: str
    strategy_name: str
    parameters: dict[str, object]
    enabled: bool = True
    push_candidate: bool = True
    sort_order: int = 0


_DEFAULT_SIGNAL_SCAN_CONFIGS = (
    DefaultSignalScanConfig(
        id="price_break_ma_ma5",
        strategy_code="price_break_ma",
        strategy_name="Price Break MA",
        parameters={"ma_window": 5, "direction": "both"},
        sort_order=10,
    ),
    DefaultSignalScanConfig(
        id="price_break_ma_ma10",
        strategy_code="price_break_ma",
        strategy_name="Price Break MA",
        parameters={"ma_window": 10, "direction": "both"},
        sort_order=20,
    ),
    DefaultSignalScanConfig(
        id="price_break_ma_ma20",
        strategy_code="price_break_ma",
        strategy_name="Price Break MA",
        parameters={"ma_window": 20, "direction": "both"},
        sort_order=30,
    ),
    DefaultSignalScanConfig(
        id="ma_cross_5_20",
        strategy_code="ma_cross",
        strategy_name="MA Cross",
        parameters={"short_window": 5, "long_window": 20},
        sort_order=40,
    ),
    DefaultSignalScanConfig(
        id="rsi_reversal_14_30_70",
        strategy_code="rsi_reversal",
        strategy_name="RSI Reversal",
        parameters={"rsi_window": 14, "oversold": 30, "overbought": 70},
        sort_order=50,
    ),
    DefaultSignalScanConfig(
        id="macd_trend_12_26_9",
        strategy_code="macd_trend",
        strategy_name="MACD Trend",
        parameters={"fast_window": 12, "slow_window": 26, "signal_window": 9},
        sort_order=60,
    ),
)


def default_signal_scan_configs() -> list[tuple[str, SignalScanConfigCreate]]:
    return [
        (
            config.id,
            SignalScanConfigCreate(
                strategy_code=config.strategy_code,
                strategy_name=config.strategy_name,
                parameters=dict(config.parameters),
                enabled=config.enabled,
                push_candidate=config.push_candidate,
                sort_order=config.sort_order,
            ),
        )
        for config in _DEFAULT_SIGNAL_SCAN_CONFIGS
    ]


def list_signal_scan_configs() -> list[SignalScanConfig]:
    persisted_configs = list_persisted_signal_scan_configs(enabled_only=False)
    if persisted_configs:
        return [config for config in persisted_configs if config.enabled]
    return [
        _runtime_config(config_id, payload)
        for config_id, payload in default_signal_scan_configs()
        if payload.enabled
    ]


def _runtime_config(
    config_id: str,
    payload: SignalScanConfigCreate,
) -> SignalScanConfig:
    now = datetime.now(timezone.utc)
    return SignalScanConfig(
        id=config_id,
        created_at=now,
        updated_at=now,
        **payload.model_dump(),
    )
