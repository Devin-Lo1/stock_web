from __future__ import annotations

import argparse
import json
import random
import subprocess
import time
from datetime import date, datetime, time as dt_time, timedelta
from pathlib import Path
from typing import Any

import numpy as np

import research_chinalife_hk_aggressive_tmp as hk
import research_nvda_state_switch_tmp as state


TARGET = "HK.02628"
BENCHMARK = "HK.800000"
START = date(2021, 1, 4)
REQUESTED_END = date(2026, 6, 11)
TRAIN_END = date(2025, 12, 31)
OUTPUT_PATH = "scripts/research_chinalife_hk_state_switch_tmp_result.json"
PROGRESS_PATH = "scripts/research_chinalife_hk_state_switch_tmp_progress.json"

_ORIG_OPEN_LONG = hk.open_long_quantity
_ORIG_OPEN_SHORT = hk.open_short_quantity


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage1", type=int, default=800_000)
    parser.add_argument("--seed", type=int, default=20260611)
    parser.add_argument("--batch-size", type=int, default=768)
    parser.add_argument("--output", default=OUTPUT_PATH)
    parser.add_argument("--progress", default=PROGRESS_PATH)
    args = parser.parse_args()

    started = time.time()
    rng = random.Random(args.seed)

    write_progress(args.progress, "fetching_data", 0, args.stage1, started)
    rows = fetch_cloud_candles()
    effective_end, end_note = choose_effective_end(rows)
    patch_state_engine(effective_end)

    data = hk.MarketData.from_rows(filter_rows(rows, effective_end))
    ind = hk.Indicators(data)
    extend_channel_indicators(data, ind)
    state.repair_adx(ind)
    ranges = hk.DateRanges(data.dates)
    split_report = hk.split_adjustment_report(rows[TARGET])

    current_records = build_current_app_records(data, ind, ranges)

    seen: set[tuple[Any, ...]] = {state.candidate_key(item["candidate"]) for item in current_records}
    prelim: list[dict[str, Any]] = []
    top_by_family: dict[str, list[dict[str, Any]]] = {}
    tested_by_family: dict[str, int] = {}
    prelim_by_family: dict[str, int] = {}
    tested = 0

    for item in current_records:
        candidate = item["candidate"]
        tested += 1
        tested_by_family[candidate.family] = tested_by_family.get(candidate.family, 0) + 1
        train_full = item["train_full"]
        if state.preliminary_pass(train_full):
            prelim_by_family[candidate.family] = prelim_by_family.get(candidate.family, 0) + 1
            state.remember_family_record(top_by_family, {"candidate": candidate, "train_full": train_full})

    write_progress(args.progress, "stage1_search", tested, args.stage1, started)
    while tested < args.stage1:
        batch: list[hk.Candidate] = []
        while len(batch) < args.batch_size and tested < args.stage1:
            candidate = random_candidate(rng)
            key = state.candidate_key(candidate)
            if key in seen:
                continue
            seen.add(key)
            batch.append(candidate)
            tested += 1
            tested_by_family[candidate.family] = tested_by_family.get(candidate.family, 0) + 1

        metrics = state.evaluate_candidates(batch, data, ind, ranges.train_start, ranges.train_end)
        for candidate, metric in zip(batch, metrics):
            if state.preliminary_pass(metric):
                prelim_by_family[candidate.family] = prelim_by_family.get(candidate.family, 0) + 1
                record = {"candidate": candidate, "train_full": metric}
                prelim.append(record)
                state.remember_family_record(top_by_family, record)

        if tested % 25_000 < args.batch_size:
            write_progress(args.progress, "stage1_search", tested, args.stage1, started)

    local_candidates = state.local_refine_candidates(top_by_family, rng, seen)
    local_metrics = state.evaluate_candidates(local_candidates, data, ind, ranges.train_start, ranges.train_end)
    for candidate, metric in zip(local_candidates, local_metrics):
        tested += 1
        tested_by_family[candidate.family] = tested_by_family.get(candidate.family, 0) + 1
        if state.preliminary_pass(metric):
            prelim_by_family[candidate.family] = prelim_by_family.get(candidate.family, 0) + 1
            record = {"candidate": candidate, "train_full": metric}
            prelim.append(record)
            state.remember_family_record(top_by_family, record)

    write_progress(args.progress, "annual_review", tested, tested, started)
    review_pool = state.annual_review_pool(top_by_family)
    reviewed = state.annual_review(review_pool, data, ind, ranges)
    train_pass = [item for item in reviewed if item["train_pass"]]

    write_progress(args.progress, "walk_forward", tested, tested, started)
    wf_counts = {"2024": 0, "2025": 0, "2026YTD": 0, "all": 0}
    final_records: list[dict[str, Any]] = []
    for item in train_pass:
        wf = state.walk_forward(item["candidate"], data, ind, ranges)
        item["walk_forward"] = wf
        wf_counts["2024"] += int(wf["2024"]["pass"])
        wf_counts["2025"] += int(wf["2025"]["pass"])
        wf_counts["2026YTD"] += int(wf["2026YTD"]["pass"])
        wf_counts["all"] += int(wf["all_pass"])
        item["full"] = state.evaluate_candidates([item["candidate"]], data, ind, ranges.all_start, ranges.all_end)[0]
        item["years"] = state.annual_metrics([item["candidate"]], data, ind, ranges)[0]
        if state.final_pass(item):
            state.add_trend_metrics(item, data, ind, ranges)
            final_records.append(item)

    final_state_switch = [item for item in final_records if item["candidate"].family == "state_switch"]
    final_with_benchmark = [item for item in final_records if uses_benchmark_conditions(item["candidate"])]
    final_without_benchmark = [item for item in final_records if not uses_benchmark_conditions(item["candidate"])]
    final_no_small_tp = [item for item in final_records if state.avoids_small_take_profit(item["candidate"])]

    top3 = state.select_top3(final_records)
    top3_state_switch = state.select_top3(final_state_switch)
    top3_with_benchmark = state.select_top3(final_with_benchmark)
    top3_without_benchmark = state.select_top3(final_without_benchmark)
    top3_no_small_tp = state.select_top3(final_no_small_tp)

    closest = state.select_top3(reviewed if reviewed else prelim, require_pass=False)
    closest_state_switch = state.select_top3(
        [item for item in reviewed if item["candidate"].family == "state_switch"],
        require_pass=False,
    )
    for item in closest + closest_state_switch:
        ensure_enriched(item, data, ind, ranges)
        state.add_trend_metrics(item, data, ind, ranges)

    output = {
        "meta": {
            "target": TARGET,
            "benchmark": BENCHMARK,
            "requested_range": f"{START.isoformat()}~{REQUESTED_END.isoformat()}",
            "effective_range": f"{START.isoformat()}~{effective_end.isoformat()}",
            "effective_end_note": end_note,
            "seed": args.seed,
            "started_at": datetime.now().isoformat(timespec="seconds"),
            "elapsed_seconds": round(time.time() - started, 2),
            "cost_model": {
                "initial_cash": hk.INITIAL_CASH,
                "slippage_single_side": hk.SLIPPAGE,
                "broker_commission_rate": hk.BROKER_COMMISSION_RATE,
                "broker_min_commission": hk.BROKER_MIN_COMMISSION,
                "hk_stamp_duty_rate": hk.HK_STAMP_DUTY_RATE,
                "hk_sfc_transaction_levy_rate": hk.HK_SFC_TRANSACTION_LEVY_RATE,
                "hk_afrc_transaction_levy_rate": hk.HK_AFRC_TRANSACTION_LEVY_RATE,
                "hk_trading_fee_rate": hk.HK_TRADING_FEE_RATE,
                "hk_ccass_settlement_fee_rate": hk.HK_CCASS_SETTLEMENT_FEE_RATE,
                "hk_ccass_min": hk.HK_CCASS_MIN,
                "hk_ccass_max": hk.HK_CCASS_MAX,
                "fee_note": "港股费用近似：佣金、印花税、交易征费、会财局交易征费、交易费、CCASS 结算费，另计单边滑点。",
            },
            "execution": "T 日收盘生成信号，T+1 交易日开盘按滑点成交；区间结束仍持仓按最后可用收盘价强制平仓。",
            "selection_rule": "2026YTD 只作最终验证，不参与 2021-2025 参数搜索、排序或调参。",
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
            "final_with_hsi_conditions": len(final_with_benchmark),
            "final_without_hsi_conditions": len(final_without_benchmark),
            "final_no_small_take_profit": len(final_no_small_tp),
            "tested_by_family": dict(sorted(tested_by_family.items())),
            "preliminary_pass_by_family": dict(sorted(prelim_by_family.items())),
        },
        "current_app": [serialize_record(item) for item in current_records],
        "top3": [serialize_record(item) for item in top3],
        "top3_state_switch": [serialize_record(item) for item in top3_state_switch],
        "top3_with_hsi": [serialize_record(item) for item in top3_with_benchmark],
        "top3_without_hsi": [serialize_record(item) for item in top3_without_benchmark],
        "top3_no_small_take_profit": [serialize_record(item) for item in top3_no_small_tp],
        "closest": [serialize_record(item) for item in closest],
        "closest_state_switch": [serialize_record(item) for item in closest_state_switch],
    }
    Path(args.output).write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
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


