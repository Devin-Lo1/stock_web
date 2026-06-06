from datetime import date, datetime, timedelta, timezone

from app.schemas import (
    Candle,
    PersonalizedStrategyDecision,
    PersonalizedStrategyScanResult,
)
from app.services import personalized_strategies as service

UTC = timezone.utc


def test_nvda_personalized_templates_include_aggressive_and_steady() -> None:
    templates = service.list_personalized_strategy_templates()
    nvda_templates = [item for item in templates if item.symbol == "US.NVDA"]

    assert {item.code for item in nvda_templates} >= {
        "personal_nvda_channel35",
        "personal_nvda_ma30_40_steady",
    }
    assert service.get_personalized_strategy_template(
        "US.NVDA"
    ).code == "personal_nvda_ma30_40_steady"
    assert service.get_personalized_strategy_template(
        "personal_nvda_channel35"
    ).risk_level == "aggressive"

    aggressive = service.get_personalized_strategy_template(
        "personal_nvda_channel35"
    )
    assert aggressive is not None
    assert aggressive.parameters["engine"] == "channel"
    assert aggressive.parameters["entry_channel_days"] == 15
    assert aggressive.parameters["exit_channel_days"] == 57
    assert aggressive.parameters["benchmark_ma"] == 80
    assert aggressive.parameters["benchmark_ma_kind"] == "ema"
    assert aggressive.parameters["benchmark_roc_days"] == 60
    assert aggressive.parameters["own_roc_days"] == 80
    assert aggressive.parameters["own_roc_min"] == -0.08
    assert aggressive.parameters["relative_strength_days"] == 80
    assert aggressive.parameters["own_slope_days"] == 20
    assert aggressive.parameters["own_slope_min"] == 0.0015
    assert aggressive.parameters["benchmark_slope_days"] == 20
    assert aggressive.parameters["benchmark_slope_min"] == 0.0005
    assert aggressive.parameters["atr_days"] == 50
    assert aggressive.parameters["atr_pct_min"] == 0.01
    assert aggressive.parameters["atr_pct_max"] == 0.06
    assert aggressive.parameters["volume_window"] == 20
    assert aggressive.parameters["volume_ratio_min"] == 0.8
    assert aggressive.parameters["exit_ma"] == 40
    assert aggressive.parameters["fixed_stop"] == 0.2
    assert aggressive.parameters["trailing_stop"] == 0.24
    assert aggressive.parameters["take_profit"] == 0.2
    assert aggressive.parameters["atr_stop_mult"] == 2.0
    assert aggressive.parameters["atr_trail_mult"] == 4.0
    assert aggressive.parameters["filtered_reverse_exit"] is False

    steady = service.get_personalized_strategy_template(
        "personal_nvda_ma30_40_steady"
    )
    assert steady is not None
    assert steady.risk_level == "steady"
    assert steady.parameters["engine"] == "ma_cross"
    assert steady.parameters["short_window"] == 30
    assert steady.parameters["long_window"] == 40
    assert steady.parameters["filtered_reverse_exit"] is True


def test_googl_personalized_templates_include_aggressive_and_steady() -> None:
    templates = service.list_personalized_strategy_templates()
    googl_templates = [item for item in templates if item.symbol == "US.GOOGL"]

    assert {item.code for item in googl_templates} >= {
        "personal_googl_sma5_113_aggressive",
        "personal_googl_sma5_113_steady",
    }
    assert service.get_personalized_strategy_template(
        "US.GOOGL"
    ).code == "personal_googl_sma5_113_steady"

    aggressive = service.get_personalized_strategy_template(
        "personal_googl_sma5_113_aggressive"
    )
    steady = service.get_personalized_strategy_template(
        "personal_googl_sma5_113_steady"
    )

    assert aggressive is not None
    assert steady is not None
    assert aggressive.risk_level == "aggressive"
    assert steady.risk_level == "steady"
    assert aggressive.parameters["benchmark_roc_days"] == 120
    assert aggressive.parameters["max_hold_days"] == 60
    assert aggressive.parameters["filtered_reverse_exit"] is True
    assert steady.parameters["own_roc_days"] == 80
    assert steady.parameters["relative_strength_days"] == 20
    assert steady.parameters["max_hold_days"] == 40


