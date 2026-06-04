from datetime import UTC, date, datetime, timedelta

from app.schemas import (
    Candle,
    PersonalizedStrategyDecision,
    PersonalizedStrategyScanResult,
)
from app.services import personalized_strategies as service


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
        "personal_qqq_sma34_77_steady",
        "personal_qqq_channel41_aggressive",
    }
    assert template is not None
    assert template.code == "personal_qqq_sma34_77_steady"
    assert template.risk_level == "steady"

    steady = service.get_personalized_strategy_template(
        "personal_qqq_sma34_77_steady"
    )
    aggressive = service.get_personalized_strategy_template(
        "personal_qqq_channel41_aggressive"
    )

    assert steady is not None
    assert aggressive is not None
    assert steady.parameters["engine"] == "ma_cross"
    assert steady.parameters["short_window"] == 34
    assert steady.parameters["long_window"] == 77
    assert steady.parameters["trend_ma"] == 120
    assert steady.parameters["benchmark_ma"] == 80
    assert steady.parameters["benchmark_roc_days"] == 80
    assert steady.parameters["benchmark_roc_min"] == 0.0
    assert steady.parameters["relative_strength_days"] == 60
    assert steady.parameters["relative_strength_min"] == -0.02
    assert steady.parameters["exit_ma"] == 120
    assert "fixed_stop" not in steady.parameters
    assert steady.parameters["trailing_stop"] == 0.20
    assert steady.parameters["take_profit"] == 0.06
    assert steady.parameters["max_hold_days"] == 60

    assert aggressive.risk_level == "aggressive"
    assert aggressive.parameters["engine"] == "channel"
    assert aggressive.parameters["entry_channel_days"] == 41
    assert aggressive.parameters["exit_channel_days"] == 65
    assert aggressive.parameters["trend_ma"] == 200
    assert aggressive.parameters["benchmark_ma"] == 120
    assert aggressive.parameters["benchmark_roc_days"] == 40
    assert aggressive.parameters["benchmark_roc_min"] == 0.0
    assert aggressive.parameters["own_roc_days"] == 40
    assert aggressive.parameters["own_roc_min"] == 0.04
    assert aggressive.parameters["relative_strength_days"] == 20
    assert aggressive.parameters["relative_strength_min"] == -0.04
    assert aggressive.parameters["exit_ma"] == 150
    assert aggressive.parameters["fixed_stop"] == 0.06
    assert aggressive.parameters["trailing_stop"] == 0.24
    assert aggressive.parameters["take_profit"] == 0.08
    assert aggressive.parameters["max_hold_days"] == 30


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
