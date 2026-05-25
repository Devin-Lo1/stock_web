import json
import re
from datetime import date, datetime, timedelta, timezone
from typing import Any, ClassVar

import httpx

from ..db.converters import UTC, _now
from ..schemas import FundBenchmarkPoint, FundNavPoint, FundQuote, FundSearchResult

CN_TZ = timezone(timedelta(hours=8))


class FundProviderError(RuntimeError):
    pass


class EastmoneyFundProvider:
    source = "eastmoney"
    _timeout = 8.0
    _search_cache_ttl = timedelta(minutes=10)
    _nav_cache_ttl = timedelta(minutes=10)
    _benchmark_cache_ttl = timedelta(minutes=10)
    _quote_cache_ttl = timedelta(seconds=30)
    _search_cache: ClassVar[
        dict[tuple[str, int], tuple[datetime, list[FundSearchResult]]]
    ] = {}
    _nav_cache: ClassVar[dict[tuple[str, int], tuple[datetime, list[FundNavPoint]]]] = {}
    _benchmark_cache: ClassVar[
        dict[tuple[str, int], tuple[datetime, list[FundBenchmarkPoint]]]
    ] = {}
    _quote_cache: ClassVar[
        dict[tuple[str, str | None, float], tuple[datetime, FundQuote]]
    ] = {}
    _headers = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json,text/javascript,*/*",
        "Referer": "https://fund.eastmoney.com/",
    }

    def search(self, query: str, *, limit: int = 20) -> list[FundSearchResult]:
        keyword = query.strip()
        if not keyword:
            return []
        cache_key = (keyword.lower(), limit)
        now = _now()
        cached = self._search_cache.get(cache_key)
        if cached is not None and now - cached[0] < self._search_cache_ttl:
            return [item.model_copy() for item in cached[1]]
        payload = self._get_json(
            "https://fundsuggest.eastmoney.com/FundSearch/api/FundSearchAPI.ashx",
            params={"m": "1", "key": keyword},
        )
        items = payload.get("Datas") if isinstance(payload, dict) else []
        if not isinstance(items, list):
            return []
        results: list[FundSearchResult] = []
        for item in items[:limit]:
            if not isinstance(item, dict):
                continue
            base = item.get("FundBaseInfo")
            if not isinstance(base, dict):
                base = {}
            code = str(item.get("CODE") or base.get("FCODE") or "").strip()
            name = str(item.get("NAME") or base.get("SHORTNAME") or "").strip()
            if not code or not name:
                continue
            results.append(
                FundSearchResult(
                    code=code,
                    name=name,
                    fund_type=str(base.get("FTYPE") or item.get("CATEGORYDESC") or ""),
                    company=str(base.get("JJGS") or ""),
                    manager=str(base.get("JJJL") or ""),
                    source=self.source,
                ),
            )
        self._search_cache[cache_key] = (now, [item.model_copy() for item in results])
        return results

    def quote(
        self,
        fund_code: str,
        *,
        latest: FundNavPoint | None = None,
    ) -> FundQuote:
        code = fund_code.strip()
        if latest is None:
            navs = self.nav_history(code, limit=1)
            latest = navs[0] if navs else None
        now = _now()
        cache_key = (
            code,
            latest.nav_date.isoformat() if latest else None,
            latest.unit_nav if latest else 0,
        )
        cached = self._quote_cache.get(cache_key)
        if cached is not None and now - cached[0] < self._quote_cache_ttl:
            return cached[1].model_copy()
        estimated_nav = 0.0
        estimated_change_rate = 0.0
        estimate_time: datetime | None = None
        name = ""
        try:
            payload = self._get_jsonp(
                f"https://fundgz.1234567.com.cn/js/{code}.js",
                params={"rt": str(int(datetime.now().timestamp() * 1000))},
            )
            name = str(payload.get("name") or "")
            estimated_nav = _float(payload.get("gsz"))
            estimated_change_rate = _float(payload.get("gszzl"))
            estimate_time = _parse_datetime(payload.get("gztime"))
        except FundProviderError:
            pass
        if not name:
            results = self.search(code, limit=1)
            name = results[0].name if results else code
        quote = FundQuote(
            fund_code=code,
            name=name,
            nav_date=latest.nav_date if latest else None,
            unit_nav=latest.unit_nav if latest else 0,
            accumulated_nav=latest.accumulated_nav if latest else 0,
            daily_growth_rate=latest.daily_growth_rate if latest else 0,
            estimated_nav=estimated_nav,
            estimated_change_rate=estimated_change_rate,
            estimate_time=estimate_time,
            source=self.source,
        )
        self._quote_cache[cache_key] = (now, quote.model_copy())
        return quote

    def nav_history(self, fund_code: str, *, limit: int = 90) -> list[FundNavPoint]:
        code = fund_code.strip()
        cache_key = (code, limit)
        now = _now()
        cached = self._nav_cache.get(cache_key)
        if cached is not None and now - cached[0] < self._nav_cache_ttl:
            return [item.model_copy() for item in cached[1]]
        payload = self._get_json(
            "https://api.fund.eastmoney.com/f10/lsjz",
            params={
                "fundCode": code,
                "pageIndex": "1",
                "pageSize": str(limit),
                "startDate": "",
                "endDate": "",
            },
            headers={"Referer": "https://fundf10.eastmoney.com/"},
        )
        data = payload.get("Data") if isinstance(payload, dict) else None
        rows = data.get("LSJZList") if isinstance(data, dict) else None
        if not isinstance(rows, list):
            raise FundProviderError("fund nav response is empty")
        now = _now()
        points: list[FundNavPoint] = []
        for row in rows:
            if not isinstance(row, dict):
                continue
            nav_date = _parse_date(row.get("FSRQ"))
            if nav_date is None:
                continue
            points.append(
                FundNavPoint(
                    fund_code=code,
                    nav_date=nav_date,
                    unit_nav=_float(row.get("DWJZ")),
                    accumulated_nav=_float(row.get("LJJZ")),
                    daily_growth_rate=_float(row.get("JZZZL")),
                    subscribe_status=str(row.get("SGZT") or ""),
                    redeem_status=str(row.get("SHZT") or ""),
                    source=self.source,
                    updated_at=now,
                ),
            )
        self._nav_cache[cache_key] = (now, [item.model_copy() for item in points])
        return points

    def benchmark_history(
        self,
        benchmark_code: str = "hs300",
        *,
        limit: int = 370,
    ) -> list[FundBenchmarkPoint]:
        normalized = benchmark_code.strip().lower()
        if normalized not in {"hs300", "000300", "sh.000300"}:
            raise FundProviderError(f"unsupported fund benchmark: {benchmark_code}")
        bounded_limit = max(1, min(limit, 1000))
        cache_key = ("hs300", bounded_limit)
        now = _now()
        cached = self._benchmark_cache.get(cache_key)
        if cached is not None and now - cached[0] < self._benchmark_cache_ttl:
            return [item.model_copy() for item in cached[1]]

        today = datetime.now(CN_TZ).date()
        begin = today - timedelta(days=max(45, bounded_limit * 2 + 14))
        try:
            result = self._eastmoney_hs300_history(bounded_limit, begin)
        except Exception as error:
            try:
                result = self._futu_hs300_history(bounded_limit, begin, today)
            except Exception as fallback_error:
                raise FundProviderError(str(error)) from fallback_error

        self._benchmark_cache[cache_key] = (
            now,
            [item.model_copy() for item in result],
        )
        return result

    def _eastmoney_hs300_history(
        self,
        limit: int,
        begin: date,
    ) -> list[FundBenchmarkPoint]:
        payload = self._get_json(
            "https://push2his.eastmoney.com/api/qt/stock/kline/get",
            params={
                "secid": "1.000300",
                "fields1": "f1,f2,f3,f4,f5,f6",
                "fields2": "f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61",
                "klt": "101",
                "fqt": "1",
                "beg": begin.strftime("%Y%m%d"),
                "end": "20500101",
            },
            headers={"Referer": "https://quote.eastmoney.com/"},
        )
        data = payload.get("data") if isinstance(payload, dict) else None
        rows = data.get("klines") if isinstance(data, dict) else None
        if not isinstance(rows, list):
            raise FundProviderError("benchmark history response is empty")

        points: list[FundBenchmarkPoint] = []
        previous_close = 0.0
        for row in rows:
            parts = str(row).split(",")
            if len(parts) < 3:
                continue
            trade_date = _parse_date(parts[0])
            if trade_date is None:
                continue
            close = _float(parts[2])
            change_rate = _float(parts[8]) if len(parts) > 8 else 0
            if change_rate == 0 and previous_close > 0:
                change_rate = (close - previous_close) / previous_close * 100
            previous_close = close
            points.append(
                FundBenchmarkPoint(
                    code="000300",
                    name="沪深300",
                    trade_date=trade_date,
                    close=close,
                    daily_growth_rate=change_rate,
                    source=self.source,
                )
            )
        if not points:
            raise FundProviderError("benchmark history response is empty")
        return points[-limit:]

    def _futu_hs300_history(
        self,
        limit: int,
        begin: date,
        end: date,
    ) -> list[FundBenchmarkPoint]:
        from .futu_client import request_history_klines

        candles = request_history_klines(
            code="SH.000300",
            period="day",
            max_count=limit,
            start=begin.isoformat(),
            end=end.isoformat(),
        )
        points: list[FundBenchmarkPoint] = []
        previous_close = 0.0
        for candle in candles:
            close = candle.close
            change_rate = (
                (close - previous_close) / previous_close * 100
                if previous_close > 0
                else 0.0
            )
            previous_close = close
            points.append(
                FundBenchmarkPoint(
                    code="000300",
                    name="沪深300",
                    trade_date=candle.time.date(),
                    close=close,
                    daily_growth_rate=change_rate,
                    source="futu",
                )
            )
        if not points:
            raise FundProviderError("benchmark history fallback response is empty")
        return points[-limit:]

    def _get_json(
        self,
        url: str,
        *,
        params: dict[str, str],
        headers: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        response = httpx.get(
            url,
            params=params,
            headers={**self._headers, **(headers or {})},
            timeout=self._timeout,
            trust_env=False,
        )
        response.raise_for_status()
        return json.loads(response.content.decode("utf-8", errors="replace"))

    def _get_jsonp(self, url: str, *, params: dict[str, str]) -> dict[str, Any]:
        response = httpx.get(
            url,
            params=params,
            headers=self._headers,
            timeout=self._timeout,
            trust_env=False,
        )
        response.raise_for_status()
        text = response.content.decode("utf-8", errors="replace")
        match = re.search(r"\((\{.*\})\)", text)
        if match is None:
            raise FundProviderError("fund quote response is not jsonp")
        return json.loads(match.group(1))


def _parse_date(value: object) -> date | None:
    if not isinstance(value, str) or not value:
        return None
    return date.fromisoformat(value[:10])


def _parse_datetime(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace(" ", "T"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=CN_TZ).astimezone(UTC)
    return parsed.astimezone(UTC)


def _float(value: object) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value.replace("%", "").replace(",", ""))
        except ValueError:
            return 0.0
    return 0.0
