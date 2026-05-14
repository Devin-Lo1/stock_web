from pydantic import BaseModel


class StockSearchResult(BaseModel):
    code: str
    name: str
    market: str
    stock_type: str
    lot_size: float = 0
