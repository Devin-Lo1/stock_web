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
BROKER_COMMISSION_RATE = 0.00138
BROKER_MIN_COMMISSION = 18.0
HK_STAMP_DUTY_RATE = 0.001
HK_SFC_TRANSACTION_LEVY_RATE = 0.000027
HK_AFRC_TRANSACTION_LEVY_RATE = 0.0000015
HK_TRADING_FEE_RATE = 0.0000565
HK_CCASS_SETTLEMENT_FEE_RATE = 0.000042
HK_CCASS_MIN = 2.0
HK_CCASS_MAX = 100.0

START = date(2021, 1, 4)
END = date(2026, 6, 5)
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
    parser.add_argument("--output", default="scripts/research_icbc_hk_steady_tmp_result.json")
    parser.add_argument("--progress", default="scripts/research_icbc_hk_steady_tmp_progress.json")
    args = parser.parse_args()

    started = time.time()
    rng = random.Random(args.seed)
    write_progress(args.progress, "fetching_data", 0, args.stage1, started)
    rows = fetch_cloud_candles()
    data = MarketData.from_rows(rows)
    split_report = split_adjustment_report(rows["HK.01398"])
    indicators = Indicators(data)
    ranges = DateRanges(data.dates)

    current_app = current_app_candidate()
    if current_app is None:
        current_metrics = None
        current_train_metrics = None
        current_years: dict[str, dict[str, Any]] = {}
        seen: set[tuple[Any, ...]] = set()
        tested = 0
    else:
        current_metrics = evaluate_candidates(
            [current_app],
            data,
            indicators,
            ranges.all_start,
            ranges.all_end,
        )[0]
        current_train_metrics = evaluate_candidates(
            [current_app],
            data,
            indicators,
            ranges.train_start,
            ranges.train_end,
        )[0]
        current_years = annual_metrics([current_app], data, indicators, ranges)[0]
        seen = {candidate_key(current_app)}
        tested = 1
    prelim: list[dict[str, Any]] = []
    top_by_family: dict[str, list[dict[str, Any]]] = {}
    if current_app is not None and current_train_metrics is not None and preliminary_pass(current_train_metrics):
        top_by_family.setdefault(current_app.family, []).append(
            {"candidate": current_app, "train_full": current_train_metrics}
        )

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
                family_records.sort(key=lambda item: steady_prelim_sort_key(item["train_full"]))
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
    enrich_records(closest, data, indicators, ranges)

    output = {
        "meta": {
            "target": "HK.01398",
            "benchmark": "HK.800000",
            "auxiliary_benchmark": None,
            "range": f"{START.isoformat()}~{END.isoformat()}",
            "seed": args.seed,
            "started_at": datetime.now().isoformat(timespec="seconds"),
            "elapsed_seconds": round(time.time() - started, 2),
            "cost_model": {
                "initial_cash": INITIAL_CASH,
                "slippage_single_side": SLIPPAGE,
                "broker_commission_rate": BROKER_COMMISSION_RATE,
                "broker_min_commission": BROKER_MIN_COMMISSION,
                "hk_stamp_duty_rate": HK_STAMP_DUTY_RATE,
                "hk_sfc_transaction_levy_rate": HK_SFC_TRANSACTION_LEVY_RATE,
                "hk_afrc_transaction_levy_rate": HK_AFRC_TRANSACTION_LEVY_RATE,
                "hk_trading_fee_rate": HK_TRADING_FEE_RATE,
                "hk_ccass_settlement_fee_rate": HK_CCASS_SETTLEMENT_FEE_RATE,
                "hk_ccass_min": HK_CCASS_MIN,
                "hk_ccass_max": HK_CCASS_MAX,
                "fee_note": "Hong Kong stock approximation: broker commission plus HK stamp duty, SFC/AFRC levies, trading fee, and CCASS settlement fee; US SEC fee and TAF are not applied.",
            },
            "no_future_function": True,
            "selection_rule": "2026YTD is used only as final validation gate; ranking uses 2021-2025 training metrics.",
            "split_adjustment": split_report,
            "execution": "Signal at T close, execution at T+1 open; final close forced at interval end.",
            "current_app_note": "No existing App personalized strategy template was found for HK.01398.",
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
        "current_app": None
        if current_app is None
        else serialize_record(
            {
                "candidate": current_app,
                "full": current_metrics,
                "train_full": current_train_metrics,
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
for code in ['HK.01398', 'HK.800000']:
    payload[code] = [row(c) for c in list_candles_between(code, 'day', date(2021,1,4), date(2026,6,5))]
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


def split_adjustment_report(rows: list[dict[str, Any]]) -> dict[str, Any]:
    sorted_rows = sorted(rows, key=lambda item: item["time"])
    large_gaps: list[dict[str, Any]] = []
    for previous, current in zip(sorted_rows, sorted_rows[1:]):
        prev_close = float(previous["close"])
        current_open = float(current["open"])
        current_close = float(current["close"])
        if prev_close <= 0 or current_open <= 0:
            continue
        open_gap = current_open / prev_close - 1
        close_gap = current_close / prev_close - 1
        if abs(open_gap) >= 0.40 or abs(close_gap) >= 0.40:
            large_gaps.append(
                {
                    "previous_date": previous["time"],
                    "current_date": current["time"],
                    "previous_close": prev_close,
                    "current_open": current_open,
                    "current_close": current_close,
                    "open_gap": open_gap,
                    "close_gap": close_gap,
                }
            )
    return {
        "known_event": "No known ICBC HK split adjustment was required for the requested 2021-2026 window; the cloud OHLC series is still checked for split-like discontinuities before backtesting.",
        "large_gap_count": len(large_gaps),
        "large_gaps": large_gaps[:5],
        "handling": (
            "No additional split adjustment was applied because no split-like discontinuity was detected in the cloud OHLC series."
            if not large_gaps
            else "Large split-like gaps were detected; review raw data before using this result."
        ),
    }


class MarketData:
    def __init__(self, rows: dict[str, list[dict[str, Any]]]) -> None:
        target = rows["HK.01398"]
        benchmark_by_date = {item["time"]: item for item in rows["HK.800000"]}
        aligned = [
            (item, benchmark_by_date[item["time"]])
            for item in target
            if item["time"] in benchmark_by_date
        ]
        self.dates = np.array([date.fromisoformat(item[0]["time"]) for item in aligned], dtype=object)
        self.open = np.array([item[0]["open"] for item in aligned], dtype=float)
        self.high = np.array([item[0]["high"] for item in aligned], dtype=float)
        self.low = np.array([item[0]["low"] for item in aligned], dtype=float)
        self.close = np.array([item[0]["close"] for item in aligned], dtype=float)
        self.volume = np.array([item[0]["volume"] for item in aligned], dtype=float)
        self.benchmark_open = np.array([item[1]["open"] for item in aligned], dtype=float)
        self.benchmark_high = np.array([item[1]["high"] for item in aligned], dtype=float)
        self.benchmark_low = np.array([item[1]["low"] for item in aligned], dtype=float)
        self.benchmark_close = np.array([item[1]["close"] for item in aligned], dtype=float)
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
        self.benchmark_sma = {w: rolling_mean(data.benchmark_close, w) for w in windows}
        self.benchmark_ema = {w: ema(data.benchmark_close, w) for w in windows}
        self.roc = {w: roc(data.close, w) for w in [20, 40, 60, 80, 120]}
        self.benchmark_roc = {w: roc(data.benchmark_close, w) for w in [20, 40, 60, 80, 120]}
        self.slope = {w: rolling_slope(data.close, w) for w in [20, 40, 60, 80]}
        self.benchmark_slope = {w: rolling_slope(data.benchmark_close, w) for w in [20, 40, 60, 80]}
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


def current_app_candidate() -> Candidate | None:
    return None


def random_candidate(rng: random.Random) -> Candidate:
    if rng.random() < 0.34:
        return random_icbc_hk_steady_region_candidate(rng)
    family = rng.choices(
        ["ma_cross", "channel", "price_ma", "momentum"],
        weights=[0.34, 0.36, 0.18, 0.12],
        k=1,
    )[0]
    direction = rng.choices(["long_short", "long_only", "short_only"], weights=[0.70, 0.24, 0.06], k=1)[0]
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
        if rng.random() < 0.32:
            params["qqq_ma2"] = rng.choice([50, 80, 100, 120, 150, 200])
            params["qqq_ma2_kind"] = rng.choice(["sma", "ema"])
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
    if rng.random() < 0.42:
        params["benchmark_ma"] = rng.choice([50, 80, 100, 120, 150, 200])
        params["benchmark_ma_kind"] = rng.choice(["sma", "ema"])
    if rng.random() < 0.32:
        params["benchmark_roc_days"] = rng.choice([20, 40, 60, 80, 120])
        params["benchmark_roc_min"] = rng.choice([-0.10, -0.08, -0.04, 0.0, 0.02, 0.04, 0.06])
    if rng.random() < 0.22:
        params["benchmark_slope_days"] = rng.choice([20, 40, 60, 80])
        params["benchmark_slope_min"] = rng.choice([0.0, 0.0003, 0.0005, 0.001])
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
        params["volume_ratio_min"] = rng.choice([1.1, 1.2, 1.5, 2.0])

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
        params["max_hold"] = rng.randint(5, 100)
    return Candidate(family=family, direction=direction, params=tuple(sorted(params.items())))


def random_icbc_hk_steady_region_candidate(rng: random.Random) -> Candidate:
    if rng.random() < 0.72:
        params: dict[str, Any] = {
            "short_window": rng.randint(5, 15),
            "long_window": rng.randint(80, 160),
            "qqq_ma": rng.choice([80, 100, 120, 150, 200]),
            "qqq_ma_kind": rng.choice(["sma", "ema"]),
            "benchmark_ma": rng.choice([80, 100, 120, 150, 200]),
            "benchmark_ma_kind": rng.choice(["sma", "ema"]),
            "own_roc_days": rng.choice([40, 60, 80, 120]),
            "own_roc_min": rng.choice([-0.04, -0.02, 0.0, 0.02, 0.04, 0.06]),
            "relative_days": rng.choice([20, 40, 60, 80]),
            "relative_min": rng.choice([-0.10, -0.08, -0.06, -0.03, 0.0, 0.03, 0.06]),
            "exit_ma": rng.choice([80, 100, 120, 150, 200]),
            "exit_ma_kind": rng.choice(["sma", "ema"]),
            "reverse_exit": rng.random() < 0.55,
        }
        if params["short_window"] >= params["long_window"]:
            params["long_window"] = min(200, params["short_window"] + 80)
        if rng.random() < 0.72:
            params["fixed_stop"] = rng.choice([0.06, 0.08, 0.10, 0.12, 0.15, 0.18])
        if rng.random() < 0.72:
            params["trailing_stop"] = rng.choice([0.06, 0.08, 0.10, 0.12, 0.15, 0.18])
        if rng.random() < 0.78:
            params["take_profit"] = rng.choice([0.08, 0.10, 0.12, 0.15, 0.18, 0.20, 0.24, 0.30])
        if rng.random() < 0.70:
            params["max_hold"] = rng.choice([20, 30, 40, 50, 60, 80, 100])
        if rng.random() < 0.22:
            params["atr_days"] = rng.choice([14, 20, 30, 50])
            params["atr_pct_max"] = rng.choice([0.018, 0.022, 0.026, 0.030, 0.035, 0.045])
        return Candidate(
            family="ma_cross",
            direction="long_short",
            params=tuple(sorted(params.items())),
        )

    params = {
        "entry_channel": rng.randint(15, 75),
        "exit_channel": rng.randint(15, 90),
        "qqq_ma": rng.choice([80, 100, 120, 150, 200]),
        "qqq_ma_kind": rng.choice(["sma", "ema"]),
        "benchmark_roc_days": rng.choice([40, 60, 80, 120]),
        "benchmark_roc_min": rng.choice([-0.10, -0.08, -0.04, 0.0, 0.02, 0.04]),
        "own_roc_days": rng.choice([40, 60, 80, 120]),
        "own_roc_min": rng.choice([-0.02, 0.0, 0.02, 0.04, 0.06, 0.08]),
        "relative_days": rng.choice([20, 40, 60, 80]),
        "relative_min": rng.choice([-0.02, 0.0, 0.02, 0.04, 0.06]),
        "reverse_exit": False,
    }
    if rng.random() < 0.70:
        params["exit_ma"] = rng.choice([80, 100, 120, 150, 200])
        params["exit_ma_kind"] = rng.choice(["sma", "ema"])
    if rng.random() < 0.72:
        params["fixed_stop"] = rng.choice([0.05, 0.06, 0.08, 0.10, 0.12])
    if rng.random() < 0.72:
        params["trailing_stop"] = rng.choice([0.08, 0.10, 0.12, 0.15, 0.18])
    if rng.random() < 0.78:
        params["take_profit"] = rng.choice([0.08, 0.10, 0.12, 0.15, 0.18, 0.20])
    if rng.random() < 0.65:
        params["max_hold"] = rng.choice([30, 40, 50, 60, 80, 100])
    if rng.random() < 0.16:
        params["atr_days"] = rng.choice([14, 20, 30, 50])
        params["atr_pct_max"] = rng.choice([0.022, 0.026, 0.030, 0.035, 0.045, 0.060])
    if rng.random() < 0.16:
        params["volume_window"] = rng.choice([20, 40, 60])
        params["volume_ratio_min"] = rng.choice([1.1, 1.2, 1.5, 2.0])
    if rng.random() < 0.18:
        params["benchmark_ma"] = rng.choice([80, 100, 120, 150, 200])
        params["benchmark_ma_kind"] = rng.choice(["sma", "ema"])
    if rng.random() < 0.20:
        params["relative_days"] = rng.choice([20, 40, 60, 80])
        params["relative_min"] = rng.choice([-0.06, -0.03, 0.0, 0.03])
    if rng.random() < 0.16:
        params["atr_days"] = rng.choice([14, 20, 30, 50])
        params["atr_pct_max"] = rng.choice([0.022, 0.026, 0.030, 0.035, 0.045])
    return Candidate(
        family="channel",
        direction="long_short",
        params=tuple(sorted(params.items())),
    )


def candidate_key(candidate: Candidate) -> tuple[Any, ...]:
    return (candidate.family, candidate.direction, normalized_params_tuple(dict(candidate.params)))


def normalized_params_tuple(params: dict[str, Any]) -> tuple[tuple[str, Any], ...]:
    normalized = dict(params)
    if "qqq_ma" in normalized and "qqq_ma2" in normalized:
        filters = sorted(
            [
                (normalized.get("qqq_ma_kind", "sma"), normalized["qqq_ma"]),
                (normalized.get("qqq_ma2_kind", "sma"), normalized["qqq_ma2"]),
            ]
        )
        normalized["qqq_ma_kind"], normalized["qqq_ma"] = filters[0]
        normalized["qqq_ma2_kind"], normalized["qqq_ma2"] = filters[1]
    return tuple(sorted(normalized.items()))


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
        "benchmark_roc_days": [20, 40, 60, 80, 120],
        "relative_days": [20, 40, 60, 80, 120],
        "momentum_days": [20, 40, 60, 80, 120],
        "qqq_slope_days": [20, 40, 60, 80],
        "sma_slope_days": [20, 40, 60, 80],
        "benchmark_slope_days": [20, 40, 60, 80],
        "adx_days": [14, 20, 30],
        "entry_ma": [10, 20, 30, 50, 80, 100, 120, 150, 200],
        "qqq_ma": [50, 80, 100, 120, 150, 200],
        "qqq_ma2": [50, 80, 100, 120, 150, 200],
        "benchmark_ma": [50, 80, 100, 120, 150, 200],
        "exit_ma": [20, 30, 40, 50, 80, 100, 120, 150, 200],
        "fixed_stop": [0.04, 0.05, 0.06, 0.08, 0.10, 0.12, 0.15, 0.18],
        "trailing_stop": [0.04, 0.05, 0.06, 0.08, 0.10, 0.12, 0.15, 0.18],
        "take_profit": [0.06, 0.08, 0.10, 0.12, 0.15, 0.18, 0.20, 0.24, 0.30],
        "atr_stop_mult": [1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
        "atr_trail_mult": [1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
        "volume_ratio_min": [1.1, 1.2, 1.5, 2.0],
        "realized_vol_max": [0.18, 0.22, 0.26, 0.30, 0.36, 0.45],
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
        normalized["max_hold"] = int(max(5, min(100, normalized["max_hold"])))
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
            ma = get_ma(ind, p.get("entry_ma_kind", "sma"), w, benchmark=False)
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
            ma = get_ma(ind, p.get("qqq_ma_kind", "sma"), p["qqq_ma"], benchmark=False)
            long_filter &= data.close > ma
            short_filter &= data.close < ma
        if "qqq_ma2" in p:
            ma = get_ma(ind, p.get("qqq_ma2_kind", "sma"), p["qqq_ma2"], benchmark=False)
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
        if "benchmark_ma" in p:
            ma = get_ma(ind, p.get("benchmark_ma_kind", "sma"), p["benchmark_ma"], benchmark=True)
            long_filter &= data.benchmark_close > ma
            short_filter &= data.benchmark_close < ma
        if "benchmark_roc_days" in p:
            r = ind.benchmark_roc[p["benchmark_roc_days"]]
            long_filter &= r > p.get("benchmark_roc_min", 0)
            short_filter &= r < -p.get("benchmark_roc_min", 0)
        if "benchmark_slope_days" in p:
            s = ind.benchmark_slope[p["benchmark_slope_days"]]
            long_filter &= s >= p.get("benchmark_slope_min", 0)
            short_filter &= s <= -p.get("benchmark_slope_min", 0)
        if "relative_days" in p:
            diff = ind.roc[p["relative_days"]] - ind.benchmark_roc[p["relative_days"]]
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
        if candidate.family == "ma_cross":
            if p.get("reverse_exit", False):
                exit_long[row] |= short_sig[row]
                exit_short[row] |= long_sig[row]
            else:
                exit_long[row] |= base_short
                exit_short[row] |= base_long
        elif p.get("reverse_exit", False):
            exit_long[row] |= short_sig[row]
            exit_short[row] |= long_sig[row]
        if "exit_channel" in p:
            w = p["exit_channel"]
            exit_long[row] |= data.close < ind.prior_low[w]
            exit_short[row] |= data.close > ind.prior_high[w]
        if "exit_ma" in p:
            ma = get_ma(ind, p.get("exit_ma_kind", "sma"), p["exit_ma"], benchmark=False)
            exit_long[row] |= data.close < ma
            exit_short[row] |= data.close > ma
    long_sig &= ~np.isnan(data.close)
    short_sig &= ~np.isnan(data.close)
    return long_sig, short_sig, exit_long, exit_short


def get_ma(ind: Indicators, kind: str, window: int, *, benchmark: bool) -> np.ndarray:
    if benchmark:
        return ind.benchmark_ema[window] if kind == "ema" else ind.benchmark_sma[window]
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
                    q, fee, cash = open_long_quantity(equity[row], price, position_ratio(params[row]))
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
                    q, fee = open_short_quantity(equity[row], price, position_ratio(params[row]))
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


def position_ratio(params: dict[str, Any]) -> float:
    return max(0.0, min(1.0, float(params.get("position_ratio", 1.0))))


def open_long_quantity(equity: float, price: float, ratio: float) -> tuple[float, float, float]:
    allocation = equity * ratio
    if allocation <= BROKER_MIN_COMMISSION:
        return 0.0, 0.0, equity
    q = allocation / (price * 1.003)
    fee = buy_fee(q * price)
    for _ in range(8):
        total = q * price + fee
        if total <= allocation:
            break
        q *= allocation / total
        fee = buy_fee(q * price)
    return q, fee, equity - q * price - fee


def open_short_quantity(equity: float, price: float, ratio: float) -> tuple[float, float]:
    allocation = equity * ratio
    if allocation <= BROKER_MIN_COMMISSION:
        return 0.0, 0.0
    q = allocation / (price * 1.003)
    fee = sell_fee(q * price, q)
    for _ in range(8):
        total = q * price + fee
        if total <= allocation:
            break
        q *= allocation / total
        fee = sell_fee(q * price, q)
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
    return max(notional * BROKER_COMMISSION_RATE, BROKER_MIN_COMMISSION)


def buy_fee(notional: float) -> float:
    return commission(notional) + hk_statutory_fee(notional)


def sell_fee(notional: float, quantity: float) -> float:
    return commission(notional) + hk_statutory_fee(notional)


def hk_statutory_fee(notional: float) -> float:
    ccass_fee = min(
        max(notional * HK_CCASS_SETTLEMENT_FEE_RATE, HK_CCASS_MIN),
        HK_CCASS_MAX,
    )
    return (
        notional * HK_STAMP_DUTY_RATE
        + notional * HK_SFC_TRANSACTION_LEVY_RATE
        + notional * HK_AFRC_TRANSACTION_LEVY_RATE
        + notional * HK_TRADING_FEE_RATE
        + ccass_fee
    )


def preliminary_pass(metric: dict[str, Any]) -> bool:
    return (
        metric["total_return"] >= 0.25
        and metric["max_drawdown"] >= -0.22
        and metric["win_rate"] >= 0.65
        and metric["round_trips"] >= 4
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
        and full["max_drawdown"] >= -0.18
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
        and train_2023["max_drawdown"] >= -0.18
        and train_2023["win_rate"] >= 0.80
    )
    pass_2024_train = (
        pass_2023_train
        and years["2024"]["total_return"] >= 0.10
        and years["2024"]["max_drawdown"] >= -0.20
        and train_2024["max_drawdown"] >= -0.18
        and train_2024["win_rate"] >= 0.80
    )
    pass_2025_train = (
        pass_2024_train
        and years["2025"]["total_return"] >= 0.10
        and years["2025"]["max_drawdown"] >= -0.20
        and train_2025["max_drawdown"] >= -0.18
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


def steady_prelim_sort_key(metric: dict[str, Any]) -> tuple[float, float, float, float, float]:
    return (
        -metric["max_drawdown"],
        -metric["win_rate"],
        -metric["total_return"],
        abs(metric["round_trips"] - 14),
        -metric["round_trips"],
    )


def record_sort_key(item: dict[str, Any]) -> tuple[float, float, float, float, float, float]:
    full = item.get("train_full") or item.get("full")
    years = item.get("years", {})
    train_labels = ["2022", "2023", "2024", "2025"]
    min_year = min((years.get(label, {}).get("total_return", -9) for label in train_labels), default=-9)
    std_year = np.std([years[label]["total_return"] for label in train_labels if label in years]) if years else 9
    wf = item.get("walk_forward", {})
    wf_penalty = 0 if wf.get("all_pass", False) else 1
    return (
        -full["max_drawdown"],
        wf_penalty,
        std_year,
        -min_year,
        -full["win_rate"],
        -full["total_return"],
    )


def select_top3(records: list[dict[str, Any]], require_pass: bool = True) -> list[dict[str, Any]]:
    sorted_records = sorted(records, key=record_sort_key if require_pass else closest_sort_key)
    selected: list[dict[str, Any]] = []
    families: set[str] = set()
    signatures: set[tuple[Any, ...]] = set()
    for item in sorted_records:
        family = item["candidate"].family
        signature = strategy_signature(item["candidate"])
        if family in families:
            continue
        if signature in signatures:
            continue
        selected.append(item)
        families.add(family)
        signatures.add(signature)
        if len(selected) == 3:
            return selected
    for item in sorted_records:
        signature = strategy_signature(item["candidate"])
        if item not in selected and signature not in signatures:
            selected.append(item)
            signatures.add(signature)
        if len(selected) == 3:
            break
    return selected


def closest_sort_key(item: dict[str, Any]) -> tuple[float, ...]:
    full = item.get("full") or item.get("train_full")
    years = item.get("years", {})
    labels = ["2022", "2023", "2024", "2025", "2026YTD"]
    return_shortfalls = [
        max(0.0, 0.10 - years.get(label, {}).get("total_return", -1.0))
        for label in labels
    ]
    dd_shortfalls = [
        max(0.0, -0.20 - years.get(label, {}).get("max_drawdown", -1.0))
        for label in labels
    ]
    min_year = min((years.get(label, {}).get("total_return", -1.0) for label in labels), default=-1.0)
    sample_shortfall = max(0, 10 - full["round_trips"]) / 10 if full else 1.0
    win_shortfall = max(0.0, 0.80 - full["win_rate"]) if full else 1.0
    full_dd_shortfall = max(0.0, -0.18 - full["max_drawdown"]) if full else 1.0
    return (
        float(sum(shortfall > 0 for shortfall in return_shortfalls)),
        float(sum(return_shortfalls)),
        float(sum(dd_shortfalls) + full_dd_shortfall),
        win_shortfall,
        sample_shortfall,
        -min_year,
        -full["total_return"] if full else 1.0,
        -full["max_drawdown"] if full else 1.0,
    )


def enrich_records(
    records: list[dict[str, Any]],
    data: MarketData,
    ind: Indicators,
    ranges: DateRanges,
) -> None:
    for item in records:
        if "full" not in item:
            item["full"] = evaluate_candidates(
                [item["candidate"]],
                data,
                ind,
                ranges.all_start,
                ranges.all_end,
            )[0]
        if "years" not in item:
            item["years"] = annual_metrics([item["candidate"]], data, ind, ranges)[0]
        if "walk_forward" not in item:
            item["walk_forward"] = walk_forward(item["candidate"], data, ind, ranges)


def strategy_signature(candidate: Candidate) -> tuple[Any, ...]:
    p = dict(candidate.params)
    ma_filters = tuple(
        sorted(
            (p.get(kind_key, "sma"), p[ma_key])
            for ma_key, kind_key in [("qqq_ma", "qqq_ma_kind"), ("qqq_ma2", "qqq_ma2_kind")]
            if ma_key in p
        )
    )
    risk = tuple(
        (key, p.get(key))
        for key in ["exit_ma", "exit_ma_kind", "exit_channel", "fixed_stop", "trailing_stop", "take_profit", "max_hold"]
        if key in p
    )
    if candidate.family == "ma_cross":
        own_min = p.get("own_roc_min")
        own_bucket = round(own_min / 0.02) * 0.02 if isinstance(own_min, float) else own_min
        return (
            candidate.family,
            candidate.direction,
            p.get("short_window"),
            p.get("long_window"),
            ma_filters,
            p.get("own_roc_days"),
            round(own_bucket, 4) if isinstance(own_bucket, float) else own_bucket,
            risk,
        )
    if candidate.family == "channel":
        return (
            candidate.family,
            candidate.direction,
            p.get("entry_channel"),
            p.get("exit_channel"),
            ma_filters,
            risk,
        )
    if candidate.family == "price_ma":
        return (
            candidate.family,
            candidate.direction,
            p.get("entry_ma"),
            p.get("entry_ma_kind"),
            ma_filters,
            risk,
        )
    return (
        candidate.family,
        candidate.direction,
        p.get("momentum_days"),
        p.get("momentum_long_min"),
        p.get("momentum_short_min"),
        ma_filters,
        risk,
    )


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
        "train_full": item.get("train_full"),
        "years": item.get("years", {}),
        "walk_forward": item.get("walk_forward", {}),
        "sample_warning": full["round_trips"] < 10 if full else None,
    }


def strategy_name(candidate: Candidate) -> str:
    if candidate.name:
        return candidate.name
    if candidate.family == "ma_cross":
        return f"工商银行 SMA{candidate.get('short_window')}/{candidate.get('long_window')} steady"
    if candidate.family == "channel":
        return f"工商银行 channel {candidate.get('entry_channel')}/{candidate.get('exit_channel', '-')}"
    if candidate.family == "price_ma":
        return f"工商银行 price {candidate.get('entry_ma_kind', 'sma').upper()}{candidate.get('entry_ma')}"
    return f"工商银行 ROC{candidate.get('momentum_days')} momentum"


def formula(candidate: Candidate) -> str:
    p = dict(candidate.params)
    pieces: list[str] = []
    if candidate.family == "ma_cross":
        pieces.append(f"Entry: 工商银行 SMA{p['short_window']} crosses SMA{p['long_window']}; short side symmetric.")
    elif candidate.family == "channel":
        pieces.append(f"Entry: 工商银行 close breaks prior {p['entry_channel']}d high/low.")
    elif candidate.family == "price_ma":
        pieces.append(f"Entry: 工商银行 close crosses {p.get('entry_ma_kind','sma').upper()}{p['entry_ma']}.")
    else:
        pieces.append(f"Entry: 工商银行 ROC{p['momentum_days']} > {p['momentum_long_min']:.0%}; short threshold {p['momentum_short_min']:.0%}.")
    filters: list[str] = []
    if "qqq_ma" in p:
        filters.append(f"工商银行 close above/below {p.get('qqq_ma_kind','sma').upper()}{p['qqq_ma']}")
    if "qqq_ma2" in p:
        filters.append(f"工商银行 close above/below {p.get('qqq_ma2_kind','sma').upper()}{p['qqq_ma2']}")
    if "own_roc_days" in p:
        filters.append(f"工商银行 ROC{p['own_roc_days']} > {p['own_roc_min']:.0%}")
    if "benchmark_ma" in p:
        filters.append(f"恒生指数 {p.get('benchmark_ma_kind','sma').upper()}{p['benchmark_ma']} filter")
    if "benchmark_roc_days" in p:
        filters.append(f"恒生指数 ROC{p['benchmark_roc_days']} > {p['benchmark_roc_min']:.0%}")
    if "relative_days" in p:
        filters.append(f"工商银行-恒生指数 ROC{p['relative_days']} > {p['relative_min']:.0%}")
    if "atr_days" in p and "atr_pct_max" in p:
        filters.append(f"ATR{p['atr_days']}% <= {p['atr_pct_max']:.1%}")
    if "realized_vol_days" in p:
        filters.append(f"RV{p['realized_vol_days']} <= {p['realized_vol_max']:.0%}")
    if filters:
        pieces.append("Filters: " + "; ".join(filters) + ".")
    exits: list[str] = []
    if candidate.family == "ma_cross" and not p.get("reverse_exit"):
        exits.append("raw reverse MA cross")
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
    if "atr_trail_mult" in p:
        exits.append(f"ATR trailing stop {p['atr_trail_mult']}x")
    if "max_hold" in p:
        exits.append(f"max hold {p['max_hold']}d")
    if exits:
        pieces.append("Exit: " + "; ".join(exits) + ".")
    return " ".join(pieces)


if __name__ == "__main__":
    main()



