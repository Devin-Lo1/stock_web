from datetime import date, datetime, timedelta, timezone

from app import database
from app.backtest import run_backtest
from app.schemas import BacktestCreate, Candle, StrategyDefinitionCreate


def test_strategy_definition_upsert_and_list() -> None:
    strategy = database.create_strategy_definition(
        StrategyDefinitionCreate(
            code="ma_cross",
            name="MA Cross",
            description="Moving average crossover baseline strategy.",
            default_parameters={"short_window": 5, "long_window": 20},
        ),
    )

    rows = database.list_strategy_definitions()

    assert len(rows) == 1
    assert rows[0].code == strategy.code
    assert rows[0].default_parameters["short_window"] == 5


def test_seed_strategy_definitions_includes_rsi() -> None:
    database.init_database(seed_defaults=True)

    rows = database.list_strategy_definitions()
    by_code = {row.code: row for row in rows}

    assert "ma_cross" in by_code
    assert "rsi_reversal" in by_code
    assert by_code["rsi_reversal"].default_parameters["rsi_window"] == 14


def test_backtest_run_create_and_get_result() -> None:
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.02628",
            period="day",
            start_date=date(2025, 1, 1),
            end_date=date(2026, 5, 14),
            initial_cash=100000,
            fee_rate=0.0003,
            slippage_rate=0.0005,
            parameters={"short_window": 5, "long_window": 20},
        ),
    )

    result = database.get_backtest_result(run.id)

    assert result is not None
    assert result.run.id == run.id
    assert result.run.name
    assert result.run.status == "created"
    assert result.run.start_date == date(2025, 1, 1)
    assert result.run.end_date == date(2026, 5, 14)
    assert result.run.parameters["long_window"] == 20
    assert result.equity_curve == []
    assert result.trades == []


def test_list_backtest_runs_returns_recent_summaries() -> None:
    first = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.02628",
            period="day",
            start_date=date(2025, 1, 1),
            end_date=date(2026, 5, 14),
            initial_cash=100000,
            fee_rate=0.0003,
            slippage_rate=0.0005,
            parameters={"short_window": 5, "long_window": 20},
        ),
    )
    second = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.00700",
            period="day",
            start_date=date(2025, 1, 1),
            end_date=date(2026, 5, 14),
            initial_cash=100000,
            fee_rate=0.0003,
            slippage_rate=0.0005,
            parameters={"short_window": 5, "long_window": 20},
        ),
    )

    rows = database.list_backtest_runs(limit=10)
    filtered = database.list_backtest_runs(stock_code="hk.02628", limit=10)

    assert [row.id for row in rows] == [second.id, first.id]
    assert [row.id for row in filtered] == [first.id]


def test_rename_backtest_run_updates_name() -> None:
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.02628",
            period="day",
            start_date=date(2025, 1, 1),
            end_date=date(2026, 5, 14),
            initial_cash=100000,
            fee_rate=0.0003,
            slippage_rate=0.0005,
            parameters={"short_window": 5, "long_window": 20},
        ),
    )

    renamed = database.rename_backtest_run(run.id, "  中国人寿 MA5/20  ")
    missing = database.rename_backtest_run("missing", "Noop")
    result = database.get_backtest_result(run.id)

    assert renamed is not None
    assert renamed.name == "中国人寿 MA5/20"
    assert result is not None
    assert result.run.name == "中国人寿 MA5/20"
    assert missing is None


def test_missing_backtest_result_returns_none() -> None:
    assert database.get_backtest_result("missing") is None


def test_delete_backtest_run_removes_result() -> None:
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.02628",
            period="day",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 1, 20),
            initial_cash=100000,
            fee_rate=0.001,
            slippage_rate=0.001,
            parameters={"short_window": 3, "long_window": 5},
        ),
    )

    assert database.delete_backtest_run(run.id) is True
    assert database.get_backtest_result(run.id) is None
    assert database.delete_backtest_run(run.id) is False


def test_delete_all_backtest_runs_removes_history() -> None:
    first = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.02628",
            period="day",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 1, 20),
            initial_cash=100000,
            fee_rate=0.001,
            slippage_rate=0.001,
            parameters={"short_window": 3, "long_window": 5},
        ),
    )
    second = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.00700",
            period="day",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 1, 20),
            initial_cash=100000,
            fee_rate=0.001,
            slippage_rate=0.001,
            parameters={"short_window": 3, "long_window": 5},
        ),
    )

    assert database.delete_all_backtest_runs() == 2
    assert database.get_backtest_result(first.id) is None
    assert database.get_backtest_result(second.id) is None
    assert database.list_backtest_runs(limit=10) == []


def test_ma_cross_backtest_generates_result() -> None:
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    closes = [
        10,
        10,
        10,
        10,
        10,
        11,
        12,
        13,
        14,
        15,
        14,
        13,
        12,
        11,
        10,
        9,
        8,
        7,
        6,
        5,
    ]
    candles = [
        Candle(
            code="HK.02628",
            market="HK",
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
    database.upsert_candles(candles)
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.02628",
            period="day",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 1, 20),
            initial_cash=100000,
            fee_rate=0.001,
            slippage_rate=0.001,
            parameters={"short_window": 3, "long_window": 5},
        ),
    )

    result = run_backtest(run)
    saved = database.get_backtest_result(run.id)

    assert result.run.status == "completed"
    assert result.run.summary["trade_count"] >= 1
    assert "win_rate" in result.run.summary
    assert "round_trip_count" in result.run.summary
    assert len(result.equity_curve) == 16
    assert saved is not None
    assert saved.run.status == "completed"
    assert len(saved.equity_curve) == len(result.equity_curve)
    assert len(saved.trades) == len(result.trades)
    assert saved.run.summary["trade_count"] == result.run.summary["trade_count"]
    assert saved.run.summary["win_rate"] == result.run.summary["win_rate"]


