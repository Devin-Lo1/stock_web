from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

from .futu_import import get_futu_sdk
from .futu_client import FUTU_HOST, FUTU_PORT, FutuDependencyError, FutuOpenDError
from ..schemas import StockSearchResult


_CACHE_TTL = timedelta(hours=12)
_CORE_CACHE: list["_StockSearchItem"] = []
_CORE_CACHE_TIME: datetime | None = None
_DERIVATIVE_CACHE: list["_StockSearchItem"] = []
_DERIVATIVE_CACHE_TIME: datetime | None = None


@dataclass(frozen=True)
class _StockSearchItem:
    code: str
    name: str
    market: str
    stock_type: str
    lot_size: float
    code_digits: str
    search_text: str


def search_stocks(
    query: str,
    limit: int = 20,
    include_derivatives: bool = False,
) -> list[StockSearchResult]:
    normalized_query = query.strip().upper()
    if not normalized_query:
        return []

    items = _get_search_items(include_derivatives=include_derivatives)
    digit_query = _digits_only(normalized_query)
    scored: list[tuple[int, _StockSearchItem]] = []
    for item in items:
        score = _match_score(item, normalized_query, digit_query)
        if score is not None:
            scored.append((score, item))

    scored.sort(key=lambda pair: (pair[0], pair[1].market, pair[1].code))
    return [
        StockSearchResult(
            code=item.code,
            name=item.name,
            market=item.market,
            stock_type=item.stock_type,
            lot_size=item.lot_size,
        )
        for _, item in scored[: max(1, min(limit, 50))]
    ]


def _get_search_items(include_derivatives: bool) -> list[_StockSearchItem]:
    core_items = _get_cached_items(include_derivatives=False)
    if not include_derivatives:
        return core_items
    return [*core_items, *_get_cached_items(include_derivatives=True)]


def _get_cached_items(include_derivatives: bool) -> list[_StockSearchItem]:
    global _CORE_CACHE, _CORE_CACHE_TIME, _DERIVATIVE_CACHE, _DERIVATIVE_CACHE_TIME
    now = datetime.now(timezone.utc)
    if include_derivatives:
        if (
            _DERIVATIVE_CACHE
            and _DERIVATIVE_CACHE_TIME is not None
            and now - _DERIVATIVE_CACHE_TIME < _CACHE_TTL
        ):
            return _DERIVATIVE_CACHE
    elif (
        _CORE_CACHE
        and _CORE_CACHE_TIME is not None
        and now - _CORE_CACHE_TIME < _CACHE_TTL
    ):
        return _CORE_CACHE

    sdk = get_futu_sdk()
    if sdk is None:
        raise FutuDependencyError("futu-api is not installed")

    quote_context = sdk.OpenQuoteContext(host=FUTU_HOST, port=FUTU_PORT)
    try:
        next_items: list[_StockSearchItem] = []
        stock_types = _stock_types(sdk, include_derivatives)
        for market in [sdk.Market.HK, sdk.Market.US, sdk.Market.SH, sdk.Market.SZ]:
            for stock_type in stock_types:
                ret, data = quote_context.get_stock_basicinfo(market, stock_type)
                if ret != sdk.RET_OK:
                    continue
                if data.empty:
                    continue
                for _, row in data.iterrows():
                    item = _row_to_search_item(row)
                    if item is not None:
                        next_items.append(item)
        if include_derivatives:
            _DERIVATIVE_CACHE = next_items
            _DERIVATIVE_CACHE_TIME = now
            return _DERIVATIVE_CACHE
        _CORE_CACHE = next_items
        _CORE_CACHE_TIME = now
        return _CORE_CACHE
    finally:
        quote_context.close()


def _stock_types(sdk: Any, include_derivatives: bool) -> list[Any]:
    if include_derivatives:
        return [sdk.SecurityType.WARRANT, sdk.SecurityType.BWRT]
    return [sdk.SecurityType.STOCK, sdk.SecurityType.ETF]


def _row_to_search_item(row: Any) -> _StockSearchItem | None:
    code = str(row.get("code", "")).strip().upper()
    name = str(row.get("name", "")).strip()
    if not code or not name:
        return None
    if bool(row.get("delisting", False)):
        return None
    market = code.split(".", 1)[0] if "." in code else ""
    stock_type = str(row.get("stock_type", "")).strip() or "STOCK"
    lot_size = _read_float(row, "lot_size")
    return _StockSearchItem(
        code=code,
        name=name,
        market=market,
        stock_type=stock_type,
        lot_size=lot_size,
        code_digits=_digits_only(code),
        search_text=f"{code} {name.upper()} {_digits_only(code)}",
    )


def _match_score(
    item: _StockSearchItem,
    normalized_query: str,
    digit_query: str,
) -> int | None:
    if item.code == normalized_query or (
        digit_query and item.code_digits == digit_query
    ):
        return 0
    symbol = item.code.split(".", 1)[1] if "." in item.code else item.code
    if symbol == normalized_query:
        return 0
    if symbol.startswith(normalized_query):
        return 1
    if item.code.startswith(normalized_query):
        return 1
    if digit_query and item.code_digits.startswith(digit_query):
        return 2
    if item.name.upper().startswith(normalized_query):
        return 3
    if normalized_query in item.search_text:
        return 4
    if digit_query and digit_query in item.code_digits:
        return 5
    return None


def _digits_only(value: str) -> str:
    return "".join(character for character in value if character.isdigit())


def _read_float(row: Any, key: str) -> float:
    value = row.get(key, 0)
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0