def patch_state_engine(effective_end: date) -> None:
    years = {
        "2022": (date(2022, 1, 1), date(2022, 12, 31)),
        "2023": (date(2023, 1, 1), date(2023, 12, 31)),
        "2024": (date(2024, 1, 1), date(2024, 12, 31)),
        "2025": (date(2025, 1, 1), date(2025, 12, 31)),
        "2026YTD": (date(2026, 1, 1), effective_end),
    }
    hk.END = effective_end
    hk.TRAIN_END = TRAIN_END
    hk.YEARS = years
    hk.open_long_quantity = lambda equity, price: _ORIG_OPEN_LONG(equity, price, 1.0)  # type: ignore[assignment]
    hk.open_short_quantity = lambda equity, price: _ORIG_OPEN_SHORT(equity, price, 1.0)  # type: ignore[assignment]

    state.engine = hk
    state.TARGET = TARGET
    state.BENCHMARK = BENCHMARK
    state.TARGET_ALIAS = TARGET
    state.END = effective_end
    state.TRAIN_END = TRAIN_END
    state.YEARS = years
    state.ORIGINAL_SIGNAL_ARRAYS = hk.signal_arrays
    state.ORIGINAL_NEIGHBORS = hk.neighbors
    state.ORIGINAL_STRATEGY_SIGNATURE = hk.strategy_signature
    state.ORIGINAL_RANDOM_CANDIDATE = hk.random_candidate
    state.ORIGINAL_AMD_REGION_CANDIDATE = hk.random_chinalife_hk_aggressive_region_candidate
    state.ORIGINAL_STRATEGY_NAME = hk.strategy_name
    state.ORIGINAL_FORMULA = hk.formula
    state.normalize_state_params = normalize_state_params
    state.strategy_name = strategy_name
    state.formula = formula
    state.strategy_signature = strategy_signature


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
    payload[code] = [row(c) for c in list_candles_between(code, 'day', date(2021,1,4), date(2026,6,11))]
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


