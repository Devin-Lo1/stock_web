from datetime import datetime, timezone

from .. import database
from ..schemas import BacktestEquityPoint, BacktestResult, BacktestRun, BacktestTrade


def run_backtest(run: BacktestRun) -> BacktestResult:
    if run.strategy_code != "ma_cross":
        return _fail_run(run, "unsupported_strategy")

    short_window = int(run.parameters.get("short_window", 5))
    long_window = int(run.parameters.get("long_window", 20))
    if short_window <= 0 or long_window <= 0 or short_window >= long_window:
        return _fail_run(run, "invalid_ma_parameters")

    candles = database.list_candles_between(
        run.stock_code,
        run.period,
        run.start_date,
        run.end_date,
    )
    if len(candles) < long_window:
        return _fail_run(run, "not_enough_candles")

    cash = run.initial_cash
    position_quantity = 0.0
    peak_equity = run.initial_cash
    previous_short_ma: float | None = None
    previous_long_ma: float | None = None
    equity_curve: list[BacktestEquityPoint] = []
    trades: list[BacktestTrade] = []

    closes = [candle.close for candle in candles]
    for index, candle in enumerate(candles):
        if index + 1 < long_window:
            continue

        short_ma = _mean(closes[index + 1 - short_window : index + 1])
        long_ma = _mean(closes[index + 1 - long_window : index + 1])

        if previous_short_ma is not None and previous_long_ma is not None:
            if previous_short_ma <= previous_long_ma and short_ma > long_ma:
                trade = _buy(run, candle.time, candle.close, cash, run.fee_rate, run.slippage_rate)
                if trade is not None:
                    trades.append(trade)
                    cash = trade.cash_after
                    position_quantity = trade.position_after
            elif previous_short_ma >= previous_long_ma and short_ma < long_ma:
                trade = _sell(
                    run,
                    candle.time,
                    candle.close,
                    cash,
                    position_quantity,
                    run.fee_rate,
                    run.slippage_rate,
                )
                if trade is not None:
                    trades.append(trade)
                    cash = trade.cash_after
                    position_quantity = trade.position_after

        market_value = position_quantity * candle.close
        equity = cash + market_value
        peak_equity = max(peak_equity, equity)
        drawdown = 0 if peak_equity == 0 else equity / peak_equity - 1
        equity_curve.append(
            BacktestEquityPoint(
                run_id=run.id,
                time=candle.time,
                equity=equity,
                cash=cash,
                position_quantity=position_quantity,
                market_value=market_value,
                drawdown=drawdown,
            ),
        )

        previous_short_ma = short_ma
        previous_long_ma = long_ma

    final_equity = equity_curve[-1].equity if equity_curve else run.initial_cash
    completed = run.model_copy(
        update={
            "status": "completed",
            "summary": {
                "strategy_code": run.strategy_code,
                "stock_code": run.stock_code,
                "period": run.period,
                "start_date": run.start_date.isoformat(),
                "end_date": run.end_date.isoformat(),
                "initial_cash": run.initial_cash,
                "final_equity": final_equity,
                "total_return": final_equity / run.initial_cash - 1,
                "max_drawdown": min((point.drawdown for point in equity_curve), default=0),
                "trade_count": len(trades),
                "candle_count": len(candles),
            },
            "updated_at": datetime.now(timezone.utc),
        },
    )
    return database.save_backtest_result(completed, equity_curve, trades)


def _fail_run(run: BacktestRun, reason: str) -> BacktestResult:
    failed = run.model_copy(
        update={
            "status": "failed",
            "summary": {"error": reason},
            "updated_at": datetime.now(timezone.utc),
        },
    )
    return database.save_backtest_result(failed, [], [])


def _buy(
    run: BacktestRun,
    trade_time: datetime,
    close_price: float,
    cash: float,
    fee_rate: float,
    slippage_rate: float,
) -> BacktestTrade | None:
    if cash <= 0:
        return None
    slippage = close_price * slippage_rate
    price = close_price + slippage
    quantity = cash / (price * (1 + fee_rate))
    if quantity <= 0:
        return None
    gross_amount = quantity * price
    fee = gross_amount * fee_rate
    cash_after = cash - gross_amount - fee
    return BacktestTrade(
        run_id=run.id,
        time=trade_time,
        side="buy",
        price=price,
        quantity=quantity,
        fee=fee,
        slippage=slippage,
        cash_after=max(0, cash_after),
        position_after=quantity,
    )


def _sell(
    run: BacktestRun,
    trade_time: datetime,
    close_price: float,
    cash: float,
    position_quantity: float,
    fee_rate: float,
    slippage_rate: float,
) -> BacktestTrade | None:
    if position_quantity <= 0:
        return None
    slippage = close_price * slippage_rate
    price = close_price - slippage
    gross_amount = position_quantity * price
    fee = gross_amount * fee_rate
    cash_after = cash + gross_amount - fee
    return BacktestTrade(
        run_id=run.id,
        time=trade_time,
        side="sell",
        price=price,
        quantity=position_quantity,
        fee=fee,
        slippage=slippage,
        cash_after=cash_after,
        position_after=0,
    )


def _mean(values: list[float]) -> float:
    return sum(values) / len(values)
