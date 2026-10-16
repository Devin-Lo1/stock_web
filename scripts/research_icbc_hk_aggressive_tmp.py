from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Any


BASE_SCRIPT = Path(__file__).with_name("research_alibaba_hk_aggressive_tmp.py")
TARGET_CODE = "HK.01398"
BENCHMARK_CODE = "HK.800000"
TARGET_NAME = "工商银行"


def _load_base_module():
    spec = importlib.util.spec_from_file_location(
        "research_alibaba_hk_aggressive_tmp_base",
        BASE_SCRIPT,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load base research script: {BASE_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


base = _load_base_module()
ORIGINAL_SPLIT_ADJUSTMENT_REPORT = base.split_adjustment_report
ORIGINAL_STRATEGY_NAME = base.strategy_name
ORIGINAL_FORMULA = base.formula


def fetch_cloud_candles() -> dict[str, list[dict[str, Any]]]:
    key = Path.home() / ".ssh" / "id_ed25519_gitee_stock_web"
    remote_script = f"""
from datetime import date
from app.repositories.market_data import list_candles_between
import json
def row(c):
    return {{
        'code': c.code,
        'time': c.time.date().isoformat(),
        'open': c.open,
        'high': c.high,
        'low': c.low,
        'close': c.close,
        'volume': c.volume,
        'turnover': c.turnover,
    }}
payload = {{}}
for code in ['{TARGET_CODE}', '{BENCHMARK_CODE}']:
    payload[code] = [row(c) for c in list_candles_between(code, 'day', date(2021,1,4), date(2026,6,5))]
payload['HK.09988'] = payload['{TARGET_CODE}']
print(json.dumps(payload))
"""
    command = [
        "ssh",
        "-i",
        str(key),
        "-o",
        "BatchMode=yes",
        "ubuntu@119.91.47.141",
        "cd /home/ubuntu/stock_web/backend && ./.venv/bin/python -",
    ]
    result = subprocess.run(
        command,
        input=remote_script,
        text=True,
        capture_output=True,
        check=True,
        timeout=60,
    )
    return json.loads(result.stdout)


class MarketData:
    def __init__(self, rows: dict[str, list[dict[str, Any]]]) -> None:
        target = rows[TARGET_CODE]
        benchmark_by_date = {item["time"]: item for item in rows[BENCHMARK_CODE]}
        aligned = [
            (item, benchmark_by_date[item["time"]])
            for item in target
            if item["time"] in benchmark_by_date
        ]
        self.dates = base.np.array(
            [date.fromisoformat(item[0]["time"]) for item in aligned],
            dtype=object,
        )
        self.open = base.np.array([item[0]["open"] for item in aligned], dtype=float)
        self.high = base.np.array([item[0]["high"] for item in aligned], dtype=float)
        self.low = base.np.array([item[0]["low"] for item in aligned], dtype=float)
        self.close = base.np.array([item[0]["close"] for item in aligned], dtype=float)
        self.volume = base.np.array([item[0]["volume"] for item in aligned], dtype=float)
        self.benchmark_open = base.np.array(
            [item[1]["open"] for item in aligned],
            dtype=float,
        )
        self.benchmark_high = base.np.array(
            [item[1]["high"] for item in aligned],
            dtype=float,
        )
        self.benchmark_low = base.np.array(
            [item[1]["low"] for item in aligned],
            dtype=float,
        )
        self.benchmark_close = base.np.array(
            [item[1]["close"] for item in aligned],
            dtype=float,
        )
        if len(self.close) < 1200:
            raise RuntimeError(f"not enough aligned data: {len(self.close)}")

    @classmethod
    def from_rows(cls, rows: dict[str, list[dict[str, Any]]]) -> "MarketData":
        return cls(rows)


def split_adjustment_report(rows: list[dict[str, Any]]) -> dict[str, Any]:
    report = ORIGINAL_SPLIT_ADJUSTMENT_REPORT(rows)
    report["known_event"] = (
        "No known ICBC HK split adjustment was required for the requested "
        "2021-2026 window; the cloud OHLC series is still checked for "
        "split-like discontinuities before backtesting."
    )
    return report


def strategy_name(candidate) -> str:
    return ORIGINAL_STRATEGY_NAME(candidate).replace("阿里巴巴", TARGET_NAME)


def formula(candidate) -> str:
    return ORIGINAL_FORMULA(candidate).replace("阿里巴巴", TARGET_NAME)


def _arg_value(flag: str, default: str) -> str:
    if flag in sys.argv:
        index = sys.argv.index(flag)
        if index + 1 < len(sys.argv):
            return sys.argv[index + 1]
    return default


def _patch_output_metadata(path: str) -> None:
    output_path = Path(path)
    if not output_path.exists():
        return
    data = json.loads(output_path.read_text(encoding="utf-8"))
    data["meta"]["target"] = TARGET_CODE
    data["meta"]["benchmark"] = BENCHMARK_CODE
    data["meta"]["current_app_note"] = (
        f"No existing App personalized strategy template was found for {TARGET_CODE}."
    )
    output_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    base.fetch_cloud_candles = fetch_cloud_candles
    base.MarketData = MarketData
    base.split_adjustment_report = split_adjustment_report
    base.strategy_name = strategy_name
    base.formula = formula
    base.main()
    _patch_output_metadata(
        _arg_value("--output", "scripts/research_icbc_hk_aggressive_tmp_result.json")
    )


if __name__ == "__main__":
    main()
