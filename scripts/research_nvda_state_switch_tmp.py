from __future__ import annotations

import argparse
import json
import math
import random
import subprocess
import sys
import time
from datetime import date, datetime
from pathlib import Path
from typing import Any

import numpy as np

import research_amd_aggressive_tmp as engine


TARGET = "US.NVDA"
BENCHMARK = "US.QQQ"
TARGET_ALIAS = "US.AMD"
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

OUTPUT_PATH = "scripts/research_nvda_state_switch_tmp_result.json"
PROGRESS_PATH = "scripts/research_nvda_state_switch_tmp_progress.json"

ORIGINAL_SIGNAL_ARRAYS = engine.signal_arrays
ORIGINAL_NEIGHBORS = engine.neighbors
ORIGINAL_STRATEGY_SIGNATURE = engine.strategy_signature
ORIGINAL_RANDOM_CANDIDATE = engine.random_candidate
ORIGINAL_AMD_REGION_CANDIDATE = engine.random_AMD_aggressive_region_candidate
ORIGINAL_STRATEGY_NAME = engine.strategy_name
ORIGINAL_FORMULA = engine.formula

engine.END = END
engine.TRAIN_END = TRAIN_END
engine.YEARS = YEARS


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage1", type=int, default=800_000)
    parser.add_argument("--seed", type=int, default=20260608)
    parser.add_argument("--batch-size", type=int, default=768)
    parser.add_argument("--output", default=OUTPUT_PATH)
    parser.add_argument("--progress", default=PROGRESS_PATH)
    args = parser.parse_args()

    started = time.time()
    rng = random.Random(args.seed)
    patch_engine()

    write_progress(args.progress, "fetching_data", 0, args.stage1, started)
    rows = fetch_cloud_candles()
    data = engine.MarketData.from_rows(rows)
    indicators = engine.Indicators(data)
    repair_adx(indicators)
    ranges = engine.DateRanges(data.dates)
    split_report = split_adjustment_report(rows[TARGET_ALIAS])

    current_app = current_app_candidate()
    current_metrics = evaluate_candidates([current_app], data, indicators, ranges.all_start, ranges.all_end)[0]
    current_train_metrics = evaluate_candidates([current_app], data, indicators, ranges.train_start, ranges.train_end)[0]
    current_years = annual_metrics([current_app], data, indicators, ranges)[0]
    current_record = {
        "candidate": current_app,
        "full": current_metrics,
        "train_full": current_train_metrics,
        "years": current_years,
        "walk_forward": walk_forward(current_app, data, indicators, ranges),
    }
    add_trend_metrics(current_record, data, indicators, ranges)

    seen: set[tuple[Any, ...]] = {candidate_key(current_app)}
    prelim: list[dict[str, Any]] = []
    top_by_family: dict[str, list[dict[str, Any]]] = {}
    tested_by_family: dict[str, int] = {current_app.family: 1}
    prelim_by_family: dict[str, int] = {}
    tested = 1
    if preliminary_pass(current_train_metrics):
        prelim_by_family[current_app.family] = 1
        remember_family_record(top_by_family, {"candidate": current_app, "train_full": current_train_metrics})

    write_progress(args.progress, "stage1_search", tested, args.stage1, started)
    while tested < args.stage1:
        batch: list[engine.Candidate] = []
        while len(batch) < args.batch_size and tested < args.stage1:
            candidate = random_candidate(rng)
            key = candidate_key(candidate)
            if key in seen:
                continue
            seen.add(key)
            batch.append(candidate)
            tested_by_family[candidate.family] = tested_by_family.get(candidate.family, 0) + 1
            tested += 1

        metrics = evaluate_candidates(batch, data, indicators, ranges.train_start, ranges.train_end)
        for candidate, metric in zip(batch, metrics):
            if preliminary_pass(metric):
                prelim_by_family[candidate.family] = prelim_by_family.get(candidate.family, 0) + 1
                record = {"candidate": candidate, "train_full": metric}
                prelim.append(record)
                remember_family_record(top_by_family, record)

        if tested % 25_000 < args.batch_size:
            write_progress(args.progress, "stage1_search", tested, args.stage1, started)

    local_candidates = local_refine_candidates(top_by_family, rng, seen)
    local_metrics = evaluate_candidates(local_candidates, data, indicators, ranges.train_start, ranges.train_end)
    for candidate, metric in zip(local_candidates, local_metrics):
        tested += 1
        tested_by_family[candidate.family] = tested_by_family.get(candidate.family, 0) + 1
        if preliminary_pass(metric):
            prelim_by_family[candidate.family] = prelim_by_family.get(candidate.family, 0) + 1
            record = {"candidate": candidate, "train_full": metric}
            prelim.append(record)
            remember_family_record(top_by_family, record)

    write_progress(args.progress, "annual_review", tested, tested, started)
    review_pool = annual_review_pool(top_by_family)
    reviewed = annual_review(review_pool, data, indicators, ranges)
    train_pass = [item for item in reviewed if item["train_pass"]]

    write_progress(args.progress, "walk_forward", tested, tested, started)
    wf_counts = {"2024": 0, "2025": 0, "2026YTD": 0, "all": 0}
    final_records: list[dict[str, Any]] = []
    for item in train_pass:
        wf = walk_forward(item["candidate"], data, indicators, ranges)
        item["walk_forward"] = wf
        wf_counts["2024"] += int(wf["2024"]["pass"])
        wf_counts["2025"] += int(wf["2025"]["pass"])
        wf_counts["2026YTD"] += int(wf["2026YTD"]["pass"])
        wf_counts["all"] += int(wf["all_pass"])
        item["full"] = evaluate_candidates([item["candidate"]], data, indicators, ranges.all_start, ranges.all_end)[0]
        item["years"] = annual_metrics([item["candidate"]], data, indicators, ranges)[0]
        if final_pass(item):
            add_trend_metrics(item, data, indicators, ranges)
            final_records.append(item)

    final_state_switch = [item for item in final_records if item["candidate"].family == "state_switch"]
    final_no_small_tp = [item for item in final_records if avoids_small_take_profit(item["candidate"])]
    top3 = select_top3(final_records)
    top3_state_switch = select_top3(final_state_switch)
    top3_no_small_tp = select_top3(final_no_small_tp)
    closest = select_top3(reviewed if reviewed else prelim, require_pass=False)
    closest_state_switch = select_top3(
        [item for item in reviewed if item["candidate"].family == "state_switch"],
        require_pass=False,
    )
    closest_no_small_tp = select_top3(
        [item for item in reviewed if avoids_small_take_profit(item["candidate"])],
        require_pass=False,
    )
    for item in closest + closest_state_switch + closest_no_small_tp:
        if "full" not in item:
            item["full"] = evaluate_candidates([item["candidate"]], data, indicators, ranges.all_start, ranges.all_end)[0]
        if "years" not in item:
            item["years"] = annual_metrics([item["candidate"]], data, indicators, ranges)[0]
        if "walk_forward" not in item:
            item["walk_forward"] = walk_forward(item["candidate"], data, indicators, ranges)
        add_trend_metrics(item, data, indicators, ranges)

    output = {
        "meta": {
            "target": TARGET,
            "benchmark": BENCHMARK,
            "range": f"{START.isoformat()}~{END.isoformat()}",
            "seed": args.seed,
            "started_at": datetime.now().isoformat(timespec="seconds"),
            "elapsed_seconds": round(time.time() - started, 2),
            "cost_model": {
                "initial_cash": engine.INITIAL_CASH,
                "slippage_single_side": engine.SLIPPAGE,
                "commission_rate": engine.US_COMMISSION_RATE,
                "min_commission": engine.US_MIN_COMMISSION,
                "sec_fee_rate": engine.US_SEC_FEE_RATE,
                "taf_rate_per_share": engine.US_TAF_RATE_PER_SHARE,
                "taf_max": engine.US_TAF_MAX,
            },
            "execution": "Signal at T close, execution at T+1 open with slippage; final close forced at interval end.",
            "selection_rule": "2026YTD is used only as final validation; ranking uses 2021-2025 training metrics and train trend-capture penalties.",
            "no_future_function": True,
            "split_adjustment": split_report,
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
            "final_pass": len(final_records),
            "final_state_switch": len(final_state_switch),
            "final_no_small_take_profit": len(final_no_small_tp),
            "tested_by_family": dict(sorted(tested_by_family.items())),
            "preliminary_pass_by_family": dict(sorted(prelim_by_family.items())),
        },
        "current_app": serialize_record(current_record),
        "top3": [serialize_record(item) for item in top3],
        "top3_state_switch": [serialize_record(item) for item in top3_state_switch],
        "top3_no_small_take_profit": [serialize_record(item) for item in top3_no_small_tp],
        "closest": [serialize_record(item) for item in closest],
        "closest_state_switch": [serialize_record(item) for item in closest_state_switch],
        "closest_no_small_take_profit": [serialize_record(item) for item in closest_no_small_tp],
    }
    Path(args.output).write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    write_progress(args.progress, "done", tested, tested, started)
    print(json.dumps(output["counts"], ensure_ascii=False, indent=2))