def test_qqq_personalized_templates_include_aggressive_and_steady() -> None:
    templates = service.list_personalized_strategy_templates()
    qqq_templates = [item for item in templates if item.symbol == "US.QQQ"]
    template = service.get_personalized_strategy_template("US.QQQ")

    assert {item.code for item in qqq_templates} >= {
        "personal_qqq_sma7_111_steady",
        "personal_qqq_sma12_101_aggressive",
    }
    assert template is not None
    assert template.code == "personal_qqq_sma7_111_steady"
    assert template.risk_level == "steady"

    steady = service.get_personalized_strategy_template(
        "personal_qqq_sma7_111_steady"
    )
    aggressive = service.get_personalized_strategy_template(
        "personal_qqq_sma12_101_aggressive"
    )

    assert steady is not None
    assert aggressive is not None
    assert steady.parameters["engine"] == "ma_cross"
    assert steady.parameters["short_window"] == 7
    assert steady.parameters["long_window"] == 111
    assert "trend_ma" not in steady.parameters
    assert steady.parameters["benchmark_ma"] == 120
    assert steady.parameters["own_roc_days"] == 20
    assert steady.parameters["own_roc_min"] == 0.02
    assert steady.parameters["exit_ma"] == 150
    assert steady.parameters["fixed_stop"] == 0.10
    assert steady.parameters["trailing_stop"] == 0.10
    assert steady.parameters["take_profit"] == 0.14
    assert "max_hold_days" not in steady.parameters
    assert steady.parameters["filtered_reverse_exit"] is True

    assert aggressive.risk_level == "aggressive"
    assert aggressive.parameters["engine"] == "ma_cross"
    assert aggressive.parameters["short_window"] == 12
    assert aggressive.parameters["long_window"] == 101
    assert aggressive.parameters["trend_ma"] == 50
    assert aggressive.parameters["benchmark_ma"] == 150
    assert aggressive.parameters["own_roc_days"] == 80
    assert aggressive.parameters["own_roc_min"] == -0.12
    assert "exit_ma" not in aggressive.parameters
    assert "fixed_stop" not in aggressive.parameters
    assert "trailing_stop" not in aggressive.parameters
    assert "max_hold_days" not in aggressive.parameters
    assert aggressive.parameters["take_profit"] == 0.12
    assert aggressive.parameters["filtered_reverse_exit"] is True
    assert aggressive.parameters["use_trend_ma_as_exit"] is False


def test_msft_personalized_templates_include_aggressive_and_steady() -> None:
    templates = service.list_personalized_strategy_templates()
    msft_templates = [item for item in templates if item.symbol == "US.MSFT"]
    template = service.get_personalized_strategy_template("US.MSFT")

    assert {item.code for item in msft_templates} >= {
        "personal_msft_channel61_steady",
        "personal_msft_channel59_aggressive",
    }
    assert template is not None
    assert template.code == "personal_msft_channel61_steady"
    assert template.direction_mode == "long_short"
    assert template.risk_level == "steady"

    steady = service.get_personalized_strategy_template(
        "personal_msft_channel61_steady"
    )
    aggressive = service.get_personalized_strategy_template(
        "personal_msft_channel59_aggressive"
    )

    assert steady is not None
    assert aggressive is not None
    assert steady.parameters["engine"] == "channel"
    assert steady.parameters["entry_channel_days"] == 61
    assert steady.parameters["exit_channel_days"] == 62
    assert steady.parameters["trend_ma"] == 80
    assert steady.parameters["benchmark_roc_days"] == 60
    assert steady.parameters["benchmark_roc_min"] == -0.08
    assert steady.parameters["own_roc_days"] == 120
    assert steady.parameters["own_roc_min"] == 0.04
    assert steady.parameters["relative_strength_days"] == 20
    assert steady.parameters["relative_strength_min"] == 0.04
    assert steady.parameters["exit_ma"] == 120
    assert steady.parameters["fixed_stop"] == 0.08
    assert steady.parameters["trailing_stop"] == 0.16
    assert steady.parameters["take_profit"] == 0.10
    assert steady.parameters["max_hold_days"] == 50

    assert aggressive.risk_level == "aggressive"
    assert aggressive.parameters["engine"] == "channel"
    assert aggressive.parameters["entry_channel_days"] == 59
    assert aggressive.parameters["exit_channel_days"] == 73
    assert aggressive.parameters["trend_ma"] == 120
    assert aggressive.parameters["own_roc_days"] == 40
    assert aggressive.parameters["own_roc_min"] == 0.02
    assert aggressive.parameters["relative_strength_days"] == 40
    assert aggressive.parameters["relative_strength_min"] == 0.02
    assert aggressive.parameters["exit_ma"] == 200
    assert aggressive.parameters["trailing_stop"] == 0.20
    assert aggressive.parameters["take_profit"] == 0.10
    assert "fixed_stop" not in aggressive.parameters
    assert "max_hold_days" not in aggressive.parameters


