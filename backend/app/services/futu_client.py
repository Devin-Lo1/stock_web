import math
import os
import socket
from datetime import datetime, time, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from .futu_import import get_futu_sdk
from ..schemas import (
    Candle,
    CapitalFlowBucket,
    CapitalFlowPoint,
    CapitalFlowSnapshot,
    QuoteSnapshot,
)


FUTU_HOST = os.getenv("FUTU_HOST", "127.0.0.1").strip() or "127.0.0.1"
FUTU_PORT = int(os.getenv("FUTU_PORT", "11111").strip() or "11111")
FUTU_CONNECT_TIMEOUT_SECONDS = float(
    os.getenv("FUTU_CONNECT_TIMEOUT_SECONDS", "2").strip() or "2"
)
US_EASTERN = ZoneInfo("America/New_York")


class FutuDependencyError(RuntimeError):
    pass


class FutuOpenDError(RuntimeError):
    pass


def check_futu_health() -> dict[str, Any]:
    sdk = get_futu_sdk()
    if sdk is None:
        raise FutuDependencyError("futu-api is not installed")

    _ensure_futu_port_available()
    quote_context = sdk.OpenQuoteContext(host=FUTU_HOST, port=FUTU_PORT)
    try:
        ret, data = quote_context.get_global_state()
        if ret != sdk.RET_OK:
            raise FutuOpenDError(str(data))
        return {
            "host": FUTU_HOST,
            "port": FUTU_PORT,
            "state": _stringify_data(data),
        }
    finally:
        quote_context.close()


def get_futu_quote(code: str) -> QuoteSnapshot:
    sdk = get_futu_sdk()
    if sdk is None:
        raise FutuDependencyError("futu-api is not installed")

    normalized_code = code.strip().upper()
    _ensure_futu_port_available()
    quote_context = sdk.OpenQuoteContext(host=FUTU_HOST, port=FUTU_PORT)
    try:
        ret, data = quote_context.get_market_snapshot([normalized_code])
        if ret != sdk.RET_OK:
            raise FutuOpenDError(str(data))
        if data.empty:
            raise FutuOpenDError(f"No quote returned for {normalized_code}")

        row = data.iloc[0]
        current_price = _read_float(row, "last_price")
        previous_close = _read_float(row, "prev_close_price")
        change = current_price - previous_close if previous_close else 0
        change_rate = change / previous_close * 100 if previous_close else 0
        extended = _extended_quote_fields(normalized_code, row)

        return QuoteSnapshot(
            code=normalized_code,
            market=_market_from_code(normalized_code),
            currency=_currency_from_code(normalized_code),
            current_price=current_price,
            previous_close=previous_close,
            open=_read_float(row, "open_price"),
            high=_read_float(row, "high_price"),
            low=_read_float(row, "low_price"),
            volume=_read_float(row, "volume"),
            turnover=_read_float(row, "turnover"),
            turnover_rate=_read_float(row, "turnover_rate"),
            pe_ratio=_read_float(row, "pe_ratio") or _read_float(row, "pe_ttm_ratio"),
            lot_size=_read_float(row, "lot_size"),
            change=change,
            change_rate=change_rate,
            quote_time=datetime.now(timezone.utc),
            **extended,
        )
    finally:
        quote_context.close()


def get_history_kline_quota() -> dict[str, Any]:
    sdk = get_futu_sdk()
    if sdk is None:
        raise FutuDependencyError("futu-api is not installed")

    _ensure_futu_port_available()
    quote_context = sdk.OpenQuoteContext(host=FUTU_HOST, port=FUTU_PORT)
    try:
        ret, data = quote_context.get_history_kl_quota(get_detail=True)
        if ret != sdk.RET_OK:
            raise FutuOpenDError(str(data))
        return _normalize_quota(data)
    finally:
        quote_context.close()