def test_ma_cross_backtest_failure_has_readable_message() -> None:
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.02628",
            period="day",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 1, 20),
            initial_cash=100000,
            fee_rate=0.001,
            slippage_rate=0.001,
            parameters={"short_window": 20, "long_window": 5},
        ),
    )

    result = run_backtest(run)

    assert result.run.status == "failed"
    assert result.run.summary["error"] == "invalid_ma_parameters"
    assert result.run.summary["error_message"]


def test_rsi_reversal_backtest_generates_result() -> None:
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    closes = [
        50,
        48,
        46,
        44,
        42,
        40,
        38,
        36,
        34,
        32,
        30,
        32,
        34,
        36,
        38,
        40,
        42,
        44,
        46,
        48,
        50,
        52,
        54,
        56,
        58,
        56,
        54,
        52,
        50,
        48,
    ]
    candles = [
        Candle(
            code="HK.02628",
            market="HK",
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
    database.upsert_candles(candles)
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="rsi_reversal",
            stock_code="HK.02628",
            period="day",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 1, 30),
            initial_cash=100000,
            fee_rate=0.001,
            slippage_rate=0.001,
            parameters={"rsi_window": 5, "oversold": 30, "overbought": 70},
        ),
    )

    result = run_backtest(run)
    saved = database.get_backtest_result(run.id)

    assert result.run.status == "completed"
    assert result.run.summary["strategy_code"] == "rsi_reversal"
    assert result.run.summary["trade_count"] >= 1
    assert "win_rate" in result.run.summary
    assert "round_trip_count" in result.run.summary
    assert saved is not None
    assert saved.run.status == "completed"
    assert len(saved.trades) == len(result.trades)
    assert all(trade.quantity > 0.000001 for trade in result.trades)
    assert min(point.equity for point in result.equity_curve) > 0


def test_rsi_reversal_repeated_buy_signals_do_not_replace_existing_position() -> None:
    start = datetime(2026, 2, 1, tzinfo=timezone.utc)
    closes = [
        50,
        45,
        40,
        35,
        30,
        32,
        31,
        32,
        31,
        32,
        31,
        32,
        31,
        32,
        31,
        32,
        31,
        32,
        31,
        32,
    ]
    candles = [
        Candle(
            code="HK.00700",
            market="HK",
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
    database.upsert_candles(candles)
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="rsi_reversal",
            stock_code="HK.00700",
            period="day",
            start_date=date(2026, 2, 1),
            end_date=date(2026, 2, 20),
            initial_cash=100000,
            fee_rate=0.001,
            slippage_rate=0.001,
            parameters={"rsi_window": 2, "oversold": 45, "overbought": 95},
        ),
    )

    result = run_backtest(run)
    buy_trades = [trade for trade in result.trades if trade.side == "buy"]

    assert result.run.status == "completed"
    assert len(buy_trades) == 1
    assert buy_trades[0].quantity > 0.000001
    assert min(point.equity for point in result.equity_curve) > 1000


def test_backtest_summary_win_rate_counts_completed_round_trips() -> None:
    start = datetime(2026, 3, 1, tzinfo=timezone.utc)
    closes = [
        10,
        10,
        10,
        10,
        10,
        11,
        12,
        13,
        14,
        15,
        14,
        13,
        12,
        11,
        10,
        9,
        8,
        7,
        6,
        5,
        6,
        7,
        8,
        9,
        10,
        9,
        8,
        7,
        6,
        5,
    ]
    candles = [
        Candle(
            code="HK.03988",
            market="HK",
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
    database.upsert_candles(candles)
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="ma_cross",
            stock_code="HK.03988",
            period="day",
            start_date=date(2026, 3, 1),
            end_date=date(2026, 3, 30),
            initial_cash=100000,
            fee_rate=0,
            slippage_rate=0,
            parameters={"short_window": 3, "long_window": 5},
        ),
    )

    result = run_backtest(run)

    assert result.run.status == "completed"
    assert result.run.summary["round_trip_count"] >= 1
    assert 0 <= result.run.summary["win_rate"] <= 1
    assert (
        result.run.summary["win_count"] + result.run.summary["loss_count"]
        == result.run.summary["round_trip_count"]
    )


def test_rsi_reversal_invalid_parameters_have_readable_message() -> None:
    run = database.create_backtest_run(
        BacktestCreate(
            strategy_code="rsi_reversal",
            stock_code="HK.02628",
            period="day",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 1, 30),
            initial_cash=100000,
            fee_rate=0.001,
            slippage_rate=0.001,
            parameters={"rsi_window": 1, "oversold": 70, "overbought": 30},
        ),
    )

    result = run_backtest(run)

    assert result.run.status == "failed"
    assert result.run.summary["error"] == "invalid_rsi_parameters"
    assert result.run.summary["error_message"]