def test_amd_personalized_templates_include_aggressive_and_steady() -> None:
    templates = service.list_personalized_strategy_templates()
    amd_templates = [item for item in templates if item.symbol == "US.AMD"]

    assert {item.code for item in amd_templates} >= {
        "personal_amd_ma10_20_steady",
        "personal_amd_channel66_aggressive",
    }
    assert service.get_personalized_strategy_template(
        "US.AMD"
    ).code == "personal_amd_ma10_20_steady"

    steady = service.get_personalized_strategy_template(
        "personal_amd_ma10_20_steady"
    )
    aggressive = service.get_personalized_strategy_template(
        "personal_amd_channel66_aggressive"
    )

    assert steady is not None
    assert aggressive is not None
    assert steady.risk_level == "steady"
    assert aggressive.risk_level == "aggressive"
    assert steady.parameters["engine"] == "ma_cross"
    assert steady.parameters["short_window"] == 10
    assert steady.parameters["long_window"] == 20
    assert steady.parameters["trend_ma"] == 100
    assert steady.parameters["benchmark_ma"] == 100
    assert steady.parameters["benchmark_roc_min"] == 0.06
    assert steady.parameters["exit_ma"] == 120
    assert steady.parameters["filtered_reverse_exit"] is True
    assert "max_hold_days" not in steady.parameters
    assert aggressive.parameters["engine"] == "channel"
    assert aggressive.parameters["entry_channel_days"] == 66
    assert aggressive.parameters["exit_channel_days"] == 43
    assert aggressive.parameters["trend_ma"] == 80
    assert aggressive.parameters["benchmark_ma"] == 50
    assert aggressive.parameters["benchmark_roc_min"] == 0.04
    assert aggressive.parameters["own_roc_min"] == 0.08
    assert aggressive.parameters["relative_strength_min"] == 0.06
    assert aggressive.parameters["take_profit"] == 0.20
    assert "max_hold_days" not in aggressive.parameters
    assert "exit_ma" not in aggressive.parameters


def test_mu_personalized_templates_include_aggressive_and_steady() -> None:
    templates = service.list_personalized_strategy_templates()
    mu_templates = [item for item in templates if item.symbol == "US.MU"]
    template = service.get_personalized_strategy_template("US.MU")

    assert {item.code for item in mu_templates} >= {
        "personal_mu_sma24_40_steady",
        "personal_mu_channel48_aggressive",
    }
    assert template is not None
    assert template.code == "personal_mu_sma24_40_steady"
    assert template.symbol == "US.MU"
    assert template.risk_level == "steady"

    steady = service.get_personalized_strategy_template(
        "personal_mu_sma24_40_steady"
    )
    aggressive = service.get_personalized_strategy_template(
        "personal_mu_channel48_aggressive"
    )

    assert steady is not None
    assert aggressive is not None
    assert steady.parameters["engine"] == "ma_cross"
    assert steady.parameters["short_window"] == 24
    assert steady.parameters["long_window"] == 40
    assert steady.parameters["trend_ma"] == 150
    assert steady.parameters["benchmark_ma"] == 120
    assert steady.parameters["own_roc_days"] == 120
    assert steady.parameters["own_roc_min"] == 0.02
    assert steady.parameters["relative_strength_days"] == 80
    assert steady.parameters["relative_strength_min"] == 0.06
    assert steady.parameters["exit_ma"] == 150
    assert steady.parameters["trailing_stop"] == 0.10
    assert steady.parameters["take_profit"] == 0.16
    assert "fixed_stop" not in steady.parameters
    assert "max_hold_days" not in steady.parameters

    assert aggressive.risk_level == "aggressive"
    assert aggressive.parameters["engine"] == "channel"
    assert aggressive.parameters["entry_channel_days"] == 48
    assert aggressive.parameters["exit_channel_days"] == 25
    assert aggressive.parameters["trend_ma"] == 100
    assert aggressive.parameters["benchmark_ma"] == 150
    assert aggressive.parameters["benchmark_roc_days"] == 120
    assert aggressive.parameters["benchmark_roc_min"] == 0.08
    assert aggressive.parameters["own_roc_days"] == 20
    assert aggressive.parameters["own_roc_min"] == -0.08
    assert aggressive.parameters["relative_strength_days"] == 20
    assert aggressive.parameters["relative_strength_min"] == -0.06
    assert aggressive.parameters["exit_ma"] == 100
    assert aggressive.parameters["trailing_stop"] == 0.24
    assert aggressive.parameters["take_profit"] == 0.08
    assert "fixed_stop" not in aggressive.parameters
    assert "max_hold_days" not in aggressive.parameters