def choose_effective_end(rows: dict[str, list[dict[str, Any]]]) -> tuple[date, str]:
    target_dates = {date.fromisoformat(item["time"]) for item in rows[TARGET]}
    benchmark_dates = {date.fromisoformat(item["time"]) for item in rows[BENCHMARK]}
    aligned = sorted(d for d in target_dates & benchmark_dates if d <= REQUESTED_END)
    if not aligned:
        raise RuntimeError("No aligned cloud candles found for target and benchmark.")
    latest = aligned[-1]
    now = datetime.now()
    if latest == now.date() and now.time() < dt_time(16, 15):
        if len(aligned) < 2:
            raise RuntimeError("Only an intraday candle is available; cannot backtest safely.")
        return aligned[-2], f"{latest.isoformat()} 仍可能是未收盘日K，已自动排除，使用 {aligned[-2].isoformat()}。"
    return latest, "使用目标与基准共同可用的最后一个交易日。"


def filter_rows(rows: dict[str, list[dict[str, Any]]], effective_end: date) -> dict[str, list[dict[str, Any]]]:
    return {
        code: [item for item in values if START <= date.fromisoformat(item["time"]) <= effective_end]
        for code, values in rows.items()
    }


def extend_channel_indicators(data: hk.MarketData, ind: hk.Indicators) -> None:
    for window in range(101, 121):
        ind.prior_high[window] = hk.prior_extreme(data.high, window, "max")
        ind.prior_low[window] = hk.prior_extreme(data.low, window, "min")
    for window in range(201, 221):
        ind.sma[window] = hk.rolling_mean(data.close, window)
        ind.ema[window] = hk.ema(data.close, window)
        ind.benchmark_sma[window] = hk.rolling_mean(data.benchmark_close, window)
        ind.benchmark_ema[window] = hk.ema(data.benchmark_close, window)


