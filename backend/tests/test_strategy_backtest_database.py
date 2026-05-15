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
    assert result.run.status == "created"
    assert result.run.start_date == date(2025, 1, 1)
    assert result.run.end_date == date(2026, 5, 14)
    assert result.run.parameters["long_window"] == 20
    assert result.equity_curve == []
    assert result.trades == []


def test_missing_backtest_result_returns_none() -> None:
    assert database.get_backtest_result("missing") is None


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
    assert len(result.equity_curve) == 16
    assert saved is not None
    assert saved.run.status == "completed"
    assert len(saved.equity_curve) == len(result.equity_curve)
    assert len(saved.trades) == len(result.trades)
    assert saved.run.summary["trade_count"] == result.run.summary["trade_count"]


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