def patch_engine() -> None:
    engine.fetch_cloud_candles = fetch_cloud_candles
    engine.current_app_candidate = current_app_candidate
    engine.random_candidate = random_candidate
    engine.evaluate_candidates = evaluate_candidates
    engine.annual_metrics = annual_metrics
    engine.annual_review = annual_review
    engine.train_constraint_pass = train_constraint_pass
    engine.walk_forward = walk_forward
    engine.final_pass = lambda item, max_drawdown_limit=0.20: final_pass(item)
    engine.strategy_name = strategy_name
    engine.formula = formula
    engine.strategy_signature = strategy_signature


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


def repair_adx(ind: engine.Indicators) -> None:
    for window in [14, 20, 30]:
        plus = ind.plus_di[window]
        minus = ind.minus_di[window]
        denom = plus + minus
        dx = np.where(denom > 0, 100 * np.abs(plus - minus) / denom, np.nan)
        ind.adx[window] = rolling_nanmean(dx, window)


def rolling_nanmean(values: np.ndarray, window: int) -> np.ndarray:
    out = np.full(len(values), np.nan)
    valid = ~np.isnan(values)
    filled = np.where(valid, values, 0.0)
    cumsum = np.cumsum(np.insert(filled, 0, 0.0))
    counts = np.cumsum(np.insert(valid.astype(float), 0, 0.0))
    sums = cumsum[window:] - cumsum[:-window]
    sample_counts = counts[window:] - counts[:-window]
    mask = sample_counts > 0
    out[window - 1 :][mask] = sums[mask] / sample_counts[mask]
    return out


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
for code in ['{TARGET}', '{BENCHMARK}']:
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
    rows = json.loads(result.stdout)
    return {TARGET_ALIAS: rows[TARGET], BENCHMARK: rows[BENCHMARK]}


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
        "known_events": [
            "NVDA 4-for-1 split effective 2021-07-20",
            "NVDA 10-for-1 split effective 2024-06-10",
        ],
        "large_gap_count": len(large_gaps),
        "large_gaps": large_gaps[:5],
        "handling": (
            "Cloud OHLC series appears continuously adjusted; no second split adjustment was applied."
            if not large_gaps
            else "Large split-like gaps were detected; review raw data before using this result."
        ),
    }


def current_app_candidate() -> engine.Candidate:
    return engine.Candidate(
        family="channel",
        direction="long_short",
        name="current_app_nvda_channel15_atr",
        params=tuple(
            sorted(
                {
                    "entry_channel": 15,
                    "exit_channel": 57,
                    "qqq_ma": 80,
                    "qqq_ma_kind": "ema",
                    "benchmark_roc_days": 60,
                    "benchmark_roc_min": 0.02,
                    "own_roc_days": 80,
                    "own_roc_min": -0.08,
                    "relative_days": 80,
                    "relative_min": 0.0,
                    "qqq_slope_days": 20,
                    "qqq_slope_min": 0.0015,
                    "benchmark_slope_days": 20,
                    "benchmark_slope_min": 0.0005,
                    "atr_days": 50,
                    "atr_pct_min": 0.01,
                    "atr_pct_max": 0.06,
                    "volume_window": 20,
                    "volume_ratio_min": 0.8,
                    "exit_ma": 40,
                    "exit_ma_kind": "sma",
                    "fixed_stop": 0.20,
                    "trailing_stop": 0.24,
                    "take_profit": 0.20,
                    "atr_stop_mult": 2.0,
                    "atr_trail_mult": 4.0,
                    "max_hold": 20,
                    "reverse_exit": False,
                }.items()
            )
        ),
    )


def random_candidate(rng: random.Random) -> engine.Candidate:
    if rng.random() < 0.62:
        return random_state_switch_candidate(rng)
    candidate = (
        ORIGINAL_AMD_REGION_CANDIDATE(rng)
        if rng.random() < 0.55
        else ORIGINAL_RANDOM_CANDIDATE(rng)
    )
    return rename_amd_candidate(candidate)


