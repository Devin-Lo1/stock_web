from datetime import datetime, timezone

from ..repositories.backtests import save_backtest_result
from ..repositories.market_data import list_candles_between
from ..schemas import BacktestEquityPoint, BacktestResult, BacktestRun, BacktestTrade
from ..strategies import get_strategy
from ..strategies.base import StrategyConfigurationError


def run_backtest(run: BacktestRun) -> BacktestResult:
    strategy = get_strategy(run.strategy_code)
    if strategy is None:
        return _fail_run(run, "unsupported_strategy")

    try:
        minimum_candles = strategy.minimum_candles(run.parameters)
    except StrategyConfigurationError as error:
        return _fail_run(run, error.reason)

    candles = list_candles_between(
        run.stock_code,
        run.period,
        run.start_date,
        run.end_date,
    )
    if len(candles) < minimum_candles:
        return _fail_run(run, "not_enough_candles")

    try:
        evaluation = strategy.evaluate(candles, run.parameters)
    except StrategyConfigurationError as error:
        return _fail_run(run, error.reason)

    cash = run.initial_cash
    position_quantity = 0.0
    peak_equity = run.initial_cash
    equity_curve: list[BacktestEquityPoint] = []
    trades: list[BacktestTrade] = []
    signals_by_index = {signal.index: signal.side for signal in evaluation.signals}

    for index, candle in enumerate(candles):
        if index < evaluation.warmup:
            continue

        signal_side = signals_by_index.get(index)
        if signal_side == "buy" and position_quantity <= 0:
            trade = _buy(run, candle.time, candle.close, cash, run.fee_rate, run.slippage_rate)
            if trade is not None:
                trades.append(trade)
                cash = trade.cash_after
                position_quantity = trade.position_after
        elif signal_side == "sell":
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

    final_equity = equity_curve[-1].equity if equity_curve else run.initial_cash
    trade_metrics = _trade_metrics(trades)
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
                "round_trip_count": trade_metrics["round_trip_count"],
                "win_count": trade_metrics["win_count"],
                "loss_count": trade_metrics["loss_count"],
                "win_rate": trade_metrics["win_rate"],
                "candle_count": len(candles),
            },
            "updated_at": datetime.now(timezone.utc),
        },
    )
    return save_backtest_result(completed, equity_curve, trades)


def _trade_metrics(trades: list[BacktestTrade]) -> dict[str, float | int]:
    open_trade: BacktestTrade | None = None
    wins = 0
    losses = 0
    for trade in trades:
        if trade.side == "buy":
            if open_trade is None:
                open_trade = trade
            continue
        if trade.side != "sell" or open_trade is None:
            continue
        buy_cost = open_trade.price * open_trade.quantity + open_trade.fee
        sell_income = trade.price * trade.quantity - trade.fee
        if sell_income > buy_cost:
            wins += 1
        else:
            losses += 1
        open_trade = None

    round_trips = wins + losses
    win_rate = 0 if round_trips == 0 else wins / round_trips
    return {
        "round_trip_count": round_trips,
        "win_count": wins,
        "loss_count": losses,
        "win_rate": win_rate,
    }


def _fail_run(run: BacktestRun, reason: str) -> BacktestResult:
    failed = run.model_copy(
        update={
            "status": "failed",
            "summary": {
                "error": reason,
                "error_message": _failure_message(reason),
            },
            "updated_at": datetime.now(timezone.utc),
        },
    )
    return save_backtest_result(failed, [], [])


def _failure_message(reason: str) -> str:
    return {
        "unsupported_strategy": "暂不支持该策略",
        "invalid_ma_parameters": "均线参数不合法，短均线必须小于长均线",
        "invalid_rsi_parameters": "RSI 参数不合法，周期必须大于 1，且超卖线小于超买线",
        "invalid_macd_parameters": "MACD 参数不合法，快线周期必须小于慢线周期",
        "not_enough_candles": "K 线数据不足，无法完成回测",
    }.get(reason, "回测失败，请检查参数和 K 线数据")


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
    if quantity <= 0.000001:
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