def get_futu_capital_flow(code: str) -> CapitalFlowSnapshot:
    sdk = get_futu_sdk()
    if sdk is None:
        raise FutuDependencyError("futu-api is not installed")

    normalized_code = code.strip().upper()
    _ensure_futu_port_available()
    quote_context = sdk.OpenQuoteContext(host=FUTU_HOST, port=FUTU_PORT)
    try:
        ret, distribution = quote_context.get_capital_distribution(normalized_code)
        if ret != sdk.RET_OK:
            raise FutuOpenDError(str(distribution))
        if distribution.empty:
            raise FutuOpenDError(f"No capital distribution returned for {normalized_code}")

        ret, flow = quote_context.get_capital_flow(
            normalized_code,
            period_type=sdk.PeriodType.INTRADAY,
        )
        if ret != sdk.RET_OK:
            raise FutuOpenDError(str(flow))

        row = distribution.iloc[0]
        buckets = [
            _capital_bucket(row, "super"),
            _capital_bucket(row, "big"),
            _capital_bucket(row, "mid"),
            _capital_bucket(row, "small"),
        ]
        total_inflow = sum(bucket.inflow for bucket in buckets)
        total_outflow = sum(bucket.outflow for bucket in buckets)
        points = [
            _row_to_capital_flow_point(flow_row)
            for _, flow_row in flow.iterrows()
        ] if not flow.empty else []

        return CapitalFlowSnapshot(
            code=normalized_code,
            market=_market_from_code(normalized_code),
            currency=_currency_from_code(normalized_code),
            update_time=_read_datetime_optional(row, "update_time"),
            total_inflow=total_inflow,
            total_outflow=total_outflow,
            net_inflow=total_inflow - total_outflow,
            buckets=buckets,
            points=points,
        )
    finally:
        quote_context.close()


def request_history_klines(
    code: str,
    period: str,
    max_count: int,
    start: str | None = None,
    end: str | None = None,
) -> list[Candle]:
    sdk = get_futu_sdk()
    if sdk is None:
        raise FutuDependencyError("futu-api is not installed")

    normalized_code = code.strip().upper()
    normalized_period = _normalize_period(period)
    requested_count = max(1, min(max_count, 1000))
    actual_end = end or datetime.now(timezone.utc).date().isoformat()
    actual_start = start or _default_kline_start(
        normalized_period,
        requested_count,
        actual_end,
    )
    ktype = _futu_ktype(sdk, normalized_period)
    _ensure_futu_port_available()
    quote_context = sdk.OpenQuoteContext(host=FUTU_HOST, port=FUTU_PORT)
    try:
        ret, data, _ = quote_context.request_history_kline(
            normalized_code,
            start=actual_start,
            end=actual_end,
            ktype=ktype,
            autype=sdk.AuType.QFQ,
            max_count=1000,
        )
        if ret != sdk.RET_OK:
            raise FutuOpenDError(str(data))
        if data.empty:
            return []
        candles = [
            _row_to_candle(normalized_code, normalized_period, row)
            for _, row in data.iterrows()
        ]
        return candles[-requested_count:]
    finally:
        quote_context.close()


def _read_float(row: Any, key: str) -> float:
    value = row.get(key, 0)
    try:
        parsed = float(value)
        return parsed if math.isfinite(parsed) else 0.0
    except (TypeError, ValueError):
        return 0.0


def _extended_quote_fields(code: str, row: Any) -> dict[str, Any]:
    if not code.startswith("US."):
        return {}

    session = _active_us_extended_session()
    if not session:
        return {}

    price = _read_float(row, f"{session}_price")
    if price <= 0:
        return {}

    return {
        "extended_session": session,
        "extended_price": price,
        "extended_change": _read_float(row, f"{session}_change_val"),
        "extended_change_rate": _read_float(row, f"{session}_change_rate"),
        "extended_volume": _read_float(row, f"{session}_volume"),
        "extended_turnover": _read_float(row, f"{session}_turnover"),
    }


def _active_us_extended_session(now: datetime | None = None) -> str:
    eastern_now = (now or datetime.now(timezone.utc)).astimezone(US_EASTERN)
    if eastern_now.weekday() >= 5:
        return ""

    current_time = eastern_now.time()
    if time(4, 0) <= current_time < time(9, 30):
        return "pre"
    if time(9, 30) <= current_time < time(16, 0):
        return ""
    if time(16, 0) <= current_time < time(20, 0):
        return "after"
    return "overnight"


def _capital_bucket(row: Any, bucket: str) -> CapitalFlowBucket:
    inflow = _read_float(row, f"capital_in_{bucket}")
    outflow = _read_float(row, f"capital_out_{bucket}")
    return CapitalFlowBucket(
        bucket=bucket,
        inflow=inflow,
        outflow=outflow,
        net_inflow=inflow - outflow,
    )