def random_state_switch_candidate(rng: random.Random) -> engine.Candidate:
    params: dict[str, Any] = {
        "up_ma": rng.choice([50, 80, 100, 120, 150, 200]),
        "up_ma_kind": rng.choice(["sma", "ema"]),
        "up_slope_days": rng.choice([20, 40, 60, 80]),
        "up_slope_min": rng.choice([0.0, 0.0003, 0.0005, 0.0010, 0.0015, 0.0020]),
        "up_roc_days": rng.choice([20, 40, 60, 80, 120]),
        "up_roc_min": rng.choice([-0.10, -0.06, -0.03, 0.0, 0.03, 0.06, 0.10, 0.15]),
        "up_adx_days": rng.choice([14, 20, 30]),
        "up_adx_min": rng.choice([15, 18, 20, 25, 30]),
        "up_di_confirm": rng.choice([False, True]),
        "down_ma": rng.choice([50, 80, 100, 120, 150, 200]),
        "down_slope_days": rng.choice([20, 40, 60, 80]),
        "down_roc_days": rng.choice([20, 40, 60, 80, 120]),
        "range_adx_days": rng.choice([14, 20, 30]),
        "range_adx_max": rng.choice([15, 18, 20, 25]),
        "range_slope_days": rng.choice([20, 40, 60, 80]),
        "range_slope_abs_max": rng.choice([0.0005, 0.0010, 0.0015, 0.0020, 0.0030]),
        "range_roc_days": rng.choice([20, 40, 60]),
        "range_roc_abs_max": rng.choice([0.03, 0.06, 0.10, 0.15]),
        "trend_entry": rng.choice(["regime", "regime", "channel", "price_ma", "ma_cross", "momentum"]),
        "trend_entry_channel": rng.randint(5, 100),
        "trend_entry_ma": rng.choice([10, 20, 30, 40, 50, 80, 100, 120]),
        "trend_entry_ma_kind": rng.choice(["sma", "ema"]),
        "trend_short_window": rng.randint(5, 35),
        "trend_long_window": rng.randint(40, 180),
        "trend_momentum_days": rng.choice([20, 40, 60, 80, 120]),
        "trend_momentum_min": rng.choice([-0.05, 0.0, 0.03, 0.06, 0.10, 0.15]),
        "trend_exit_ma": rng.choice([20, 30, 40, 50, 80, 100]),
        "trend_exit_ma_kind": rng.choice(["sma", "ema"]),
        "atr_days": rng.choice([10, 14, 20, 30, 50]),
        "trend_atr_trail_mult": rng.choice([2.0, 2.5, 3.0, 3.5, 4.0, 5.0]),
        "trend_atr_stop_mult": rng.choice([1.5, 2.0, 2.5, 3.0, 3.5]),
        "range_entry": rng.choice(["none", "price_ma", "channel", "momentum"]),
        "range_entry_ma": rng.choice([10, 20, 30, 40, 50]),
        "range_entry_ma_kind": rng.choice(["sma", "ema"]),
        "range_channel": rng.randint(5, 60),
        "range_momentum_days": rng.choice([20, 40, 60]),
        "range_momentum_min": rng.choice([-0.06, -0.03, 0.0, 0.03, 0.06]),
        "range_exit_ma": rng.choice([20, 30, 40, 50, 80]),
        "range_exit_ma_kind": rng.choice(["sma", "ema"]),
        "range_fixed_stop": rng.choice([0.06, 0.08, 0.10, 0.12, 0.15, 0.18]),
        "range_take_profit": rng.choice([0.08, 0.10, 0.12, 0.16, 0.20, 0.24, 0.30, 0.40]),
        "range_max_hold": rng.choice([10, 20, 30, 40, 60, 80]),
        "allow_short": rng.choice([False, True]),
        "short_channel": rng.randint(10, 100),
        "short_fixed_stop": rng.choice([0.08, 0.10, 0.12, 0.15, 0.18, 0.20]),
        "short_take_profit": rng.choice([0.08, 0.10, 0.12, 0.16, 0.20, 0.24, 0.30]),
        "short_max_hold": rng.choice([10, 20, 30, 40, 60, 80]),
    }
    if params["trend_short_window"] >= params["trend_long_window"]:
        params["trend_long_window"] = min(220, params["trend_short_window"] + 40)
    if rng.random() < 0.35:
        params["benchmark_ma"] = rng.choice([50, 80, 100, 120, 150, 200])
        params["benchmark_ma_kind"] = rng.choice(["sma", "ema"])
    if rng.random() < 0.45:
        params["benchmark_roc_days"] = rng.choice([20, 40, 60, 80, 120])
        params["benchmark_roc_min"] = rng.choice([-0.08, -0.04, 0.0, 0.02, 0.04, 0.06])
    if rng.random() < 0.35:
        params["relative_days"] = rng.choice([20, 40, 60, 80, 120])
        params["relative_min"] = rng.choice([-0.08, -0.04, 0.0, 0.03, 0.06, 0.10])
    if rng.random() < 0.35:
        params["hv_atr_days"] = rng.choice([10, 14, 20, 30, 50])
        params["hv_atr_pct_max"] = rng.choice([0.045, 0.055, 0.065, 0.08, 0.10, 0.12])
    if rng.random() < 0.20:
        params["hv_rv_days"] = rng.choice([20, 40, 60])
        params["hv_rv_max"] = rng.choice([0.45, 0.55, 0.65, 0.80, 1.00])
    if rng.random() < 0.35:
        params["trend_max_hold"] = rng.choice([120, 180, 240])
    if rng.random() < 0.18:
        params["trend_take_profit"] = rng.choice([0.40, 0.60])
    return engine.Candidate("state_switch", "long_short", tuple(sorted(params.items())))


def rename_amd_candidate(candidate: engine.Candidate) -> engine.Candidate:
    return engine.Candidate(
        family=candidate.family,
        direction=candidate.direction,
        params=candidate.params,
        name=candidate.name.replace("AMD", "NVDA") if candidate.name else "",
    )


def candidate_key(candidate: engine.Candidate) -> tuple[Any, ...]:
    return (candidate.family, candidate.direction, tuple(sorted(dict(candidate.params).items())))


def local_refine_candidates(
    top_by_family: dict[str, list[dict[str, Any]]],
    rng: random.Random,
    seen: set[tuple[Any, ...]],
) -> list[engine.Candidate]:
    candidates: list[engine.Candidate] = []
    for records in top_by_family.values():
        for item in records[:10]:
            for variant in neighbors(item["candidate"], rng):
                key = candidate_key(variant)
                if key in seen:
                    continue
                seen.add(key)
                candidates.append(variant)
    return candidates


def neighbors(base: engine.Candidate, rng: random.Random) -> list[engine.Candidate]:
    if base.family != "state_switch":
        return ORIGINAL_NEIGHBORS(base, rng)
    params = dict(base.params)
    variants: list[engine.Candidate] = []
    for _ in range(80):
        p = dict(params)
        keys = list(p.keys())
        for key in rng.sample(keys, k=min(len(keys), rng.randint(1, 5))):
            value = p[key]
            if isinstance(value, bool):
                p[key] = not value
            elif isinstance(value, int):
                if "channel" in key or "window" in key or "days" in key or "hold" in key or "ma" in key:
                    p[key] = int(max(5, min(240, value + rng.choice([-8, -5, -3, -1, 1, 3, 5, 8]))))
            elif isinstance(value, float):
                p[key] = round(max(-0.20, min(1.20, value + rng.choice([-0.03, -0.02, -0.01, 0.01, 0.02, 0.03]))), 4)
            elif isinstance(value, str) and key.endswith("_kind"):
                p[key] = "ema" if value == "sma" else "sma"
        p = normalize_state_params(p)
        variants.append(engine.Candidate("state_switch", base.direction, tuple(sorted(p.items()))))
    return variants


