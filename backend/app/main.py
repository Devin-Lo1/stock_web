from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.responses import JSONResponse

from .db.init import init_database
from .middleware.api_auth import install_api_token_middleware
from .routers import (
    backtests,
    funds,
    futu,
    health,
    klines,
    notifications,
    personalized_strategies,
    positions,
    quotes,
    signals,
)
from .routers import stocks, strategies
from .services.strategy_monitor_scheduler import (
    start_strategy_monitor_scheduler_from_env,
    stop_strategy_monitor_scheduler,
)
from .services.fund_alert_scheduler import (
    start_fund_alert_scheduler,
    stop_fund_alert_scheduler,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_database()
    await start_strategy_monitor_scheduler_from_env()
    await start_fund_alert_scheduler()
    try:
        yield
    finally:
        await stop_fund_alert_scheduler()
        await stop_strategy_monitor_scheduler()


class UTF8JSONResponse(JSONResponse):
    media_type = "application/json; charset=utf-8"


app = FastAPI(
    title="Stock Web Android MVP API",
    description="Backend API for the Android stock signal MVP.",
    version="0.1.0",
    default_response_class=UTF8JSONResponse,
    lifespan=lifespan,
)


install_api_token_middleware(app)
app.include_router(health.router)
app.include_router(positions.router)
app.include_router(quotes.router)
app.include_router(klines.router)
app.include_router(notifications.router)
app.include_router(signals.router)
app.include_router(stocks.router)
app.include_router(futu.router)
app.include_router(strategies.router)
app.include_router(backtests.router)
app.include_router(personalized_strategies.router)
app.include_router(funds.router)