def _row_to_capital_flow_point(row: Any) -> CapitalFlowPoint:
    return CapitalFlowPoint(
        time=_read_datetime(row, "capital_flow_item_time"),
        net_inflow=_read_float(row, "in_flow"),
        super_net_inflow=_read_float(row, "super_in_flow"),
        big_net_inflow=_read_float(row, "big_in_flow"),
        mid_net_inflow=_read_float(row, "mid_in_flow"),
        small_net_inflow=_read_float(row, "sml_in_flow"),
    )


def _market_from_code(code: str) -> str:
    market = code.split(".", 1)[0].upper() if "." in code else ""
    if market in {"HK", "US", "SH", "SZ"}:
        return market
    raise FutuOpenDError(f"Unsupported market code: {code}")


def _currency_from_code(code: str) -> str:
    market = _market_from_code(code)
    return {
        "HK": "HKD",
        "US": "USD",
        "SH": "CNY",
        "SZ": "CNY",
    }[market]


def _normalize_period(period: str) -> str:
    normalized = period.strip().lower()
    aliases = {
        "k_day": "day",
        "1d": "day",
        "d": "day",
        "daily": "day",
        "k_week": "week",
        "1w": "week",
        "w": "week",
        "weekly": "week",
        "k_mon": "month",
        "1mo": "month",
        "mon": "month",
        "monthly": "month",
        "k_1m": "1m",
        "1": "1m",
        "min": "1m",
        "minute": "1m",
        "intraday": "1m",
        "k_60m": "60m",
        "60": "60m",
        "1h": "60m",
        "hour": "60m",
    }
    return aliases.get(normalized, normalized)


def _default_kline_start(period: str, max_count: int, end: str) -> str:
    end_date = datetime.fromisoformat(end).date()
    bounded_count = max(1, min(max_count, 1000))
    if period == "1m":
        days = max(3, bounded_count // 120 + 2)
    elif period == "60m":
        days = max(10, bounded_count // 4 + 10)
    elif period == "week":
        days = bounded_count * 10
    elif period == "month":
        days = bounded_count * 40
    else:
        days = bounded_count * 2 + 20
    return (end_date - timedelta(days=days)).isoformat()


def _futu_ktype(sdk: Any, period: str) -> str:
    mapping = {
        "day": sdk.KLType.K_DAY,
        "week": sdk.KLType.K_WEEK,
        "month": sdk.KLType.K_MON,
        "1m": sdk.KLType.K_1M,
        "60m": sdk.KLType.K_60M,
    }
    if period not in mapping:
        raise FutuOpenDError(f"Unsupported kline period: {period}")
    return mapping[period]


def _ensure_futu_port_available() -> None:
    try:
        with socket.create_connection(
            (FUTU_HOST, FUTU_PORT),
            timeout=FUTU_CONNECT_TIMEOUT_SECONDS,
        ):
            return
    except OSError as error:
        raise FutuOpenDError(
            f"FutuOpenD is not reachable at {FUTU_HOST}:{FUTU_PORT}",
        ) from error


def _normalize_quota(data: Any) -> dict[str, Any]:
    if isinstance(data, tuple) and len(data) >= 3:
        return {
            "used_quota": data[0],
            "remain_quota": data[1],
            "detail_list": data[2],
        }
    return {"raw": _stringify_data(data)}


def _row_to_candle(code: str, period: str, row: Any) -> Candle:
    return Candle(
        code=code,
        market=_market_from_code(code),
        period=period,
        time=_read_datetime(row, "time_key"),
        open=_read_float(row, "open"),
        high=_read_float(row, "high"),
        low=_read_float(row, "low"),
        close=_read_float(row, "close"),
        volume=_read_float(row, "volume"),
        turnover=_read_float(row, "turnover"),
    )


def _read_datetime(row: Any, key: str) -> datetime:
    value = row.get(key, None)
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc)
    if isinstance(value, str) and value:
        normalized = value.replace(" ", "T")
        parsed = datetime.fromisoformat(normalized)
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    return datetime.now(timezone.utc)


def _read_datetime_optional(row: Any, key: str) -> datetime | None:
    value = row.get(key, None)
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc)
    if isinstance(value, str) and value:
        normalized = value.replace(" ", "T")
        parsed = datetime.fromisoformat(normalized)
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    return None


def _stringify_data(data: Any) -> Any:
    if hasattr(data, "to_dict"):
        return data.to_dict()
    return str(data)