def normalize_state_params(params: dict[str, Any]) -> dict[str, Any]:
    p = dict(params)
    ma_values = [10, 20, 30, 40, 50, 80, 100, 120, 150, 200]
    for key in ["up_ma", "down_ma", "trend_entry_ma", "trend_exit_ma", "range_entry_ma", "range_exit_ma", "benchmark_ma"]:
        if key in p:
            p[key] = min(ma_values, key=lambda item: abs(item - int(p[key])))
    for key in ["up_slope_days", "down_slope_days", "range_slope_days"]:
        if key in p:
            p[key] = min([20, 40, 60, 80], key=lambda item: abs(item - int(p[key])))
    for key in ["up_roc_days", "down_roc_days", "range_roc_days", "trend_momentum_days", "range_momentum_days", "benchmark_roc_days", "relative_days"]:
        if key in p:
            p[key] = min([20, 40, 60, 80, 120], key=lambda item: abs(item - int(p[key])))
    for key in ["up_adx_days", "range_adx_days"]:
        if key in p:
            p[key] = min([14, 20, 30], key=lambda item: abs(item - int(p[key])))
    for key in ["atr_days", "hv_atr_days"]:
        if key in p:
            p[key] = min([10, 14, 20, 30, 50], key=lambda item: abs(item - int(p[key])))
    for key in ["hv_rv_days"]:
        if key in p:
            p[key] = min([20, 40, 60], key=lambda item: abs(item - int(p[key])))
    for key in ["trend_entry_channel", "range_channel", "short_channel"]:
        if key in p:
            p[key] = int(max(5, min(100, p[key])))
    if p.get("trend_short_window", 5) >= p.get("trend_long_window", 40):
        p["trend_long_window"] = min(220, p["trend_short_window"] + 20)
    return p