def test_dell_personalized_templates_include_long_only_aggressive_and_steady() -> None:
    templates = service.list_personalized_strategy_templates()
    dell_templates = [item for item in templates if item.symbol == "US.DELL"]
    template = service.get_personalized_strategy_template("US.DELL")

    assert {item.code for item in dell_templates} >= {
        "personal_dell_channel19_steady",
        "personal_dell_channel42_aggressive",
    }
    assert template is not None
    assert template.code == "personal_dell_channel19_steady"
    assert template.direction_mode == "long_only"
    assert template.risk_level == "steady"

    steady = service.get_personalized_strategy_template(
        "personal_dell_channel19_steady"
    )
    aggressive = service.get_personalized_strategy_template(
        "personal_dell_channel42_aggressive"
    )

    assert steady is not None
    assert aggressive is not None
    assert steady.direction_mode == "long_only"
    assert steady.parameters["engine"] == "channel"
    assert steady.parameters["entry_channel_days"] == 19
    assert steady.parameters["exit_channel_days"] == 73
    assert steady.parameters["trend_ma"] == 100
    assert steady.parameters["benchmark_roc_days"] == 20
    assert steady.parameters["benchmark_roc_min"] == 0.06
    assert steady.parameters["own_roc_days"] == 20
    assert steady.parameters["own_roc_min"] == 0.06
    assert steady.parameters["relative_strength_days"] == 20
    assert steady.parameters["relative_strength_min"] == 0.02
    assert steady.parameters["trailing_stop"] == 0.10
    assert steady.parameters["take_profit"] == 0.16
    assert steady.parameters["max_hold_days"] == 20

    assert aggressive.direction_mode == "long_only"
    assert aggressive.risk_level == "aggressive"
    assert aggressive.parameters["engine"] == "channel"
    assert aggressive.parameters["entry_channel_days"] == 42
    assert aggressive.parameters["exit_channel_days"] == 70
    assert aggressive.parameters["benchmark_roc_days"] == 20
    assert aggressive.parameters["benchmark_roc_min"] == 0.0
    assert aggressive.parameters["fixed_stop"] == 0.16
    assert aggressive.parameters["trailing_stop"] == 0.16
    assert aggressive.parameters["take_profit"] == 0.12
    assert aggressive.parameters["max_hold_days"] == 50
    assert "trend_ma" not in aggressive.parameters