def build_current_app_records(data: hk.MarketData, ind: hk.Indicators, ranges: hk.DateRanges) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for candidate in [current_steady_candidate(), current_aggressive_candidate()]:
        train_full = state.evaluate_candidates([candidate], data, ind, ranges.train_start, ranges.train_end)[0]
        full = state.evaluate_candidates([candidate], data, ind, ranges.all_start, ranges.all_end)[0]
        years = state.annual_metrics([candidate], data, ind, ranges)[0]
        record = {
            "candidate": candidate,
            "train_full": train_full,
            "full": full,
            "years": years,
            "walk_forward": state.walk_forward(candidate, data, ind, ranges),
        }
        state.add_trend_metrics(record, data, ind, ranges)
        records.append(record)
    return records


def current_steady_candidate() -> hk.Candidate:
    return hk.Candidate(
        family="channel",
        direction="long_short",
        name="current_app_chinalife_channel67_steady",
        params=tuple(
            sorted(
                {
                    "entry_channel": 67,
                    "exit_channel": 42,
                    "qqq_ma": 80,
                    "qqq_ma_kind": "ema",
                    "benchmark_ma": 200,
                    "benchmark_ma_kind": "ema",
                    "benchmark_roc_days": 80,
                    "benchmark_roc_min": 0.02,
                    "own_roc_days": 40,
                    "own_roc_min": 0.08,
                    "relative_days": 20,
                    "relative_min": 0.02,
                    "atr_days": 14,
                    "atr_pct_max": 0.035,
                    "exit_ma": 100,
                    "exit_ma_kind": "sma",
                    "take_profit": 0.12,
                    "max_hold": 80,
                    "reverse_exit": False,
                }.items()
            )
        ),
    )


def current_aggressive_candidate() -> hk.Candidate:
    return hk.Candidate(
        family="channel",
        direction="long_short",
        name="current_app_chinalife_channel72_aggressive",
        params=tuple(
            sorted(
                {
                    "entry_channel": 72,
                    "exit_channel": 54,
                    "qqq_ma": 100,
                    "qqq_ma_kind": "ema",
                    "benchmark_roc_days": 80,
                    "benchmark_roc_min": 0.02,
                    "own_roc_days": 40,
                    "own_roc_min": 0.08,
                    "relative_days": 40,
                    "relative_min": 0.0,
                    "atr_days": 20,
                    "atr_pct_max": 0.035,
                    "exit_ma": 80,
                    "exit_ma_kind": "sma",
                    "fixed_stop": 0.12,
                    "trailing_stop": 0.18,
                    "take_profit": 0.12,
                    "reverse_exit": False,
                }.items()
            )
        ),
    )


def random_candidate(rng: random.Random) -> hk.Candidate:
    if rng.random() < 0.66:
        return random_state_switch_candidate(rng)
    if rng.random() < 0.58:
        return hk.random_chinalife_hk_aggressive_region_candidate(rng)
    return hk.random_candidate(rng)


def random_state_switch_candidate(rng: random.Random) -> hk.Candidate:
    candidate = state.random_state_switch_candidate(rng)
    params = dict(candidate.params)
    for key in ["trend_entry_channel", "range_channel", "short_channel"]:
        if key in params and rng.random() < 0.40:
            params[key] = rng.randint(5, 120)
    if rng.random() < 0.25:
        params.pop("benchmark_ma", None)
        params.pop("benchmark_ma_kind", None)
        params.pop("benchmark_roc_days", None)
        params.pop("benchmark_roc_min", None)
        params.pop("relative_days", None)
        params.pop("relative_min", None)
    return hk.Candidate("state_switch", "long_short", tuple(sorted(normalize_state_params(params).items())))


def normalize_state_params(params: dict[str, Any]) -> dict[str, Any]:
    p = dict(params)
    ma_values = [10, 20, 30, 40, 50, 80, 100, 120, 150, 200, 220]
    for key in ["up_ma", "down_ma", "trend_entry_ma", "trend_exit_ma", "range_entry_ma", "range_exit_ma", "benchmark_ma"]:
        if key in p:
            p[key] = min(ma_values, key=lambda item: abs(item - int(p[key])))
    for key in ["up_slope_days", "down_slope_days", "range_slope_days"]:
        if key in p:
            p[key] = min([20, 40, 60, 80], key=lambda item: abs(item - int(p[key])))
    for key in [
        "up_roc_days",
        "down_roc_days",
        "range_roc_days",
        "trend_momentum_days",
        "range_momentum_days",
        "benchmark_roc_days",
        "relative_days",
    ]:
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
            p[key] = int(max(5, min(120, p[key])))
    if p.get("trend_short_window", 5) >= p.get("trend_long_window", 40):
        p["trend_long_window"] = min(220, p["trend_short_window"] + 20)
    return p


