import json
import re
from datetime import date, datetime, timedelta, timezone
from typing import Any

import httpx

from ..db.converters import UTC, _now
from ..schemas import FundNavPoint, FundQuote, FundSearchResult

CN_TZ = timezone(timedelta(hours=8))


class FundProviderError(RuntimeError):
    pass


class EastmoneyFundProvider:
    source = "eastmoney"
    _timeout = 8.0
    _headers = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json,text/javascript,*/*",
        "Referer": "https://fund.eastmoney.com/",
    }

    def search(self, query: str, *, limit: int = 20) -> list[FundSearchResult]:
        keyword = query.strip()
        if not keyword:
            return []
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
        return FundQuote(
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

    def nav_history(self, fund_code: str, *, limit: int = 90) -> list[FundNavPoint]:
        code = fund_code.strip()
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
        return points

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
        )
        response.raise_for_status()
        return json.loads(response.content.decode("utf-8", errors="replace"))

    def _get_jsonp(self, url: str, *, params: dict[str, str]) -> dict[str, Any]:
        response = httpx.get(
            url,
            params=params,
            headers=self._headers,
            timeout=self._timeout,
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