def test_aaoi_personalized_templates_include_long_only_aggressive_and_steady() -> None:
    templates = service.list_personalized_strategy_templates()
    aaoi_templates = [item for item in templates if item.symbol == "US.AAOI"]
    template = service.get_personalized_strategy_template("US.AAOI")

    assert {item.code for item in aaoi_templates} >= {
        "personal_aaoi_sma37_53_steady",
        "personal_aaoi_sma5_30_aggressive",
    }
    assert template is not None
    assert template.code == "personal_aaoi_sma37_53_steady"
    assert template.direction_mode == "long_only"
    assert template.risk_level == "steady"

    steady = service.get_personalized_strategy_template(
        "personal_aaoi_sma37_53_steady"
    )
    aggressive = service.get_personalized_strategy_template(
        "personal_aaoi_sma5_30_aggressive"
    )

    assert steady is not None
    assert aggressive is not None
    assert steady.direction_mode == "long_only"
    assert steady.parameters["engine"] == "ma_cross"
    assert steady.parameters["short_window"] == 37
    assert steady.parameters["long_window"] == 53
    assert steady.parameters["trend_ma"] == 50
    assert steady.parameters["benchmark_ma"] == 80
    assert steady.parameters["relative_strength_days"] == 40
    assert steady.parameters["relative_strength_min"] == 0.0
    assert steady.parameters["exit_ma"] == 120
    assert steady.parameters["fixed_stop"] == 0.08
    assert steady.parameters["take_profit"] == 0.08
    assert steady.parameters["max_hold_days"] == 60
    assert "trailing_stop" not in steady.parameters
    assert "filtered_reverse_exit" not in steady.parameters

    assert aggressive.direction_mode == "long_only"
    assert aggressive.risk_level == "aggressive"
    assert aggressive.parameters["engine"] == "ma_cross"
    assert aggressive.parameters["short_window"] == 5
    assert aggressive.parameters["long_window"] == 30
    assert aggressive.parameters["trend_ma"] == 100
    assert aggressive.parameters["own_roc_days"] == 60
    assert aggressive.parameters["own_roc_min"] == 0.0
    assert aggressive.parameters["exit_ma"] == 120
    assert aggressive.parameters["fixed_stop"] == 0.12
    assert aggressive.parameters["trailing_stop"] == 0.16
    assert aggressive.parameters["take_profit"] == 0.20
    assert aggressive.parameters["max_hold_days"] == 60
    assert "filtered_reverse_exit" not in aggressive.parameters


def test_ma_cross_entry_uses_momentum_and_relative_strength_filters() -> None:
    candles = _candles("US.NVDA", [10, 10, 9, 12])
    benchmark_candles = _candles("US.QQQ", [10, 10, 10, 11])
    closes = [item.close for item in candles]
    benchmark_closes = [item.close for item in benchmark_candles]
    params = {
        "short_window": 2,
        "long_window": 3,
        "trend_ma": 3,
        "benchmark_ma": 3,
        "own_roc_days": 1,
        "own_roc_min": 0.50,
        "relative_strength_days": 1,
        "relative_strength_min": -0.02,
    }

    blocked = service._ma_cross_entry_reason(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        3,
        3,
    )
    params["own_roc_min"] = 0.10
    allowed = service._ma_cross_entry_reason(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        3,
        3,
    )

    assert blocked is None
    assert allowed == ("long", "ma_cross_up_with_filters")


def test_long_only_channel_template_blocks_short_entry() -> None:
    candles = _candles("US.DELL", [10, 9, 8, 7])
    benchmark_candles = _candles("US.QQQ", [10, 9, 8, 7])
    closes = [item.close for item in candles]
    benchmark_closes = [item.close for item in benchmark_candles]
    config = {
        "direction_mode": "long_only",
        "parameters": {
            "engine": "channel",
            "entry_channel_days": 2,
        },
    }

    blocked = service._entry_reason(
        config,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        3,
        3,
    )

    assert blocked is None


def test_filtered_reverse_exit_requires_reverse_filters_to_pass() -> None:
    candles = _candles("US.NVDA", [10, 10, 14, 5])
    benchmark_candles = _candles("US.QQQ", [10, 10, 10, 11])
    closes = [item.close for item in candles]
    benchmark_closes = [item.close for item in benchmark_candles]
    position = service._Position(
        side="long",
        entry_price=10,
        entry_date=date(2026, 1, 1),
        high_since_entry=14,
        low_since_entry=5,
    )
    params = {
        "engine": "ma_cross",
        "short_window": 2,
        "long_window": 3,
        "trend_ma": None,
        "benchmark_ma": 3,
        "own_roc_days": 1,
        "own_roc_min": 0.10,
        "relative_strength_days": 1,
        "relative_strength_min": -0.02,
        "filtered_reverse_exit": True,
    }

    blocked = service._exit_reason(
        {"parameters": params},
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        3,
        3,
        position,
    )
    params["filtered_reverse_exit"] = False
    unfiltered = service._exit_reason(
        {"parameters": params},
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        3,
        3,
        position,
    )

    assert blocked is None
    assert unfiltered == "reverse_ma_cross"


