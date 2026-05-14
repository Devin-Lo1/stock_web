from fastapi import FastAPI
from fastapi.responses import JSONResponse

from .database import init_database
from .routers import futu, health, klines, positions, quotes, signals, stocks

class UTF8JSONResponse(JSONResponse):
    media_type = "application/json; charset=utf-8"


app = FastAPI(
    title="Stock Web Android MVP API",
    description="Backend API for the Android stock signal MVP.",
    version="0.1.0",
    default_response_class=UTF8JSONResponse,
)


@app.on_event("startup")
def startup() -> None:
    init_database()


app.include_router(health.router)
app.include_router(positions.router)
app.include_router(quotes.router)
app.include_router(klines.router)
app.include_router(signals.router)
app.include_router(stocks.router)
app.include_router(futu.router)