def signal_arrays(
    candidates: list[engine.Candidate],
    data: engine.MarketData,
    ind: engine.Indicators,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    n = len(data.close)
    b = len(candidates)
    long_sig = np.zeros((b, n), dtype=bool)
    short_sig = np.zeros((b, n), dtype=bool)
    exit_long = np.zeros((b, n), dtype=bool)
    exit_short = np.zeros((b, n), dtype=bool)
    mode = np.zeros((b, n), dtype=np.int8)

    non_state: list[engine.Candidate] = []
    non_state_rows: list[int] = []
    for row, candidate in enumerate(candidates):
        if candidate.family == "state_switch":
            ls, ss, el, es, m = state_switch_arrays(candidate, data, ind)
            long_sig[row] = ls
            short_sig[row] = ss
            exit_long[row] = el
            exit_short[row] = es
            mode[row] = m
        else:
            non_state.append(candidate)
            non_state_rows.append(row)

    if non_state:
        ls, ss, el, es = ORIGINAL_SIGNAL_ARRAYS(non_state, data, ind)
        for offset, row in enumerate(non_state_rows):
            long_sig[row] = ls[offset]
            short_sig[row] = ss[offset]
            exit_long[row] = el[offset]
            exit_short[row] = es[offset]
    return long_sig, short_sig, exit_long, exit_short, mode


def state_switch_arrays(
    candidate: engine.Candidate,
    data: engine.MarketData,
    ind: engine.Indicators,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    p = dict(candidate.params)
    up, sideways, down, high_vol = regime_arrays(candidate, data, ind)
    trend_entry = entry_condition("trend", p, data, ind, long=True)
    range_entry = entry_condition("range", p, data, ind, long=True)
    short_entry = data.close < ind.prior_low[p["short_channel"]]
    long_sig = ((up & trend_entry) | (sideways & range_entry)) & ~high_vol
    short_sig = down & short_entry & p.get("allow_short", False) & ~high_vol
    trend_exit_ma = engine.get_ma(ind, p.get("trend_exit_ma_kind", "sma"), p["trend_exit_ma"], benchmark=False)
    range_exit_ma = engine.get_ma(ind, p.get("range_exit_ma_kind", "sma"), p["range_exit_ma"], benchmark=False)
    exit_long = (data.close < trend_exit_ma) | (sideways & (data.close < range_exit_ma)) | down
    exit_short = (~down) | (data.close > trend_exit_ma)
    mode = np.zeros(len(data.close), dtype=np.int8)
    mode[up] = 1
    mode[sideways] = 2
    mode[down] = -1
    mode[high_vol] = 3
    return long_sig, short_sig, exit_long, exit_short, mode


def regime_arrays(
    candidate: engine.Candidate,
    data: engine.MarketData,
    ind: engine.Indicators,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    p = dict(candidate.params)
    n = len(data.close)
    high_vol = np.zeros(n, dtype=bool)
    if "hv_atr_days" in p:
        high_vol |= ind.atr_pct[p["hv_atr_days"]] > p["hv_atr_pct_max"]
    if "hv_rv_days" in p:
        high_vol |= ind.realized_vol[p["hv_rv_days"]] > p["hv_rv_max"]

    up_ma = engine.get_ma(ind, p.get("up_ma_kind", "sma"), p["up_ma"], benchmark=False)
    up = data.close > up_ma
    up &= ind.slope[p["up_slope_days"]] >= p["up_slope_min"]
    up &= ind.roc[p["up_roc_days"]] >= p["up_roc_min"]
    up &= ind.adx[p["up_adx_days"]] >= p["up_adx_min"]
    if p.get("up_di_confirm"):
        up &= ind.plus_di[p["up_adx_days"]] > ind.minus_di[p["up_adx_days"]]
    if "benchmark_ma" in p:
        bma = engine.get_ma(ind, p.get("benchmark_ma_kind", "sma"), p["benchmark_ma"], benchmark=True)
        up &= data.benchmark_close > bma
    if "benchmark_roc_days" in p:
        up &= ind.benchmark_roc[p["benchmark_roc_days"]] >= p["benchmark_roc_min"]
    if "relative_days" in p:
        up &= (ind.roc[p["relative_days"]] - ind.benchmark_roc[p["relative_days"]]) >= p["relative_min"]

    down_ma = engine.get_ma(ind, "sma", p["down_ma"], benchmark=False)
    down = data.close < down_ma
    down &= ind.slope[p["down_slope_days"]] <= -max(0.0003, p["up_slope_min"])
    down &= ind.roc[p["down_roc_days"]] <= -0.03
    down &= ind.minus_di[p["up_adx_days"]] > ind.plus_di[p["up_adx_days"]]
    if "benchmark_ma" in p:
        bma = engine.get_ma(ind, p.get("benchmark_ma_kind", "sma"), p["benchmark_ma"], benchmark=True)
        down &= data.benchmark_close < bma

    sideways = ~up & ~down
    sideways &= ind.adx[p["range_adx_days"]] <= p["range_adx_max"]
    sideways &= np.abs(ind.slope[p["range_slope_days"]]) <= p["range_slope_abs_max"]
    sideways &= np.abs(ind.roc[p["range_roc_days"]]) <= p["range_roc_abs_max"]
    sideways &= ~high_vol
    return up, sideways, down, high_vol


def entry_condition(
    prefix: str,
    p: dict[str, Any],
    data: engine.MarketData,
    ind: engine.Indicators,
    *,
    long: bool,
) -> np.ndarray:
    mode = p[f"{prefix}_entry"]
    if mode == "none":
        return np.zeros(len(data.close), dtype=bool)
    if mode == "regime":
        return np.ones(len(data.close), dtype=bool)
    if mode == "channel":
        w = p[f"{prefix}_entry_channel"] if prefix == "trend" else p["range_channel"]
        return data.close > ind.prior_high[w] if long else data.close < ind.prior_low[w]
    if mode == "price_ma":
        w = p[f"{prefix}_entry_ma"]
        kind = p.get(f"{prefix}_entry_ma_kind", "sma")
        ma = engine.get_ma(ind, kind, w, benchmark=False)
        return (data.close > ma) & (np.r_[False, data.close[:-1] <= ma[:-1]])
    if mode == "ma_cross":
        s = ind.sma[p["trend_short_window"]]
        l = ind.sma[p["trend_long_window"]]
        return (s > l) & (np.r_[False, s[:-1] <= l[:-1]])
    days = p[f"{prefix}_momentum_days"]
    threshold = p[f"{prefix}_momentum_min"]
    return ind.roc[days] >= threshold


def evaluate_candidates(
    candidates: list[engine.Candidate],
    data: engine.MarketData,
    ind: engine.Indicators,
    start_idx: int,
    end_idx: int,
) -> list[dict[str, Any]]:
    if not candidates:
        return []
    long_sig, short_sig, exit_long_sig, exit_short_sig, modes = signal_arrays(candidates, data, ind)
    b = len(candidates)
    equity = np.full(b, engine.INITIAL_CASH, dtype=float)
    peak = equity.copy()
    max_dd = np.zeros(b, dtype=float)
    position = np.zeros(b, dtype=np.int8)
    entry_mode = np.zeros(b, dtype=np.int8)
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
    losses = np.zeros(b, dtype=np.int16)
    long_count = np.zeros(b, dtype=np.int16)
    short_count = np.zeros(b, dtype=np.int16)
    fees = np.zeros(b, dtype=float)
    gross_profit = np.zeros(b, dtype=float)
    gross_loss = np.zeros(b, dtype=float)
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
            exit_mask |= (position == 1) & exit_long_sig[:, sig]
            exit_mask |= (position == -1) & exit_short_sig[:, sig]
            for row, p in enumerate(params):
                if position[row] == 0:
                    continue
                if candidates[row].family == "state_switch":
                    exit_mask[row] |= state_risk_exit(
                        p,
                        int(position[row]),
                        int(entry_mode[row]),
                        close_sig,
                        entry_price[row],
                        high_since[row],
                        low_since[row],
                        highest_close[row],
                        lowest_close[row],
                        int(hold_days[row]),
                        ind,
                        sig,
                    )
                else:
                    exit_mask[row] |= generic_risk_exit(
                        p,
                        int(position[row]),
                        close_sig,
                        entry_price[row],
                        high_since[row],
                        low_since[row],
                        highest_close[row],
                        lowest_close[row],
                        int(hold_days[row]),
                        ind,
                        sig,
                    )

            if np.any(exit_mask):
                for row in np.flatnonzero(exit_mask):
                    next_equity, fee = engine.close_position(
                        equity[row],
                        int(position[row]),
                        qty[row],
                        entry_price[row],
                        entry_equity[row],
                        entry_cash[row],
                        open_price,
                        already_slipped=False,
                    )
                    pnl = next_equity - entry_equity[row]
                    if pnl > 0:
                        gross_profit[row] += pnl
                        wins[row] += 1
                    else:
                        gross_loss[row] += -pnl
                        losses[row] += 1
                    equity[row] = next_equity
                    fees[row] += fee
                    rounds[row] += 1
                    position[row] = 0
                    entry_mode[row] = 0
                    qty[row] = 0

            flat = position == 0
            enter_long = flat & long_sig[:, sig]
            enter_short = flat & short_sig[:, sig] & ~enter_long
            if np.any(enter_long):
                for row in np.flatnonzero(enter_long):
                    price = open_price * (1 + engine.SLIPPAGE)
                    q, fee, cash = engine.open_long_quantity(equity[row], price)
                    if q > 0:
                        entry_equity[row] = equity[row]
                        equity[row] = cash + q * data.close[idx]
                        fees[row] += fee
                        position[row] = 1
                        entry_mode[row] = int(modes[row, sig]) if candidates[row].family == "state_switch" else 0
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
                    price = open_price * (1 - engine.SLIPPAGE)
                    q, fee = engine.open_short_quantity(equity[row], price)
                    if q > 0:
                        entry_equity[row] = equity[row]
                        entry_cash[row] = equity[row] - fee
                        equity[row] = entry_cash[row] + q * (price - data.close[idx])
                        fees[row] += fee
                        position[row] = -1
                        entry_mode[row] = -1
                        qty[row] = q
                        entry_price[row] = price
                        high_since[row] = data.high[sig]
                        low_since[row] = data.low[sig]
                        highest_close[row] = data.close[sig]
                        lowest_close[row] = data.close[sig]
                        hold_days[row] = 0
                        short_count[row] += 1

        equity = engine.mark_equity(equity, position, qty, entry_price, entry_cash, data.close[idx])
        peak = np.maximum(peak, equity)
        max_dd = np.minimum(max_dd, equity / peak - 1)

    force_mask = position != 0
    if np.any(force_mask):
        close_price = data.close[end_idx]
        for row in np.flatnonzero(force_mask):
            next_equity, fee = engine.close_position(
                equity[row],
                int(position[row]),
                qty[row],
                entry_price[row],
                entry_equity[row],
                entry_cash[row],
                close_price,
                already_slipped=False,
            )
            pnl = next_equity - entry_equity[row]
            if pnl > 0:
                gross_profit[row] += pnl
                wins[row] += 1
            else:
                gross_loss[row] += -pnl
                losses[row] += 1
            equity[row] = next_equity
            fees[row] += fee
            rounds[row] += 1
            position[row] = 0

    return [
        {
            "total_return": float(equity[row] / engine.INITIAL_CASH - 1),
            "max_drawdown": float(max_dd[row]),
            "win_rate": float(wins[row] / rounds[row]) if rounds[row] else 0.0,
            "round_trips": int(rounds[row]),
            "long_count": int(long_count[row]),
            "short_count": int(short_count[row]),
            "total_fees": float(fees[row]),
            "profit_factor": float(gross_profit[row] / gross_loss[row]) if gross_loss[row] > 0 else (999.0 if gross_profit[row] > 0 else 0.0),
            "payoff_ratio": float((gross_profit[row] / wins[row]) / (gross_loss[row] / losses[row])) if wins[row] and losses[row] and gross_loss[row] > 0 else 0.0,
        }
        for row in range(b)
    ]


def generic_risk_exit(
    p: dict[str, Any],
    side: int,
    close_sig: float,
    entry_price: float,
    high_since: float,
    low_since: float,
    highest_close: float,
    lowest_close: float,
    hold_days: int,
    ind: engine.Indicators,
    sig: int,
) -> bool:
    if "fixed_stop" in p:
        if side == 1 and close_sig <= entry_price * (1 - p["fixed_stop"]):
            return True
        if side == -1 and close_sig >= entry_price * (1 + p["fixed_stop"]):
            return True
    if "trailing_stop" in p:
        if side == 1 and close_sig <= high_since * (1 - p["trailing_stop"]):
            return True
        if side == -1 and close_sig >= low_since * (1 + p["trailing_stop"]):
            return True
    if "take_profit" in p:
        if side == 1 and close_sig >= entry_price * (1 + p["take_profit"]):
            return True
        if side == -1 and close_sig <= entry_price * (1 - p["take_profit"]):
            return True
    if "atr_days" in p:
        atr_value = ind.atr[p["atr_days"]][sig]
        if not np.isnan(atr_value):
            if "atr_stop_mult" in p:
                if side == 1 and close_sig <= entry_price - p["atr_stop_mult"] * atr_value:
                    return True
                if side == -1 and close_sig >= entry_price + p["atr_stop_mult"] * atr_value:
                    return True
            if "atr_trail_mult" in p:
                if side == 1 and close_sig <= highest_close - p["atr_trail_mult"] * atr_value:
                    return True
                if side == -1 and close_sig >= lowest_close + p["atr_trail_mult"] * atr_value:
                    return True
    return "max_hold" in p and hold_days >= p["max_hold"]


def state_risk_exit(
    p: dict[str, Any],
    side: int,
    mode: int,
    close_sig: float,
    entry_price: float,
    high_since: float,
    low_since: float,
    highest_close: float,
    lowest_close: float,
    hold_days: int,
    ind: engine.Indicators,
    sig: int,
) -> bool:
    atr_value = ind.atr[p["atr_days"]][sig]
    if side == 1 and mode == 1:
        if not np.isnan(atr_value):
            if close_sig <= entry_price - p["trend_atr_stop_mult"] * atr_value:
                return True
            if close_sig <= highest_close - p["trend_atr_trail_mult"] * atr_value:
                return True
        if "trend_take_profit" in p and close_sig >= entry_price * (1 + p["trend_take_profit"]):
            return True
        return "trend_max_hold" in p and hold_days >= p["trend_max_hold"]
    if side == 1:
        if close_sig <= entry_price * (1 - p["range_fixed_stop"]):
            return True
        if close_sig >= entry_price * (1 + p["range_take_profit"]):
            return True
        return hold_days >= p["range_max_hold"]
    if side == -1:
        if close_sig >= entry_price * (1 + p["short_fixed_stop"]):
            return True
        if close_sig <= entry_price * (1 - p["short_take_profit"]):
            return True
        return hold_days >= p["short_max_hold"]
    return False


def preliminary_pass(metric: dict[str, Any]) -> bool:
    return (
        metric["total_return"] >= 0.35
        and metric["max_drawdown"] >= -0.26
        and metric["round_trips"] >= 5
        and metric["win_rate"] >= 0.45
        and metric["profit_factor"] >= 1.15
    )


def preliminary_sort_key(metric: dict[str, Any]) -> tuple[float, ...]:
    return (
        -metric["total_return"],
        -metric["profit_factor"],
        -metric["max_drawdown"],
        abs(metric["round_trips"] - 18),
        -metric["win_rate"],
    )


def remember_family_record(top_by_family: dict[str, list[dict[str, Any]]], record: dict[str, Any]) -> None:
    family = record["candidate"].family
    family_records = top_by_family.setdefault(family, [])
    family_records.append(record)
    family_records.sort(key=lambda item: preliminary_sort_key(item["train_full"]))
    limit = 1500 if family == "state_switch" else 800
    del family_records[limit:]


def annual_review_pool(top_by_family: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    pool: dict[tuple[Any, ...], dict[str, Any]] = {}
    for records in top_by_family.values():
        for record in records:
            pool[candidate_key(record["candidate"])] = record
    return list(pool.values())


def annual_metrics(
    candidates: list[engine.Candidate],
    data: engine.MarketData,
    ind: engine.Indicators,
    ranges: engine.DateRanges,
) -> list[dict[str, dict[str, Any]]]:
    result = [dict() for _ in candidates]
    for label, (start_idx, end_idx) in ranges.periods.items():
        metrics = evaluate_candidates(candidates, data, ind, start_idx, end_idx)
        for row, metric in enumerate(metrics):
            result[row][label] = metric
    return result


def annual_review(
    prelim: list[dict[str, Any]],
    data: engine.MarketData,
    ind: engine.Indicators,
    ranges: engine.DateRanges,
) -> list[dict[str, Any]]:
    reviewed: list[dict[str, Any]] = []
    batch_size = 384
    for offset in range(0, len(prelim), batch_size):
        items = prelim[offset : offset + batch_size]
        candidates = [item["candidate"] for item in items]
        years = annual_metrics(candidates, data, ind, ranges)
        train_full = evaluate_candidates(candidates, data, ind, ranges.train_start, ranges.train_end)
        for item, year_metrics, full in zip(items, years, train_full):
            train_pass = train_constraint_pass(year_metrics, full, include_2026=False)
            reviewed.append({**item, "years": year_metrics, "train_full": full, "train_pass": train_pass})
    return reviewed


def train_constraint_pass(
    years: dict[str, dict[str, Any]],
    full: dict[str, Any],
    *,
    include_2026: bool,
) -> bool:
    labels = ["2022", "2023", "2024", "2025"] + (["2026YTD"] if include_2026 else [])
    return (
        all(years[label]["total_return"] >= 0.10 for label in labels)
        and all(years[label]["max_drawdown"] >= -0.20 for label in labels)
        and full["max_drawdown"] >= -0.20
        and full["round_trips"] >= 8
        and full["win_rate"] >= 0.55
        and (full["profit_factor"] >= 1.50 or full["payoff_ratio"] >= 1.50)
    )


def walk_forward(
    candidate: engine.Candidate,
    data: engine.MarketData,
    ind: engine.Indicators,
    ranges: engine.DateRanges,
) -> dict[str, Any]:
    years = annual_metrics([candidate], data, ind, ranges)[0]
    train_2023 = evaluate_candidates([candidate], data, ind, *ranges.wf_train_2023)[0]
    train_2024 = evaluate_candidates([candidate], data, ind, *ranges.wf_train_2024)[0]
    train_2025 = evaluate_candidates([candidate], data, ind, *ranges.wf_train_2025)[0]
    pass_2023_train = (
        years["2022"]["total_return"] >= 0.10
        and years["2023"]["total_return"] >= 0.10
        and years["2022"]["max_drawdown"] >= -0.20
        and years["2023"]["max_drawdown"] >= -0.20
        and train_2023["max_drawdown"] >= -0.20
        and train_2023["round_trips"] >= 4
        and train_2023["win_rate"] >= 0.50
        and train_2023["profit_factor"] >= 1.25
    )
    pass_2024_train = (
        pass_2023_train
        and years["2024"]["total_return"] >= 0.10
        and years["2024"]["max_drawdown"] >= -0.20
        and train_2024["max_drawdown"] >= -0.20
        and train_2024["win_rate"] >= 0.52
        and train_2024["profit_factor"] >= 1.35
    )
    pass_2025_train = (
        pass_2024_train
        and years["2025"]["total_return"] >= 0.10
        and years["2025"]["max_drawdown"] >= -0.20
        and train_2025["max_drawdown"] >= -0.20
        and train_2025["win_rate"] >= 0.55
        and train_2025["profit_factor"] >= 1.50
    )
    wf2024 = pass_2023_train and years["2024"]["total_return"] >= 0.10 and years["2024"]["max_drawdown"] >= -0.20
    wf2025 = pass_2024_train and years["2025"]["total_return"] >= 0.10 and years["2025"]["max_drawdown"] >= -0.20
    wf2026 = pass_2025_train and years["2026YTD"]["total_return"] >= 0.10 and years["2026YTD"]["max_drawdown"] >= -0.20
    return {
        "2024": {"pass": bool(wf2024), **years["2024"]},
        "2025": {"pass": bool(wf2025), **years["2025"]},
        "2026YTD": {"pass": bool(wf2026), **years["2026YTD"]},
        "all_pass": bool(wf2024 and wf2025 and wf2026),
    }


def final_pass(item: dict[str, Any]) -> bool:
    full = item.get("full")
    years = item.get("years")
    wf = item.get("walk_forward", {})
    if full is None or years is None:
        return False
    return (
        wf.get("all_pass", False)
        and all(years[label]["total_return"] >= 0.10 for label in ["2022", "2023", "2024", "2025", "2026YTD"])
        and all(years[label]["max_drawdown"] >= -0.20 for label in ["2022", "2023", "2024", "2025", "2026YTD"])
        and full["max_drawdown"] >= -0.20
        and full["round_trips"] >= 10
        and full["win_rate"] >= 0.55
        and (full["profit_factor"] >= 1.50 or full["payoff_ratio"] >= 1.50)
    )


def add_trend_metrics(
    item: dict[str, Any],
    data: engine.MarketData,
    ind: engine.Indicators,
    ranges: engine.DateRanges,
) -> None:
    item["trend_train"] = trend_capture_analysis(item["candidate"], data, ind, ranges.train_start, ranges.train_end)
    item["trend_full"] = trend_capture_analysis(item["candidate"], data, ind, ranges.all_start, ranges.all_end)


def trend_capture_analysis(
    candidate: engine.Candidate,
    data: engine.MarketData,
    ind: engine.Indicators,
    start_idx: int,
    end_idx: int,
) -> dict[str, Any]:
    positions, exits = position_trace(candidate, data, ind, start_idx, end_idx)
    up_segments = major_segments(data, ind, start_idx, end_idx, up=True)
    down_segments = major_segments(data, ind, start_idx, end_idx, up=False)
    weighted_capture = 0.0
    weighted_coverage = 0.0
    total_weight = 0.0
    segment_details: list[dict[str, Any]] = []
    for start, end in up_segments:
        bh = data.close[end] / data.close[start] - 1
        if bh <= 0:
            continue
        strat = 1.0
        long_days = 0
        for idx in range(start + 1, end + 1):
            if positions[idx - 1] == 1:
                strat *= data.close[idx] / data.close[idx - 1]
                long_days += 1
        capture = max(0.0, strat - 1) / bh
        coverage = long_days / max(1, end - start)
        weight = bh
        weighted_capture += capture * weight
        weighted_coverage += coverage * weight
        total_weight += weight
        segment_details.append(
            {
                "start": data.dates[start].isoformat(),
                "end": data.dates[end].isoformat(),
                "buy_hold_return": float(bh),
                "capture_ratio": float(capture),
                "long_coverage": float(coverage),
            }
        )
    down_avoid = 0.0
    down_weight = 0.0
    for start, end in down_segments:
        drop = 1 - data.close[end] / data.close[start]
        if drop <= 0:
            continue
        non_long_days = sum(1 for idx in range(start, end + 1) if positions[idx] <= 0)
        avoid = non_long_days / max(1, end - start + 1)
        down_avoid += avoid * drop
        down_weight += drop

    sell_fly_events: list[dict[str, Any]] = []
    for exit_idx in exits:
        if exit_idx < start_idx or exit_idx > end_idx:
            continue
        best_future = 0.0
        best_window = 0
        for window, threshold in [(20, 0.10), (40, 0.15), (60, 0.20)]:
            future_idx = min(end_idx, exit_idx + window)
            if future_idx <= exit_idx:
                continue
            future_gain = np.max(data.close[exit_idx + 1 : future_idx + 1]) / data.close[exit_idx] - 1
            if future_gain >= threshold and future_gain > best_future:
                best_future = float(future_gain)
                best_window = window
        if best_window:
            sell_fly_events.append(
                {
                    "date": data.dates[exit_idx].isoformat(),
                    "price": float(data.close[exit_idx]),
                    "window": best_window,
                    "future_gain": best_future,
                }
            )

    return {
        "up_segment_count": len(up_segments),
        "trend_capture_ratio": float(weighted_capture / total_weight) if total_weight else 0.0,
        "trend_long_coverage": float(weighted_coverage / total_weight) if total_weight else 0.0,
        "down_segment_count": len(down_segments),
        "downside_avoidance": float(down_avoid / down_weight) if down_weight else 0.0,
        "sell_fly_count": len(sell_fly_events),
        "sell_fly_avg_future_gain": float(np.mean([event["future_gain"] for event in sell_fly_events])) if sell_fly_events else 0.0,
        "sell_fly_events": sell_fly_events[:10],
        "up_segments": segment_details[:10],
    }


def position_trace(
    candidate: engine.Candidate,
    data: engine.MarketData,
    ind: engine.Indicators,
    start_idx: int,
    end_idx: int,
) -> tuple[np.ndarray, list[int]]:
    long_sig, short_sig, exit_long_sig, exit_short_sig, modes = signal_arrays([candidate], data, ind)
    p = dict(candidate.params)
    positions = np.zeros(len(data.close), dtype=np.int8)
    position = 0
    entry_mode = 0
    entry_price = 0.0
    high_since = 0.0
    low_since = math.inf
    highest_close = 0.0
    lowest_close = math.inf
    hold_days = 0
    long_exits: list[int] = []
    for idx in range(start_idx, end_idx + 1):
        if idx > start_idx:
            sig = idx - 1
            if position != 0:
                hold_days += 1
                high_since = max(high_since, data.high[sig])
                low_since = min(low_since, data.low[sig])
                highest_close = max(highest_close, data.close[sig])
                lowest_close = min(lowest_close, data.close[sig])
                exit_now = (position == 1 and exit_long_sig[0, sig]) or (position == -1 and exit_short_sig[0, sig])
                if candidate.family == "state_switch":
                    exit_now = exit_now or state_risk_exit(
                        p,
                        position,
                        entry_mode,
                        data.close[sig],
                        entry_price,
                        high_since,
                        low_since,
                        highest_close,
                        lowest_close,
                        hold_days,
                        ind,
                        sig,
                    )
                else:
                    exit_now = exit_now or generic_risk_exit(
                        p,
                        position,
                        data.close[sig],
                        entry_price,
                        high_since,
                        low_since,
                        highest_close,
                        lowest_close,
                        hold_days,
                        ind,
                        sig,
                    )
                if exit_now:
                    if position == 1:
                        long_exits.append(sig)
                    position = 0
                    entry_mode = 0
            if position == 0:
                if long_sig[0, sig]:
                    position = 1
                    entry_mode = int(modes[0, sig]) if candidate.family == "state_switch" else 0
                    entry_price = data.open[idx] * (1 + engine.SLIPPAGE)
                    high_since = data.high[sig]
                    low_since = data.low[sig]
                    highest_close = data.close[sig]
                    lowest_close = data.close[sig]
                    hold_days = 0
                elif short_sig[0, sig]:
                    position = -1
                    entry_mode = -1
                    entry_price = data.open[idx] * (1 - engine.SLIPPAGE)
                    high_since = data.high[sig]
                    low_since = data.low[sig]
                    highest_close = data.close[sig]
                    lowest_close = data.close[sig]
                    hold_days = 0
        positions[idx] = position
    return positions, long_exits


def major_segments(
    data: engine.MarketData,
    ind: engine.Indicators,
    start_idx: int,
    end_idx: int,
    *,
    up: bool,
) -> list[tuple[int, int]]:
    sma = ind.sma[80]
    slope = ind.slope[60]
    roc = ind.roc[60]
    if up:
        mask = (data.close > sma) & (slope > 0) & (roc > 0)
    else:
        mask = (data.close < sma) & (slope < 0) & (roc < 0)
    segments: list[tuple[int, int]] = []
    idx = start_idx
    while idx <= end_idx:
        if not mask[idx] or np.isnan(sma[idx]):
            idx += 1
            continue
        start = idx
        while idx <= end_idx and mask[idx]:
            idx += 1
        end = idx - 1
        if end - start + 1 >= 20:
            move = data.close[end] / data.close[start] - 1
            if (up and move >= 0.15) or ((not up) and move <= -0.15):
                segments.append((start, end))
    return segments


def record_sort_key(item: dict[str, Any]) -> tuple[float, ...]:
    full = item.get("train_full") or item.get("full")
    years = item.get("years", {})
    trend = item.get("trend_train", {})
    min_year = min((years.get(label, {}).get("total_return", -9) for label in ["2022", "2023", "2024", "2025"]), default=-9)
    std_year = np.std([years[label]["total_return"] for label in ["2022", "2023", "2024", "2025"] if label in years]) if years else 9
    wf = item.get("walk_forward", {})
    return (
        0 if wf.get("all_pass", False) else 1,
        -trend.get("trend_capture_ratio", 0.0),
        float(trend.get("sell_fly_count", 999)),
        -full["total_return"],
        -min_year,
        -full["profit_factor"],
        -full["max_drawdown"],
        std_year,
        abs(full["round_trips"] - 18),
    )


def closest_sort_key(item: dict[str, Any]) -> tuple[float, ...]:
    full = item.get("full") or item.get("train_full")
    years = item.get("years", {})
    labels = ["2022", "2023", "2024", "2025", "2026YTD"]
    return_shortfalls = [max(0.0, 0.10 - years.get(label, {}).get("total_return", -1.0)) for label in labels]
    dd_shortfalls = [max(0.0, -0.20 - years.get(label, {}).get("max_drawdown", -1.0)) for label in labels]
    pf_shortfall = max(0.0, 1.5 - full.get("profit_factor", 0.0)) if full else 1.5
    sample_shortfall = max(0, 10 - full["round_trips"]) / 10 if full else 1.0
    return (
        float(sum(shortfall > 0 for shortfall in return_shortfalls)),
        float(sum(return_shortfalls)),
        float(sum(dd_shortfalls)),
        pf_shortfall,
        sample_shortfall,
        -full["total_return"] if full else 1.0,
        -full["max_drawdown"] if full else 1.0,
    )


def select_top3(records: list[dict[str, Any]], require_pass: bool = True) -> list[dict[str, Any]]:
    sorted_records = sorted(records, key=record_sort_key if require_pass else closest_sort_key)
    selected: list[dict[str, Any]] = []
    signatures: set[tuple[Any, ...]] = set()
    families: set[str] = set()
    for item in sorted_records:
        signature = strategy_signature(item["candidate"])
        family = item["candidate"].family
        if signature in signatures or (family in families and len(families) < 3):
            continue
        selected.append(item)
        signatures.add(signature)
        families.add(family)
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


def strategy_signature(candidate: engine.Candidate) -> tuple[Any, ...]:
    p = dict(candidate.params)
    if candidate.family != "state_switch":
        return ORIGINAL_STRATEGY_SIGNATURE(candidate)
    return (
        candidate.family,
        p.get("up_ma"),
        p.get("up_slope_days"),
        p.get("trend_entry"),
        p.get("trend_entry_channel"),
        p.get("trend_entry_ma"),
        p.get("trend_exit_ma"),
        p.get("trend_atr_trail_mult"),
        p.get("range_entry"),
        p.get("range_take_profit"),
        p.get("allow_short"),
    )


def avoids_small_take_profit(candidate: engine.Candidate) -> bool:
    p = dict(candidate.params)
    if candidate.family == "state_switch":
        return "trend_take_profit" not in p or p["trend_take_profit"] >= 0.40
    take_profit = p.get("take_profit")
    return take_profit is None or take_profit >= 0.24


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
        "trend_train": item.get("trend_train", {}),
        "trend_full": item.get("trend_full", {}),
        "sample_warning": full["round_trips"] < 10 if full else None,
    }


def strategy_name(candidate: engine.Candidate) -> str:
    if candidate.name:
        return candidate.name.replace("AMD", "NVDA")
    if candidate.family == "state_switch":
        p = dict(candidate.params)
        return f"NVDA state switch {p['trend_entry']} / {p['range_entry']}"
    return ORIGINAL_STRATEGY_NAME(candidate).replace("AMD", "NVDA")


def formula(candidate: engine.Candidate) -> str:
    p = dict(candidate.params)
    if candidate.family != "state_switch":
        return ORIGINAL_FORMULA(candidate).replace("AMD", "NVDA")
    return (
        "Regime: uptrend when NVDA close > "
        f"{p.get('up_ma_kind','sma').upper()}{p['up_ma']}, slope{p['up_slope_days']} >= {p['up_slope_min']}, "
        f"ROC{p['up_roc_days']} >= {p['up_roc_min']:.0%}, ADX{p['up_adx_days']} >= {p['up_adx_min']}; "
        f"range when ADX{p['range_adx_days']} <= {p['range_adx_max']} and slope/ROC are muted; "
        f"downtrend when close < SMA{p['down_ma']} with negative slope/ROC. "
        f"Uptrend long entry: {p['trend_entry']}; exit by {p.get('trend_exit_ma_kind','sma').upper()}{p['trend_exit_ma']} "
        f"or ATR{p['atr_days']} trailing {p['trend_atr_trail_mult']}x / stop {p['trend_atr_stop_mult']}x"
        + (f" / max hold {p['trend_max_hold']}d" if "trend_max_hold" in p else " / no trend max-hold")
        + (f" / wide take-profit {p['trend_take_profit']:.0%}. " if "trend_take_profit" in p else " / no fixed trend take-profit. ")
        + f"Range entry: {p['range_entry']}; range take-profit {p['range_take_profit']:.0%}, stop {p['range_fixed_stop']:.0%}, max hold {p['range_max_hold']}d. "
        + ("Shorts enabled in downtrend." if p.get("allow_short") else "Downtrend uses flat/no-new-long mode.")
    )


if __name__ == "__main__":
    main()