def test_atr_percent_and_volume_filters_block_or_allow_entries() -> None:
    candles = _candles("US.NVDA", [100, 101, 102])
    benchmark_candles = _candles("US.QQQ", [100, 101, 102])
    closes = [item.close for item in candles]
    benchmark_closes = [item.close for item in benchmark_candles]
    params = {
        "atr_days": 2,
        "atr_pct_min": 0.02,
        "volume_window": 2,
        "volume_ratio_min": 1.0,
    }

    blocked = service._passes_long_filters(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        2,
        2,
    )
    params["atr_pct_min"] = 0.005
    allowed = service._passes_long_filters(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        2,
        2,
    )
    params["volume_ratio_min"] = 1.1
    volume_blocked = service._passes_long_filters(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        2,
        2,
    )

    assert blocked is False
    assert allowed is True
    assert volume_blocked is False


def test_slope_filters_apply_to_symbol_and_benchmark() -> None:
    candles = _candles("US.NVDA", [100, 101, 102, 104])
    benchmark_candles = _candles("US.QQQ", [100, 101, 102, 103])
    closes = [item.close for item in candles]
    benchmark_closes = [item.close for item in benchmark_candles]
    params = {
        "own_slope_days": 3,
        "own_slope_min": 0.001,
        "benchmark_slope_days": 3,
        "benchmark_slope_min": 0.001,
    }

    allowed = service._passes_long_filters(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        3,
        3,
    )
    params["benchmark_slope_min"] = 0.02
    blocked = service._passes_long_filters(
        params,
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        3,
        3,
    )

    assert allowed is True
    assert blocked is False


def test_atr_stop_and_atr_trailing_stop_exit_reasons() -> None:
    candles = _candles_from_ohlc(
        "US.NVDA",
        [
            (100, 100, 100),
            (105, 105, 105),
            (101, 93, 93),
        ],
    )
    benchmark_candles = _candles("US.QQQ", [100, 101, 102])
    closes = [item.close for item in candles]
    benchmark_closes = [item.close for item in benchmark_candles]
    position = service._Position(
        side="long",
        entry_price=100,
        entry_date=date(2026, 1, 1),
        high_since_entry=105,
        low_since_entry=93,
        highest_close_since_entry=105,
        lowest_close_since_entry=93,
    )

    atr_stop = service._exit_reason(
        {"parameters": {"engine": "channel", "atr_days": 1, "atr_stop_mult": 0.5}},
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        2,
        2,
        position,
    )
    atr_trailing = service._exit_reason(
        {
            "parameters": {
                "engine": "channel",
                "atr_days": 1,
                "atr_trail_mult": 0.5,
            }
        },
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        2,
        2,
        position,
    )

    assert atr_stop == "atr_stop"
    assert atr_trailing == "atr_trailing_stop"


def test_channel_strategy_can_use_entry_channel_as_reverse_exit() -> None:
    candles = _candles("US.NVDA", [10, 12, 8])
    benchmark_candles = _candles("US.QQQ", [10, 12, 8])
    closes = [item.close for item in candles]
    benchmark_closes = [item.close for item in benchmark_candles]
    position = service._Position(
        side="long",
        entry_price=12,
        entry_date=date(2026, 1, 2),
        high_since_entry=12,
        low_since_entry=8,
        highest_close_since_entry=12,
        lowest_close_since_entry=8,
    )

    reason = service._exit_reason(
        {
            "parameters": {
                "engine": "channel",
                "entry_channel_days": 2,
                "exit_channel_days": 5,
                "filtered_reverse_exit": False,
            }
        },
        candles,
        closes,
        benchmark_candles,
        benchmark_closes,
        2,
        2,
        position,
    )

    assert reason == "reverse_channel_breakdown"


