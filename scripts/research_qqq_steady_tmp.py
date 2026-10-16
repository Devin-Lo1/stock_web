from __future__ import annotations

import argparse
import json
import math
import os
import random
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Any

import numpy as np


INITIAL_CASH = 100_000.0
SLIPPAGE = 0.0005
US_COMMISSION_RATE = 0.00138
US_MIN_COMMISSION = 18.0
US_SEC_FEE_RATE = 20.60 / 1_000_000
US_TAF_RATE_PER_SHARE = 0.000195
US_TAF_MAX = 9.79

START = date(2021, 1, 4)
END = date(2026, 6, 3)
TRAIN_END = date(2025, 12, 31)
YEARS = {
    "2022": (date(2022, 1, 1), date(2022, 12, 31)),
    "2023": (date(2023, 1, 1), date(2023, 12, 31)),
    "2024": (date(2024, 1, 1), date(2024, 12, 31)),
    "2025": (date(2025, 1, 1), date(2025, 12, 31)),
    "2026YTD": (date(2026, 1, 1), END),
}


@dataclass(frozen=True)
class Candidate:
    family: str
    direction: str
    params: tuple[tuple[str, Any], ...]
    name: str = ""

    def get(self, key: str, default: Any = None) -> Any:
        return dict(self.params).get(key, default)

    def as_dict(self) -> dict[str, Any]:
        return {"family": self.family, "direction": self.direction, **dict(self.params)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage1", type=int, default=800_000)
    parser.add_argument("--seed", type=int, default=20260606)
    parser.add_argument("--batch-size", type=int, default=1024)
    parser.add_argument("--output", default="scripts/research_qqq_steady_tmp_result.json")
    parser.add_argument("--progress", default="scripts/research_qqq_steady_tmp_progress.json")
    args = parser.parse_args()

    started = time.time()
    rng = random.Random(args.seed)
    write_progress(args.progress, "fetching_data", 0, args.stage1, started)
    rows = fetch_cloud_candles()
    data = MarketData.from_rows(rows)
    indicators = Indicators(data)
    ranges = DateRanges(data.dates)

    current_app = current_app_candidate()
    current_metrics = evaluate_candidates(
        [current_app],
        data,
        indicators,
        ranges.all_start,
        ranges.all_end,
    )[0]
    current_years = annual_metrics([current_app], data, indicators, ranges)[0]

    seen: set[tuple[Any, ...]] = {candidate_key(current_app)}
    prelim: list[dict[str, Any]] = []
    top_by_family: dict[str, list[dict[str, Any]]] = {}
    tested = 1

    write_progress(args.progress, "stage1_search", tested, args.stage1, started)
    while tested < args.stage1:
        batch: list[Candidate] = []
        while len(batch) < args.batch_size and tested < args.stage1:
            candidate = random_candidate(rng)
            key = candidate_key(candidate)
            if key in seen:
                continue
            seen.add(key)
            batch.append(candidate)
            tested += 1

        metrics = evaluate_candidates(
            batch,
            data,
            indicators,
            ranges.train_start,
            ranges.train_end,
        )
        for candidate, metric in zip(batch, metrics):
            if preliminary_pass(metric):
                record = {"candidate": candidate, "train_full": metric}
                prelim.append(record)
                family_records = top_by_family.setdefault(candidate.family, [])
                family_records.append(record)
                family_records.sort(key=lambda item: steady_sort_key(item["train_full"]))
                del family_records[20:]

        if tested % 25_000 < args.batch_size:
            write_progress(args.progress, "stage1_search", tested, args.stage1, started)

    local_candidates = local_refine_candidates(top_by_family, rng, seen)
    local_metrics = evaluate_candidates(
        local_candidates,
        data,
        indicators,
        ranges.train_start,
        ranges.train_end,
    )
    for candidate, metric in zip(local_candidates, local_metrics):
        tested += 1
        if preliminary_pass(metric):
            prelim.append({"candidate": candidate, "train_full": metric})

    write_progress(args.progress, "annual_review", tested, tested, started)
    reviewed = annual_review(prelim, data, indicators, ranges)
    train_pass = [item for item in reviewed if item["train_pass"]]

    write_progress(args.progress, "walk_forward", tested, tested, started)
    wf_counts = {"2024": 0, "2025": 0, "2026YTD": 0, "all": 0}
    final_records: list[dict[str, Any]] = []
    relaxed_records: list[dict[str, Any]] = []
    for item in train_pass:
        wf = walk_forward(item["candidate"], data, indicators, ranges)
        item["walk_forward"] = wf
        wf_counts["2024"] += int(wf["2024"]["pass"])
        wf_counts["2025"] += int(wf["2025"]["pass"])
        wf_counts["2026YTD"] += int(wf["2026YTD"]["pass"])
        wf_counts["all"] += int(wf["all_pass"])
        full = evaluate_candidates(
            [item["candidate"]],
            data,
            indicators,
            ranges.all_start,
            ranges.all_end,
        )[0]
        years = annual_metrics([item["candidate"]], data, indicators, ranges)[0]
        item["full"] = full
        item["years"] = years
        strict = final_pass(item, max_drawdown_limit=0.15)
        relaxed = final_pass(item, max_drawdown_limit=0.18)
        if strict:
            final_records.append(item)
        if relaxed:
            relaxed_records.append(item)

    selected_pool = final_records if final_records else relaxed_records
    relaxed_used = not final_records
    top3 = select_top3(selected_pool)
    closest = select_top3(reviewed if reviewed else prelim, require_pass=False)

    output = {
        "meta": {
            "target": "US.QQQ",
            "benchmark": "US.QQQ",
            "auxiliary_benchmark": "US.SPY",
            "range": f"{START.isoformat()}~{END.isoformat()}",
            "seed": args.seed,
            "started_at": datetime.now().isoformat(timespec="seconds"),
            "elapsed_seconds": round(time.time() - started, 2),
            "cost_model": {
                "initial_cash": INITIAL_CASH,
                "slippage_single_side": SLIPPAGE,
                "commission_rate": US_COMMISSION_RATE,
                "min_commission": US_MIN_COMMISSION,
                "sec_fee_rate": US_SEC_FEE_RATE,
                "taf_rate_per_share": US_TAF_RATE_PER_SHARE,
                "taf_max": US_TAF_MAX,
            },
            "no_future_function": True,
            "execution": "Signal at T close, execution at T+1 open; final close forced at interval end.",
        },
        "counts": {
            "unique_tested": tested,
            "stage1_unique": args.stage1,
            "local_refine_unique": len(local_candidates),
            "annual_review": len(reviewed),
            "train_pass_2021_2025": len(train_pass),
            "walk_forward_2024_pass": wf_counts["2024"],
            "walk_forward_2025_pass": wf_counts["2025"],
            "walk_forward_2026YTD_pass": wf_counts["2026YTD"],
            "walk_forward_all_pass": wf_counts["all"],
            "final_pass_dd15": len(final_records),
            "final_pass_dd18": len(relaxed_records),
            "relaxed_used": relaxed_used,
        },
        "current_app": serialize_record(
            {
                "candidate": current_app,
                "full": current_metrics,
                "years": current_years,
                "walk_forward": walk_forward(current_app, data, indicators, ranges),
            }
        ),
        "top3": [serialize_record(item) for item in top3],
        "closest": [serialize_record(item) for item in closest],
    }
    Path(args.output).write_text(
        json.dumps(output, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    write_progress(args.progress, "done", tested, tested, started)
    print(json.dumps(output["counts"], ensure_ascii=False, indent=2))


def write_progress(path: str, stage: str, done: int, total: int, started: float) -> None:
    Path(path).write_text(
        json.dumps(
            {
                "stage": stage,
                "done": done,
                "total": total,
                "elapsed_seconds": round(time.time() - started, 2),
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )


def fetch_cloud_candles() -> dict[str, list[dict[str, Any]]]:
    key = Path.home() / ".ssh" / "id_ed25519_gitee_stock_web"
    remote_script = """
from datetime import date
from app.repositories.market_data import list_candles_between
import json
def row(c):
    return {
        'code': c.code,
        'time': c.time.date().isoformat(),
        'open': c.open,
        'high': c.high,
        'low': c.low,
        'close': c.close,
        'volume': c.volume,
        'turnover': c.turnover,
    }
payload = {}
for code in ['US.QQQ', 'US.SPY']:
    payload[code] = [row(c) for c in list_candles_between(code, 'day', date(2021,1,4), date(2026,6,3))]
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
        qqq = rows["US.QQQ"]
        spy_by_date = {item["time"]: item for item in rows["US.SPY"]}
        aligned = [(item, spy_by_date[item["time"]]) for item in qqq if item["time"] in spy_by_date]
        self.dates = np.array([date.fromisoformat(item[0]["time"]) for item in aligned], dtype=object)
        self.open = np.array([item[0]["open"] for item in aligned], dtype=float)
        self.high = np.array([item[0]["high"] for item in aligned], dtype=float)
        self.low = np.array([item[0]["low"] for item in aligned], dtype=float)
        self.close = np.array([item[0]["close"] for item in aligned], dtype=float)
        self.volume = np.array([item[0]["volume"] for item in aligned], dtype=float)
        self.spy_open = np.array([item[1]["open"] for item in aligned], dtype=float)
        self.spy_high = np.array([item[1]["high"] for item in aligned], dtype=float)
        self.spy_low = np.array([item[1]["low"] for item in aligned], dtype=float)
        self.spy_close = np.array([item[1]["close"] for item in aligned], dtype=float)
        if len(self.close) < 1200:
            raise RuntimeError(f"not enough aligned data: {len(self.close)}")

    @classmethod
    def from_rows(cls, rows: dict[str, list[dict[str, Any]]]) -> "MarketData":
        return cls(rows)


class DateRanges:
    def __init__(self, dates: np.ndarray) -> None:
        self.all_start = 0
        self.all_end = find_end(dates, END)
        self.train_start = 0
        self.train_end = find_end(dates, TRAIN_END)
        self.periods = {
            label: (find_start(dates, start), find_end(dates, end))
            for label, (start, end) in YEARS.items()
        }
        self.wf_train_2023 = (0, find_end(dates, date(2023, 12, 31)))
        self.wf_train_2024 = (0, find_end(dates, date(2024, 12, 31)))
        self.wf_train_2025 = (0, find_end(dates, date(2025, 12, 31)))


def find_start(dates: np.ndarray, value: date) -> int:
    for idx, item in enumerate(dates):
        if item >= value:
            return idx
    return len(dates) - 1


def find_end(dates: np.ndarray, value: date) -> int:
    result = 0
    for idx, item in enumerate(dates):
        if item <= value:
            result = idx
    return result


class Indicators:
    def __init__(self, data: MarketData) -> None:
        self.data = data
        windows = sorted(set(range(5, 201)) | {10, 14, 20, 30, 40, 50, 60, 80, 100, 120, 150, 200})
        self.sma = {w: rolling_mean(data.close, w) for w in windows}
        self.ema = {w: ema(data.close, w) for w in windows}
        self.spy_sma = {w: rolling_mean(data.spy_close, w) for w in windows}
        self.spy_ema = {w: ema(data.spy_close, w) for w in windows}
        self.roc = {w: roc(data.close, w) for w in [20, 40, 60, 80, 120]}
        self.spy_roc = {w: roc(data.spy_close, w) for w in [20, 40, 60, 80, 120]}
        self.slope = {w: rolling_slope(data.close, w) for w in [20, 40, 60, 80]}
        self.spy_slope = {w: rolling_slope(data.spy_close, w) for w in [20, 40, 60, 80]}
        self.sma_slope = {w: rolling_slope(self.sma[w], w) for w in [20, 40, 60, 80]}
        self.prior_high = {w: prior_extreme(data.high, w, "max") for w in range(5, 101)}
        self.prior_low = {w: prior_extreme(data.low, w, "min") for w in range(5, 101)}
        self.atr = {w: rolling_mean(true_range(data.high, data.low, data.close), w) for w in [10, 14, 20, 30, 50]}
        self.atr_pct = {w: self.atr[w] / data.close for w in [10, 14, 20, 30, 50]}
        returns = np.full_like(data.close, np.nan, dtype=float)
        returns[1:] = data.close[1:] / data.close[:-1] - 1
        self.realized_vol = {w: rolling_std(returns, w) * math.sqrt(252) for w in [20, 40, 60]}
        self.volume_ma = {w: rolling_mean(data.volume, w) for w in [20, 40, 60]}
        self.adx = {w: adx(data.high, data.low, data.close, w) for w in [14, 20, 30]}
        self.plus_di = {w: di_values(data.high, data.low, data.close, w)[0] for w in [14, 20, 30]}
        self.minus_di = {w: di_values(data.high, data.low, data.close, w)[1] for w in [14, 20, 30]}


def rolling_mean(values: np.ndarray, window: int) -> np.ndarray:
    out = np.full(len(values), np.nan)
    if window <= 0 or len(values) < window:
        return out
    cumsum = np.cumsum(np.insert(values, 0, 0.0))
    out[window - 1 :] = (cumsum[window:] - cumsum[:-window]) / window
    return out


def rolling_std(values: np.ndarray, window: int) -> np.ndarray:
    out = np.full(len(values), np.nan)
    for idx in range(window - 1, len(values)):
        sample = values[idx - window + 1 : idx + 1]
        if not np.isnan(sample).any():
            out[idx] = np.std(sample)
    return out


def ema(values: np.ndarray, window: int) -> np.ndarray:
    out = np.full(len(values), np.nan)
    if len(values) < window:
        return out
    alpha = 2 / (window + 1)
    value = np.mean(values[:window])
    out[window - 1] = value
    for idx in range(window, len(values)):
        value = alpha * values[idx] + (1 - alpha) * value
        out[idx] = value
    return out


def roc(values: np.ndarray, window: int) -> np.ndarray:
    out = np.full(len(values), np.nan)
    out[window:] = values[window:] / values[:-window] - 1
    return out


def prior_extreme(values: np.ndarray, window: int, mode: str) -> np.ndarray:
    out = np.full(len(values), np.nan)
    fn = np.max if mode == "max" else np.min
    for idx in range(window, len(values)):
        out[idx] = fn(values[idx - window : idx])
    return out


def rolling_slope(values: np.ndarray, window: int) -> np.ndarray:
    out = np.full(len(values), np.nan)
    x = np.arange(window, dtype=float)
    x -= x.mean()
    denominator = np.sum(x * x)
    for idx in range(window - 1, len(values)):
        sample = values[idx - window + 1 : idx + 1]
        if np.isnan(sample).any() or sample[-1] == 0:
            continue
        y = sample - np.mean(sample)
        out[idx] = np.sum(x * y) / denominator / sample[-1]
    return out


def true_range(high: np.ndarray, low: np.ndarray, close: np.ndarray) -> np.ndarray:
    out = high - low
    previous = np.r_[close[0], close[:-1]]
    return np.maximum(out, np.maximum(np.abs(high - previous), np.abs(low - previous)))


def di_values(high: np.ndarray, low: np.ndarray, close: np.ndarray, window: int) -> tuple[np.ndarray, np.ndarray]:
    plus_dm = np.zeros(len(close))
    minus_dm = np.zeros(len(close))
    for idx in range(1, len(close)):
        up = high[idx] - high[idx - 1]
        down = low[idx - 1] - low[idx]
        plus_dm[idx] = up if up > down and up > 0 else 0
        minus_dm[idx] = down if down > up and down > 0 else 0
    tr_sum = rolling_mean(true_range(high, low, close), window) * window
    plus = rolling_mean(plus_dm, window) * window
    minus = rolling_mean(minus_dm, window) * window
    plus_di = np.where(tr_sum > 0, 100 * plus / tr_sum, np.nan)
    minus_di = np.where(tr_sum > 0, 100 * minus / tr_sum, np.nan)
    return plus_di, minus_di


def adx(high: np.ndarray, low: np.ndarray, close: np.ndarray, window: int) -> np.ndarray:
    plus_di, minus_di = di_values(high, low, close, window)
    denom = plus_di + minus_di
    dx = np.where(denom > 0, 100 * np.abs(plus_di - minus_di) / denom, np.nan)
    return rolling_mean(dx, window)


def current_app_candidate() -> Candidate:
    return Candidate(
        family="ma_cross",
        direction="long_short",
        name="current_app_qqq_sma7_111_steady",
        params=tuple(sorted({
            "short_window": 7,
            "long_window": 111,
            "qqq_ma": 120,
            "qqq_ma_kind": "sma",
            "own_roc_days": 20,
            "own_roc_min": 0.02,
            "exit_ma": 150,
            "exit_ma_kind": "sma",
            "fixed_stop": 0.10,
            "trailing_stop": 0.10,
            "take_profit": 0.14,
            "reverse_exit": True,
        }.items())),
    )


def random_candidate(rng: random.Random) -> Candidate:
    if rng.random() < 0.28:
        return random_qqq_steady_region_candidate(rng)
    family = rng.choices(
        ["ma_cross", "channel", "price_ma", "momentum"],
        weights=[0.42, 0.28, 0.18, 0.12],
        k=1,
    )[0]
    direction = rng.choices(["long_short", "long_only", "short_only"], weights=[0.72, 0.22, 0.06], k=1)[0]
    params: dict[str, Any] = {}
    if family == "ma_cross":
        short = rng.randint(5, 50)
        long = rng.randint(max(20, short + 5), 200)
        params.update(short_window=short, long_window=long)
    elif family == "channel":
        params.update(entry_channel=rng.randint(5, 100), exit_channel=rng.randint(5, 100))
    elif family == "price_ma":
        params.update(entry_ma=rng.choice([10, 20, 30, 50, 80, 100, 120, 150, 200]), entry_ma_kind=rng.choice(["sma", "ema"]))
    else:
        params.update(
            momentum_days=rng.choice([20, 40, 60, 80, 120]),
            momentum_long_min=rng.choice([-0.10, -0.06, -0.03, 0.0, 0.03, 0.06, 0.10, 0.15]),
            momentum_short_min=rng.choice([-0.04, 0.0, 0.03, 0.06, 0.10, 0.15]),
        )

    if rng.random() < 0.65:
        params["qqq_ma"] = rng.choice([50, 80, 100, 120, 150, 200])
        params["qqq_ma_kind"] = rng.choice(["sma", "ema"])
    if rng.random() < 0.55:
        params["own_roc_days"] = rng.choice([20, 40, 60, 80, 120])
        params["own_roc_min"] = rng.choice([-0.10, -0.06, -0.03, 0.0, 0.02, 0.04, 0.06, 0.10, 0.15])
    if rng.random() < 0.34:
        params["qqq_slope_days"] = rng.choice([20, 40, 60, 80])
        params["qqq_slope_min"] = rng.choice([0.0000, 0.0003, 0.0005, 0.0010, 0.0015, 0.0020])
    if rng.random() < 0.20:
        params["sma_slope_days"] = rng.choice([20, 40, 60, 80])
        params["sma_slope_min"] = rng.choice([0.0000, 0.0003, 0.0005, 0.0010])
    if rng.random() < 0.22:
        params["adx_days"] = rng.choice([14, 20, 30])
        params["adx_min"] = rng.choice([15, 20, 25, 30, 35])
        params["di_confirm"] = rng.choice([False, True])
    if rng.random() < 0.38:
        params["spy_ma"] = rng.choice([50, 80, 100, 120, 150, 200])
        params["spy_ma_kind"] = rng.choice(["sma", "ema"])
    if rng.random() < 0.32:
        params["spy_roc_days"] = rng.choice([20, 40, 60, 80, 120])
        params["spy_roc_min"] = rng.choice([-0.08, -0.04, 0.0, 0.02, 0.04, 0.06])
    if rng.random() < 0.22:
        params["spy_slope_days"] = rng.choice([20, 40, 60, 80])
        params["spy_slope_min"] = rng.choice([0.0, 0.0003, 0.0005, 0.001])
    if rng.random() < 0.30:
        params["relative_days"] = rng.choice([20, 40, 60, 80, 120])
        params["relative_min"] = rng.choice([-0.10, -0.06, -0.03, 0.0, 0.03, 0.06, 0.10])
    if rng.random() < 0.20:
        params["atr_days"] = rng.choice([10, 14, 20, 30, 50])
        params["atr_pct_max"] = rng.choice([0.018, 0.022, 0.026, 0.030, 0.035, 0.045, 0.060])
        if rng.random() < 0.35:
            params["atr_pct_min"] = rng.choice([0.004, 0.006, 0.008, 0.010])
    if rng.random() < 0.14:
        params["realized_vol_days"] = rng.choice([20, 40, 60])
        params["realized_vol_max"] = rng.choice([0.18, 0.22, 0.26, 0.30, 0.36, 0.45])
    if rng.random() < 0.18:
        params["volume_window"] = rng.choice([20, 40, 60])
        params["volume_ratio_min"] = rng.choice([0.8, 1.0, 1.1, 1.2, 1.5])

    if rng.random() < 0.45:
        params["exit_ma"] = rng.choice([20, 30, 40, 50, 80, 100, 120, 150, 200])
        params["exit_ma_kind"] = rng.choice(["sma", "ema"])
    if family != "channel" and rng.random() < 0.22:
        params["exit_channel"] = rng.randint(5, 100)
    params["reverse_exit"] = rng.random() < 0.72
    if rng.random() < 0.55:
        params["fixed_stop"] = rng.choice([0.04, 0.05, 0.06, 0.08, 0.10, 0.12, 0.15, 0.18])
    if rng.random() < 0.52:
        params["trailing_stop"] = rng.choice([0.04, 0.05, 0.06, 0.08, 0.10, 0.12, 0.15, 0.18])
    if rng.random() < 0.50:
        params["take_profit"] = rng.choice([0.06, 0.08, 0.10, 0.12, 0.15, 0.18, 0.20, 0.24, 0.30])
    if rng.random() < 0.24:
        params.setdefault("atr_days", rng.choice([10, 14, 20, 30, 50]))
        params["atr_stop_mult"] = rng.choice([1.5, 2.0, 2.5, 3.0, 3.5, 4.0])
    if rng.random() < 0.18:
        params.setdefault("atr_days", rng.choice([10, 14, 20, 30, 50]))
        params["atr_trail_mult"] = rng.choice([1.5, 2.0, 2.5, 3.0, 3.5, 4.0])
    if rng.random() < 0.38:
        params["max_hold"] = rng.randint(5, 80)
    return Candidate(family=family, direction=direction, params=tuple(sorted(params.items())))


def random_qqq_steady_region_candidate(rng: random.Random) -> Candidate:
    params: dict[str, Any] = {
        "short_window": rng.randint(5, 16),
        "long_window": rng.randint(88, 135),
        "qqq_ma": rng.choice([80, 100, 120, 150, 200]),
        "qqq_ma_kind": rng.choice(["sma", "ema"]),
        "own_roc_days": rng.choice([20, 40, 60, 80]),
        "own_roc_min": rng.choice([-0.04, -0.02, 0.0, 0.02, 0.04, 0.06]),
        "reverse_exit": rng.choice([True, True, True, False]),
    }
    if rng.random() < 0.75:
        params["exit_ma"] = rng.choice([80, 100, 120, 150, 200])
        params["exit_ma_kind"] = rng.choice(["sma", "ema"])
    if rng.random() < 0.75:
        params["fixed_stop"] = rng.choice([0.06, 0.08, 0.10, 0.12, 0.15])
    if rng.random() < 0.75:
        params["trailing_stop"] = rng.choice([0.06, 0.08, 0.10, 0.12, 0.15])
    if rng.random() < 0.75:
        params["take_profit"] = rng.choice([0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20])
    if rng.random() < 0.25:
        params["spy_ma"] = rng.choice([100, 120, 150, 200])
        params["spy_ma_kind"] = rng.choice(["sma", "ema"])
    if rng.random() < 0.20:
        params["spy_roc_days"] = rng.choice([20, 40, 60, 80])
        params["spy_roc_min"] = rng.choice([-0.04, 0.0, 0.02, 0.04])
    if rng.random() < 0.20:
        params["relative_days"] = rng.choice([20, 40, 60, 80])
        params["relative_min"] = rng.choice([-0.06, -0.03, 0.0, 0.03])
    if rng.random() < 0.16:
        params["atr_days"] = rng.choice([14, 20, 30, 50])
        params["atr_pct_max"] = rng.choice([0.022, 0.026, 0.030, 0.035, 0.045])
    return Candidate(
        family="ma_cross",
        direction="long_short",
        params=tuple(sorted(params.items())),
    )


def candidate_key(candidate: Candidate) -> tuple[Any, ...]:
    return (candidate.family, candidate.direction, candidate.params)


def local_refine_candidates(
    top_by_family: dict[str, list[dict[str, Any]]],
    rng: random.Random,
    seen: set[tuple[Any, ...]],
) -> list[Candidate]:
    candidates: list[Candidate] = []
    for records in top_by_family.values():
        for item in records[:10]:
            base = item["candidate"]
            for variant in neighbors(base, rng):
                key = candidate_key(variant)
                if key in seen:
                    continue
                seen.add(key)
                candidates.append(variant)
    return candidates


def neighbors(base: Candidate, rng: random.Random) -> list[Candidate]:
    params = dict(base.params)
    variants: list[Candidate] = []
    for _ in range(80):
        p = dict(params)
        for key in rng.sample(list(p.keys()), k=min(len(p), rng.randint(1, 3))):
            value = p[key]
            if isinstance(value, bool):
                p[key] = not value
            elif isinstance(value, int):
                delta = rng.choice([-5, -3, -2, -1, 1, 2, 3, 5])
                if "window" in key or "ma" in key or "channel" in key or "days" in key or key == "max_hold":
                    p[key] = int(max(5, min(200, value + delta)))
            elif isinstance(value, float):
                p[key] = round(max(-0.15, min(0.45, value + rng.choice([-0.02, -0.01, 0.01, 0.02]))), 4)
        if base.family == "ma_cross" and p.get("short_window", 5) >= p.get("long_window", 20):
            p["long_window"] = min(200, p["short_window"] + 10)
        p = normalize_neighbor_params(p)
        variants.append(Candidate(base.family, base.direction, tuple(sorted(p.items()))))
    return variants


def normalize_neighbor_params(params: dict[str, Any]) -> dict[str, Any]:
    grid_values = {
        "atr_days": [10, 14, 20, 30, 50],
        "realized_vol_days": [20, 40, 60],
        "volume_window": [20, 40, 60],
        "own_roc_days": [20, 40, 60, 80, 120],
        "spy_roc_days": [20, 40, 60, 80, 120],
        "relative_days": [20, 40, 60, 80, 120],
        "momentum_days": [20, 40, 60, 80, 120],
        "qqq_slope_days": [20, 40, 60, 80],
        "sma_slope_days": [20, 40, 60, 80],
        "spy_slope_days": [20, 40, 60, 80],
        "adx_days": [14, 20, 30],
        "entry_ma": [10, 20, 30, 50, 80, 100, 120, 150, 200],
        "qqq_ma": [50, 80, 100, 120, 150, 200],
        "spy_ma": [50, 80, 100, 120, 150, 200],
        "exit_ma": [20, 30, 40, 50, 80, 100, 120, 150, 200],
    }
    normalized = dict(params)
    for key, values in grid_values.items():
        if key in normalized:
            normalized[key] = min(values, key=lambda item: abs(item - normalized[key]))
    for key in ["entry_channel", "exit_channel"]:
        if key in normalized:
            normalized[key] = int(max(5, min(100, normalized[key])))
    if "short_window" in normalized:
        normalized["short_window"] = int(max(5, min(50, normalized["short_window"])))
    if "long_window" in normalized:
        normalized["long_window"] = int(max(20, min(200, normalized["long_window"])))
    if "max_hold" in normalized:
        normalized["max_hold"] = int(max(5, min(80, normalized["max_hold"])))
    return normalized


def signal_arrays(candidates: list[Candidate], data: MarketData, ind: Indicators) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    n = len(data.close)
    b = len(candidates)
    long_sig = np.ones((b, n), dtype=bool)
    short_sig = np.ones((b, n), dtype=bool)
    exit_long = np.zeros((b, n), dtype=bool)
    exit_short = np.zeros((b, n), dtype=bool)
    for row, candidate in enumerate(candidates):
        p = dict(candidate.params)
        if candidate.family == "ma_cross":
            sw, lw = p["short_window"], p["long_window"]
            s = ind.sma[sw]
            l = ind.sma[lw]
            base_long = (s > l) & (np.r_[False, s[:-1] <= l[:-1]])
            base_short = (s < l) & (np.r_[False, s[:-1] >= l[:-1]])
        elif candidate.family == "channel":
            w = p["entry_channel"]
            base_long = data.close > ind.prior_high[w]
            base_short = data.close < ind.prior_low[w]
        elif candidate.family == "price_ma":
            w = p["entry_ma"]
            ma = get_ma(ind, p.get("entry_ma_kind", "sma"), w, spy=False)
            base_long = (data.close > ma) & (np.r_[False, data.close[:-1] <= ma[:-1]])
            base_short = (data.close < ma) & (np.r_[False, data.close[:-1] >= ma[:-1]])
        else:
            roc_arr = ind.roc[p["momentum_days"]]
            base_long = roc_arr > p["momentum_long_min"]
            base_short = roc_arr < -p["momentum_short_min"]
        if candidate.direction == "long_only":
            base_short = np.zeros(n, dtype=bool)
        elif candidate.direction == "short_only":
            base_long = np.zeros(n, dtype=bool)

        long_filter = np.ones(n, dtype=bool)
        short_filter = np.ones(n, dtype=bool)
        if "qqq_ma" in p:
            ma = get_ma(ind, p.get("qqq_ma_kind", "sma"), p["qqq_ma"], spy=False)
            long_filter &= data.close > ma
            short_filter &= data.close < ma
        if "own_roc_days" in p:
            r = ind.roc[p["own_roc_days"]]
            long_filter &= r > p.get("own_roc_min", 0)
            short_filter &= r < -p.get("own_roc_min", 0)
        if "qqq_slope_days" in p:
            s = ind.slope[p["qqq_slope_days"]]
            long_filter &= s >= p.get("qqq_slope_min", 0)
            short_filter &= s <= -p.get("qqq_slope_min", 0)
        if "sma_slope_days" in p:
            s = ind.sma_slope[p["sma_slope_days"]]
            long_filter &= s >= p.get("sma_slope_min", 0)
            short_filter &= s <= -p.get("sma_slope_min", 0)
        if "adx_days" in p:
            a = ind.adx[p["adx_days"]]
            long_filter &= a >= p["adx_min"]
            short_filter &= a >= p["adx_min"]
            if p.get("di_confirm"):
                long_filter &= ind.plus_di[p["adx_days"]] > ind.minus_di[p["adx_days"]]
                short_filter &= ind.minus_di[p["adx_days"]] > ind.plus_di[p["adx_days"]]
        if "spy_ma" in p:
            ma = get_ma(ind, p.get("spy_ma_kind", "sma"), p["spy_ma"], spy=True)
            long_filter &= data.spy_close > ma
            short_filter &= data.spy_close < ma
        if "spy_roc_days" in p:
            r = ind.spy_roc[p["spy_roc_days"]]
            long_filter &= r > p.get("spy_roc_min", 0)
            short_filter &= r < -p.get("spy_roc_min", 0)
        if "spy_slope_days" in p:
            s = ind.spy_slope[p["spy_slope_days"]]
            long_filter &= s >= p.get("spy_slope_min", 0)
            short_filter &= s <= -p.get("spy_slope_min", 0)
        if "relative_days" in p:
            diff = ind.roc[p["relative_days"]] - ind.spy_roc[p["relative_days"]]
            long_filter &= diff > p.get("relative_min", 0)
            short_filter &= diff < -p.get("relative_min", 0)
        if "atr_days" in p and ("atr_pct_max" in p or "atr_pct_min" in p):
            atrp = ind.atr_pct[p["atr_days"]]
            if "atr_pct_min" in p:
                long_filter &= atrp >= p["atr_pct_min"]
                short_filter &= atrp >= p["atr_pct_min"]
            if "atr_pct_max" in p:
                long_filter &= atrp <= p["atr_pct_max"]
                short_filter &= atrp <= p["atr_pct_max"]
        if "realized_vol_days" in p:
            rv = ind.realized_vol[p["realized_vol_days"]]
            long_filter &= rv <= p["realized_vol_max"]
            short_filter &= rv <= p["realized_vol_max"]
        if "volume_window" in p:
            ratio = data.volume / ind.volume_ma[p["volume_window"]]
            long_filter &= ratio >= p["volume_ratio_min"]
            short_filter &= ratio >= p["volume_ratio_min"]

        long_sig[row] = base_long & long_filter
        short_sig[row] = base_short & short_filter
        if p.get("reverse_exit", False):
            exit_long[row] |= short_sig[row]
            exit_short[row] |= long_sig[row]
        if "exit_channel" in p:
            w = p["exit_channel"]
            exit_long[row] |= data.close < ind.prior_low[w]
            exit_short[row] |= data.close > ind.prior_high[w]
        if "exit_ma" in p:
            ma = get_ma(ind, p.get("exit_ma_kind", "sma"), p["exit_ma"], spy=False)
            exit_long[row] |= data.close < ma
            exit_short[row] |= data.close > ma
    long_sig &= ~np.isnan(data.close)
    short_sig &= ~np.isnan(data.close)
    return long_sig, short_sig, exit_long, exit_short


def get_ma(ind: Indicators, kind: str, window: int, *, spy: bool) -> np.ndarray:
    if spy:
        return ind.spy_ema[window] if kind == "ema" else ind.spy_sma[window]
    return ind.ema[window] if kind == "ema" else ind.sma[window]


def evaluate_candidates(
    candidates: list[Candidate],
    data: MarketData,
    ind: Indicators,
    start_idx: int,
    end_idx: int,
) -> list[dict[str, Any]]:
    if not candidates:
        return []
    long_sig, short_sig, exit_long_sig, exit_short_sig = signal_arrays(candidates, data, ind)
    b = len(candidates)
    equity = np.full(b, INITIAL_CASH, dtype=float)
    peak = equity.copy()
    max_dd = np.zeros(b, dtype=float)
    position = np.zeros(b, dtype=np.int8)
    qty = np.zeros(b, dtype=float)
    entry_price = np.zeros(b, dtype=float)
    entry_equity = np.zeros(b, dtype=float)
    entry_cash = np.zeros(b, dtype=float)
    high_since = np.zeros(b, dtype=float)
    low_since = np.full(b, np.inf, dtype=float)
    highest_close = np.zeros(b, dtype=float)
    lowest_close = np.full(b, np.inf, dtype=float)
    hold_days = np.zeros(b, dtype=np.int16)
    rounds = np.zeros(b, dtype=np.int16)
    wins = np.zeros(b, dtype=np.int16)
    long_count = np.zeros(b, dtype=np.int16)
    short_count = np.zeros(b, dtype=np.int16)
    fees = np.zeros(b, dtype=float)
    params = [dict(c.params) for c in candidates]

    for idx in range(start_idx, end_idx + 1):
        if idx > start_idx:
            sig = idx - 1
            open_price = data.open[idx]
            close_sig = data.close[sig]
            active = position != 0
            if np.any(active):
                hold_days[active] += 1
                high_since[active] = np.maximum(high_since[active], data.high[sig])
                low_since[active] = np.minimum(low_since[active], data.low[sig])
                highest_close[active] = np.maximum(highest_close[active], close_sig)
                lowest_close[active] = np.minimum(lowest_close[active], close_sig)

            exit_mask = np.zeros(b, dtype=bool)
            long_pos = position == 1
            short_pos = position == -1
            exit_mask |= long_pos & exit_long_sig[:, sig]
            exit_mask |= short_pos & exit_short_sig[:, sig]
            for row, p in enumerate(params):
                if position[row] == 0:
                    continue
                if "fixed_stop" in p:
                    if position[row] == 1 and close_sig <= entry_price[row] * (1 - p["fixed_stop"]):
                        exit_mask[row] = True
                    if position[row] == -1 and close_sig >= entry_price[row] * (1 + p["fixed_stop"]):
                        exit_mask[row] = True
                if "trailing_stop" in p:
                    if position[row] == 1 and close_sig <= high_since[row] * (1 - p["trailing_stop"]):
                        exit_mask[row] = True
                    if position[row] == -1 and close_sig >= low_since[row] * (1 + p["trailing_stop"]):
                        exit_mask[row] = True
                if "take_profit" in p:
                    if position[row] == 1 and close_sig >= entry_price[row] * (1 + p["take_profit"]):
                        exit_mask[row] = True
                    if position[row] == -1 and close_sig <= entry_price[row] * (1 - p["take_profit"]):
                        exit_mask[row] = True
                if "atr_days" in p:
                    atr_value = ind.atr[p["atr_days"]][sig]
                    if not np.isnan(atr_value):
                        if "atr_stop_mult" in p:
                            if position[row] == 1 and close_sig <= entry_price[row] - p["atr_stop_mult"] * atr_value:
                                exit_mask[row] = True
                            if position[row] == -1 and close_sig >= entry_price[row] + p["atr_stop_mult"] * atr_value:
                                exit_mask[row] = True
                        if "atr_trail_mult" in p:
                            if position[row] == 1 and close_sig <= highest_close[row] - p["atr_trail_mult"] * atr_value:
                                exit_mask[row] = True
                            if position[row] == -1 and close_sig >= lowest_close[row] + p["atr_trail_mult"] * atr_value:
                                exit_mask[row] = True
                if "max_hold" in p and hold_days[row] >= p["max_hold"]:
                    exit_mask[row] = True

            if np.any(exit_mask):
                for row in np.flatnonzero(exit_mask):
                    equity[row], fee = close_position(
                        equity[row],
                        position[row],
                        qty[row],
                        entry_price[row],
                        entry_equity[row],
                        entry_cash[row],
                        open_price,
                    )
                    fees[row] += fee
                    rounds[row] += 1
                    if equity[row] > entry_equity[row]:
                        wins[row] += 1
                    position[row] = 0
                    qty[row] = 0

            flat = position == 0
            enter_long = flat & long_sig[:, sig]
            enter_short = flat & short_sig[:, sig] & ~enter_long
            if np.any(enter_long):
                for row in np.flatnonzero(enter_long):
                    price = open_price * (1 + SLIPPAGE)
                    q, fee, cash = open_long_quantity(equity[row], price)
                    if q > 0:
                        entry_equity[row] = equity[row]
                        equity[row] = cash + q * data.close[idx]
                        fees[row] += fee
                        position[row] = 1
                        qty[row] = q
                        entry_price[row] = price
                        entry_cash[row] = cash
                        high_since[row] = data.high[sig]
                        low_since[row] = data.low[sig]
                        highest_close[row] = data.close[sig]
                        lowest_close[row] = data.close[sig]
                        hold_days[row] = 0
                        long_count[row] += 1
            if np.any(enter_short):
                for row in np.flatnonzero(enter_short):
                    price = open_price * (1 - SLIPPAGE)
                    q, fee = open_short_quantity(equity[row], price)
                    if q > 0:
                        entry_equity[row] = equity[row]
                        entry_cash[row] = equity[row] - fee
                        equity[row] = entry_cash[row] + q * (price - data.close[idx])
                        fees[row] += fee
                        position[row] = -1
                        qty[row] = q
                        entry_price[row] = price
                        high_since[row] = data.high[sig]
                        low_since[row] = data.low[sig]
                        highest_close[row] = data.close[sig]
                        lowest_close[row] = data.close[sig]
                        hold_days[row] = 0
                        short_count[row] += 1

        mark = mark_equity(equity, position, qty, entry_price, entry_cash, data.close[idx])
        equity = mark
        peak = np.maximum(peak, equity)
        dd = equity / peak - 1
        max_dd = np.minimum(max_dd, dd)

    force_mask = position != 0
    if np.any(force_mask):
        close_price = data.close[end_idx]
        for row in np.flatnonzero(force_mask):
            equity[row], fee = close_position(
                equity[row],
                position[row],
                qty[row],
                entry_price[row],
                entry_equity[row],
                entry_cash[row],
                close_price,
                already_slipped=False,
            )
            fees[row] += fee
            rounds[row] += 1
            if equity[row] > entry_equity[row]:
                wins[row] += 1
            position[row] = 0
    return [
        {
            "total_return": float(equity[row] / INITIAL_CASH - 1),
            "max_drawdown": float(max_dd[row]),
            "win_rate": float(wins[row] / rounds[row]) if rounds[row] else 0.0,
            "round_trips": int(rounds[row]),
            "long_count": int(long_count[row]),
            "short_count": int(short_count[row]),
            "total_fees": float(fees[row]),
        }
        for row in range(b)
    ]


def open_long_quantity(equity: float, price: float) -> tuple[float, float, float]:
    q = equity / (price * (1 + US_COMMISSION_RATE))
    fee = commission(q * price)
    if fee <= equity and abs(fee - q * price * US_COMMISSION_RATE) < 1e-6:
        return q, fee, equity - q * price - fee
    q = max(0.0, (equity - US_MIN_COMMISSION) / price)
    fee = commission(q * price)
    return q, fee, equity - q * price - fee


def open_short_quantity(equity: float, price: float) -> tuple[float, float]:
    q = equity / (price * (1 + US_COMMISSION_RATE))
    fee = commission(q * price)
    if fee > equity:
        q = max(0.0, (equity - US_MIN_COMMISSION) / price)
        fee = commission(q * price)
    return q, fee


def close_position(
    current_equity: float,
    side: int,
    qty: float,
    entry_price: float,
    entry_equity: float,
    entry_cash: float,
    price: float,
    *,
    already_slipped: bool = True,
) -> tuple[float, float]:
    if side == 1:
        exec_price = price if already_slipped else price * (1 - SLIPPAGE)
        notional = qty * exec_price
        fee = sell_fee(notional, qty)
        return entry_cash + notional - fee, fee
    exec_price = price if already_slipped else price * (1 + SLIPPAGE)
    notional = qty * exec_price
    fee = buy_fee(notional)
    return entry_cash + qty * (entry_price - exec_price) - fee, fee


def mark_equity(
    current_equity: np.ndarray,
    position: np.ndarray,
    qty: np.ndarray,
    entry_price: np.ndarray,
    entry_cash: np.ndarray,
    close: float,
) -> np.ndarray:
    out = current_equity.copy()
    long_mask = position == 1
    short_mask = position == -1
    out[long_mask] = entry_cash[long_mask] + qty[long_mask] * close
    out[short_mask] = entry_cash[short_mask] + qty[short_mask] * (entry_price[short_mask] - close)
    return out


def commission(notional: float) -> float:
    return max(notional * US_COMMISSION_RATE, US_MIN_COMMISSION)


def buy_fee(notional: float) -> float:
    return commission(notional)


def sell_fee(notional: float, quantity: float) -> float:
    return commission(notional) + notional * US_SEC_FEE_RATE + min(quantity * US_TAF_RATE_PER_SHARE, US_TAF_MAX)


def preliminary_pass(metric: dict[str, Any]) -> bool:
    return (
        metric["total_return"] >= 0.35
        and metric["max_drawdown"] >= -0.20
        and metric["win_rate"] >= 0.70
        and metric["round_trips"] >= 5
    )


def annual_metrics(candidates: list[Candidate], data: MarketData, ind: Indicators, ranges: DateRanges) -> list[dict[str, dict[str, Any]]]:
    result = [dict() for _ in candidates]
    for label, (start_idx, end_idx) in ranges.periods.items():
        metrics = evaluate_candidates(candidates, data, ind, start_idx, end_idx)
        for row, metric in enumerate(metrics):
            result[row][label] = metric
    return result


def annual_review(prelim: list[dict[str, Any]], data: MarketData, ind: Indicators, ranges: DateRanges) -> list[dict[str, Any]]:
    reviewed: list[dict[str, Any]] = []
    batch_size = 512
    for offset in range(0, len(prelim), batch_size):
        items = prelim[offset : offset + batch_size]
        candidates = [item["candidate"] for item in items]
        years = annual_metrics(candidates, data, ind, ranges)
        train_full = evaluate_candidates(candidates, data, ind, ranges.train_start, ranges.train_end)
        for item, year_metrics, full in zip(items, years, train_full):
            train_pass = train_constraint_pass(year_metrics, full, include_2026=False)
            reviewed.append({**item, "years": year_metrics, "train_full": full, "train_pass": train_pass})
    return reviewed


def train_constraint_pass(years: dict[str, dict[str, Any]], full: dict[str, Any], *, include_2026: bool) -> bool:
    labels = ["2022", "2023", "2024", "2025"] + (["2026YTD"] if include_2026 else [])
    return (
        all(years[label]["total_return"] >= 0.10 for label in labels)
        and all(years[label]["max_drawdown"] >= -0.20 for label in labels)
        and full["max_drawdown"] >= -0.15
        and full["win_rate"] >= 0.80
    )


def walk_forward(candidate: Candidate, data: MarketData, ind: Indicators, ranges: DateRanges) -> dict[str, Any]:
    years = annual_metrics([candidate], data, ind, ranges)[0]
    train_2023 = evaluate_candidates([candidate], data, ind, *ranges.wf_train_2023)[0]
    train_2024 = evaluate_candidates([candidate], data, ind, *ranges.wf_train_2024)[0]
    train_2025 = evaluate_candidates([candidate], data, ind, *ranges.wf_train_2025)[0]
    pass_2023_train = train_constraint_pass({"2022": years["2022"], "2023": years["2023"]}, train_2023, include_2026=False) if False else (
        years["2022"]["total_return"] >= 0.10
        and years["2023"]["total_return"] >= 0.10
        and years["2022"]["max_drawdown"] >= -0.20
        and years["2023"]["max_drawdown"] >= -0.20
        and train_2023["max_drawdown"] >= -0.15
        and train_2023["win_rate"] >= 0.80
    )
    pass_2024_train = (
        pass_2023_train
        and years["2024"]["total_return"] >= 0.10
        and years["2024"]["max_drawdown"] >= -0.20
        and train_2024["max_drawdown"] >= -0.15
        and train_2024["win_rate"] >= 0.80
    )
    pass_2025_train = (
        pass_2024_train
        and years["2025"]["total_return"] >= 0.10
        and years["2025"]["max_drawdown"] >= -0.20
        and train_2025["max_drawdown"] >= -0.15
        and train_2025["win_rate"] >= 0.80
    )
    wf2024 = pass_2023_train and years["2024"]["total_return"] >= 0.10 and years["2024"]["max_drawdown"] >= -0.20
    wf2025 = pass_2024_train and years["2025"]["total_return"] >= 0.10 and years["2025"]["max_drawdown"] >= -0.20
    wf2026 = pass_2025_train and years["2026YTD"]["total_return"] >= 0.10 and years["2026YTD"]["max_drawdown"] >= -0.20
    return {
        "2024": {"pass": wf2024, **years["2024"]},
        "2025": {"pass": wf2025, **years["2025"]},
        "2026YTD": {"pass": wf2026, **years["2026YTD"]},
        "all_pass": bool(wf2024 and wf2025 and wf2026),
    }


def final_pass(item: dict[str, Any], *, max_drawdown_limit: float) -> bool:
    full = item.get("full")
    years = item.get("years")
    wf = item.get("walk_forward", {})
    if full is None or years is None:
        return False
    return (
        wf.get("all_pass", False)
        and all(years[label]["total_return"] >= 0.10 for label in ["2022", "2023", "2024", "2025", "2026YTD"])
        and all(years[label]["max_drawdown"] >= -0.20 for label in ["2022", "2023", "2024", "2025", "2026YTD"])
        and full["max_drawdown"] >= -max_drawdown_limit
        and full["win_rate"] >= 0.80
    )


def steady_sort_key(metric: dict[str, Any]) -> tuple[float, float, float, float, float]:
    return (
        -metric["max_drawdown"],
        -metric["win_rate"],
        -metric["total_return"],
        abs(metric["round_trips"] - 14),
        -metric["round_trips"],
    )


def record_sort_key(item: dict[str, Any]) -> tuple[float, float, float, float, float]:
    full = item.get("full") or item.get("train_full")
    years = item.get("years", {})
    min_year = min((years.get(label, {}).get("total_return", -9) for label in ["2022", "2023", "2024", "2025", "2026YTD"]), default=-9)
    std_year = np.std([years[label]["total_return"] for label in years]) if years else 9
    sample_penalty = 0 if full["round_trips"] >= 10 else 1
    return (
        -full["max_drawdown"],
        sample_penalty,
        -min_year,
        std_year,
        -full["win_rate"],
    )


def select_top3(records: list[dict[str, Any]], require_pass: bool = True) -> list[dict[str, Any]]:
    sorted_records = sorted(records, key=record_sort_key)
    selected: list[dict[str, Any]] = []
    families: set[str] = set()
    for item in sorted_records:
        family = item["candidate"].family
        if family in families:
            continue
        selected.append(item)
        families.add(family)
        if len(selected) == 3:
            return selected
    for item in sorted_records:
        if item not in selected:
            selected.append(item)
        if len(selected) == 3:
            break
    return selected


def serialize_record(item: dict[str, Any]) -> dict[str, Any]:
    candidate = item["candidate"]
    full = item.get("full") or item.get("train_full")
    return {
        "strategy": strategy_name(candidate),
        "family": candidate.family,
        "direction": candidate.direction,
        "formula": formula(candidate),
        "parameters": candidate.as_dict(),
        "full": full,
        "years": item.get("years", {}),
        "walk_forward": item.get("walk_forward", {}),
        "sample_warning": full["round_trips"] < 10 if full else None,
    }


def strategy_name(candidate: Candidate) -> str:
    if candidate.name:
        return candidate.name
    if candidate.family == "ma_cross":
        return f"QQQ SMA{candidate.get('short_window')}/{candidate.get('long_window')} steady"
    if candidate.family == "channel":
        return f"QQQ channel {candidate.get('entry_channel')}/{candidate.get('exit_channel', '-')}"
    if candidate.family == "price_ma":
        return f"QQQ price {candidate.get('entry_ma_kind', 'sma').upper()}{candidate.get('entry_ma')}"
    return f"QQQ ROC{candidate.get('momentum_days')} momentum"


def formula(candidate: Candidate) -> str:
    p = dict(candidate.params)
    pieces: list[str] = []
    if candidate.family == "ma_cross":
        pieces.append(f"Entry: SMA{p['short_window']} crosses SMA{p['long_window']}; short side symmetric.")
    elif candidate.family == "channel":
        pieces.append(f"Entry: close breaks prior {p['entry_channel']}d high/low.")
    elif candidate.family == "price_ma":
        pieces.append(f"Entry: close crosses {p.get('entry_ma_kind','sma').upper()}{p['entry_ma']}.")
    else:
        pieces.append(f"Entry: ROC{p['momentum_days']} > {p['momentum_long_min']:.0%}; short threshold {p['momentum_short_min']:.0%}.")
    filters: list[str] = []
    if "qqq_ma" in p:
        filters.append(f"QQQ close above/below {p.get('qqq_ma_kind','sma').upper()}{p['qqq_ma']}")
    if "own_roc_days" in p:
        filters.append(f"QQQ ROC{p['own_roc_days']} > {p['own_roc_min']:.0%}")
    if "spy_ma" in p:
        filters.append(f"SPY {p.get('spy_ma_kind','sma').upper()}{p['spy_ma']} filter")
    if "spy_roc_days" in p:
        filters.append(f"SPY ROC{p['spy_roc_days']} > {p['spy_roc_min']:.0%}")
    if "relative_days" in p:
        filters.append(f"QQQ-SPY ROC{p['relative_days']} > {p['relative_min']:.0%}")
    if "atr_days" in p and "atr_pct_max" in p:
        filters.append(f"ATR{p['atr_days']}% <= {p['atr_pct_max']:.1%}")
    if "realized_vol_days" in p:
        filters.append(f"RV{p['realized_vol_days']} <= {p['realized_vol_max']:.0%}")
    if filters:
        pieces.append("Filters: " + "; ".join(filters) + ".")
    exits: list[str] = []
    if p.get("reverse_exit"):
        exits.append("qualified reverse signal")
    if "exit_ma" in p:
        exits.append(f"{p.get('exit_ma_kind','sma').upper()}{p['exit_ma']}")
    if "exit_channel" in p:
        exits.append(f"{p['exit_channel']}d opposite channel")
    if "fixed_stop" in p:
        exits.append(f"fixed stop {p['fixed_stop']:.0%}")
    if "trailing_stop" in p:
        exits.append(f"trailing stop {p['trailing_stop']:.0%}")
    if "take_profit" in p:
        exits.append(f"take profit {p['take_profit']:.0%}")
    if "atr_stop_mult" in p:
        exits.append(f"ATR stop {p['atr_stop_mult']}x")
    if "max_hold" in p:
        exits.append(f"max hold {p['max_hold']}d")
    if exits:
        pieces.append("Exit: " + "; ".join(exits) + ".")
    return " ".join(pieces)


if __name__ == "__main__":
    main()