def uses_benchmark_conditions(candidate: hk.Candidate) -> bool:
    params = dict(candidate.params)
    return any(key in params for key in ["benchmark_ma", "benchmark_roc_days", "benchmark_slope_days", "relative_days"])


def ensure_enriched(item: dict[str, Any], data: hk.MarketData, ind: hk.Indicators, ranges: hk.DateRanges) -> None:
    if "full" not in item:
        item["full"] = state.evaluate_candidates([item["candidate"]], data, ind, ranges.all_start, ranges.all_end)[0]
    if "years" not in item:
        item["years"] = state.annual_metrics([item["candidate"]], data, ind, ranges)[0]
    if "walk_forward" not in item:
        item["walk_forward"] = state.walk_forward(item["candidate"], data, ind, ranges)


def strategy_signature(candidate: hk.Candidate) -> tuple[Any, ...]:
    if candidate.family != "state_switch":
        return hk.strategy_signature(candidate)
    p = dict(candidate.params)
    return (
        candidate.family,
        p.get("up_ma"),
        p.get("up_slope_days"),
        p.get("up_roc_days"),
        p.get("up_adx_days"),
        p.get("trend_entry"),
        p.get("trend_entry_channel"),
        p.get("trend_entry_ma"),
        p.get("trend_long_window"),
        p.get("trend_exit_ma"),
        p.get("trend_atr_trail_mult"),
        p.get("range_entry"),
        p.get("range_take_profit"),
        p.get("range_max_hold"),
        p.get("allow_short"),
        uses_benchmark_conditions(candidate),
    )


def strategy_name(candidate: hk.Candidate) -> str:
    if candidate.name:
        return candidate.name
    if candidate.family == "state_switch":
        p = dict(candidate.params)
        return f"中国人寿 状态切换 {p['trend_entry']} / {p['range_entry']}"
    return hk.strategy_name(candidate)


def formula(candidate: hk.Candidate) -> str:
    p = dict(candidate.params)
    if candidate.family != "state_switch":
        return hk.formula(candidate)
    benchmark = []
    if "benchmark_ma" in p:
        benchmark.append(f"恒生 {p.get('benchmark_ma_kind','sma').upper()}{p['benchmark_ma']}")
    if "benchmark_roc_days" in p:
        benchmark.append(f"恒生 ROC{p['benchmark_roc_days']} >= {p['benchmark_roc_min']:.0%}")
    if "relative_days" in p:
        benchmark.append(f"中国人寿-恒生 ROC{p['relative_days']} >= {p['relative_min']:.0%}")
    return (
        f"状态：上涨=收盘>{p.get('up_ma_kind','sma').upper()}{p['up_ma']} 且 slope{p['up_slope_days']}>={p['up_slope_min']}、"
        f"ROC{p['up_roc_days']}>={p['up_roc_min']:.0%}、ADX{p['up_adx_days']}>={p['up_adx_min']}; "
        f"震荡=ADX{p['range_adx_days']}<={p['range_adx_max']} 且斜率/ROC 收敛；"
        f"下跌=收盘<SMA{p['down_ma']} 且 slope/ROC 转负；"
        + (f"基准过滤：{'; '.join(benchmark)}；" if benchmark else "不使用恒生基准过滤；")
        + f"上涨做多入场={p['trend_entry']}，退出={p.get('trend_exit_ma_kind','sma').upper()}{p['trend_exit_ma']} 或 ATR{p['atr_days']}移动止损{p['trend_atr_trail_mult']}x/初始止损{p['trend_atr_stop_mult']}x"
        + (f"，趋势最长{p['trend_max_hold']}日" if "trend_max_hold" in p else "，趋势不设最长持仓")
        + (f"，宽止盈{p['trend_take_profit']:.0%}。" if "trend_take_profit" in p else "，趋势无固定止盈。")
        + f"震荡入场={p['range_entry']}，止盈{p['range_take_profit']:.0%}，止损{p['range_fixed_stop']:.0%}，最长{p['range_max_hold']}日。"
        + ("下跌允许做空。" if p.get("allow_short") else "下跌空仓规避。")
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
        "trend_train": item.get("trend_train", {}),
        "trend_full": item.get("trend_full", {}),
        "sample_warning": full["round_trips"] < 10 if full else None,
    }


if __name__ == "__main__":
    main()