def test_decision_detail_includes_replay_position_metadata() -> None:
    candles = _candles("US.NVDA", [10, 11, 13, 14])
    benchmark_candles = _candles("US.QQQ", [10, 11, 12, 13])
    replay = service._replay_strategy(
        {
            "parameters": {
                "engine": "channel",
                "entry_channel_days": 2,
                "max_hold_days": 20,
            },
            "direction_mode": "long_only",
        },
        candles,
        benchmark_candles,
    )
    template = service.get_personalized_strategy_template("personal_nvda_channel35")
    assert template is not None

    decision = service._decision_from_replay(
        template,
        replay,
        kind="previous_close",
        title="previous",
        is_realtime=False,
        is_confirmed=True,
    )

    assert decision.action == "hold_long"
    assert decision.current_position == "long"
    assert decision.signal_date == date(2026, 1, 3)
    assert decision.detail["position_entry_date"] == "2026-01-03"
    assert decision.detail["position_entry_price"] == 13
    assert decision.detail["position_hold_days"] == 1
    assert decision.detail["last_event"] == {
        "date": "2026-01-03",
        "action": "long_entry",
        "price": 13,
        "reason": "channel_breakout_with_filters",
    }


def test_personalized_recommendations_keep_best_long_candidate_per_symbol() -> None:
    googl_steady = service.get_personalized_strategy_template(
        "personal_googl_sma5_113_steady"
    )
    googl_aggressive = service.get_personalized_strategy_template(
        "personal_googl_sma5_113_aggressive"
    )
    nvda_steady = service.get_personalized_strategy_template(
        "personal_nvda_ma30_40_steady"
    )

    assert googl_steady is not None
    assert googl_aggressive is not None
    assert nvda_steady is not None

    recommendations = service._rank_personalized_recommendations(
        [
            _scan_result(googl_aggressive, "long_entry"),
            _scan_result(googl_steady, "hold_long"),
            _scan_result(nvda_steady, "short_entry"),
        ]
    )

    assert len(recommendations) == 1
    assert recommendations[0].symbol == "US.GOOGL"
    assert recommendations[0].template_code == "personal_googl_sma5_113_aggressive"
    assert recommendations[0].action == "long_entry"


def _scan_result(
    template,
    action: str,
) -> PersonalizedStrategyScanResult:
    action_label = {
        "long_entry": "做多观察",
        "hold_long": "持有多头",
        "short_entry": "做空观察",
    }.get(action, "无信号")
    decision = PersonalizedStrategyDecision(
        kind="strategy_signal",
        title="测试信号",
        action=action,
        action_label=action_label,
        current_position="flat",
        latest_date=date(2026, 6, 3),
        latest_price=100,
        signal_date=date(2026, 6, 3),
        reason="unit_test",
        flat_decision=action,
        long_decision=action,
        short_decision=action,
        is_realtime=False,
        is_confirmed=True,
        detail={},
    )
    return PersonalizedStrategyScanResult(
        template=template,
        status="completed",
        action=action,
        action_label=action_label,
        current_position="flat",
        latest_date=date(2026, 6, 3),
        latest_close=100,
        signal_date=date(2026, 6, 3),
        reason="unit_test",
        refresh_error=None,
        today_signal=decision,
        previous_close_signal=decision,
        detail={},
    )


def _candles(code: str, closes: list[float]) -> list[Candle]:
    start = datetime(2026, 1, 1, tzinfo=UTC)
    market = code.split(".", 1)[0]
    return [
        Candle(
            code=code,
            market=market,
            period="day",
            time=start + timedelta(days=index),
            open=close,
            high=close,
            low=close,
            close=close,
            volume=1000,
            turnover=close * 1000,
        )
        for index, close in enumerate(closes)
    ]


def _candles_from_ohlc(
    code: str,
    values: list[tuple[float, float, float]],
) -> list[Candle]:
    start = datetime(2026, 1, 1, tzinfo=UTC)
    market = code.split(".", 1)[0]
    return [
        Candle(
            code=code,
            market=market,
            period="day",
            time=start + timedelta(days=index),
            open=close,
            high=high,
            low=low,
            close=close,
            volume=1000,
            turnover=close * 1000,
        )
        for index, (high, low, close) in enumerate(values)
    ]
