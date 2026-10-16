from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import research_brkb_steady_tmp as engine


OUTPUT_PATH = "scripts/research_spy_self_steady_tmp_result.json"
PROGRESS_PATH = "scripts/research_spy_self_steady_tmp_progress.json"
EXTERNAL_KEYS = {
    "benchmark_ma",
    "benchmark_ma_kind",
    "benchmark_roc_days",
    "benchmark_roc_min",
    "benchmark_slope_days",
    "benchmark_slope_min",
    "relative_days",
    "relative_min",
}

ORIGINAL_RANDOM_CANDIDATE = engine.random_candidate
ORIGINAL_SPLIT_ADJUSTMENT_REPORT = engine.split_adjustment_report
ORIGINAL_STRATEGY_NAME = engine.strategy_name
ORIGINAL_FORMULA = engine.formula


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
spy = [row(c) for c in list_candles_between('US.SPY', 'day', date(2021,1,4), date(2026,6,3))]
print(json.dumps({'US.SPY': spy}))
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
    spy_rows = rows["US.SPY"]
    return {"US.BRK.B": spy_rows, "US.QQQ": spy_rows}


def strip_external(candidate: engine.Candidate) -> engine.Candidate:
    params = tuple((key, value) for key, value in candidate.params if key not in EXTERNAL_KEYS)
    return engine.Candidate(
        family=candidate.family,
        direction=candidate.direction,
        params=tuple(sorted(params)),
        name=candidate.name,
    )


def random_candidate(rng: Any) -> engine.Candidate:
    return strip_external(ORIGINAL_RANDOM_CANDIDATE(rng))


def split_adjustment_report(rows: list[dict[str, Any]]) -> dict[str, Any]:
    base = ORIGINAL_SPLIT_ADJUSTMENT_REPORT(rows)
    base["known_event"] = "No known SPY split adjustment was required for the requested 2021-2026 window."
    return base


def strategy_name(candidate: engine.Candidate) -> str:
    return ORIGINAL_STRATEGY_NAME(candidate).replace("BRK.B", "SPY")


def formula(candidate: engine.Candidate) -> str:
    return ORIGINAL_FORMULA(candidate).replace("BRK.B", "SPY")


def main() -> None:
    engine.fetch_cloud_candles = fetch_cloud_candles
    engine.random_candidate = random_candidate
    engine.split_adjustment_report = split_adjustment_report
    engine.strategy_name = strategy_name
    engine.formula = formula

    args = sys.argv[1:]
    if "--output" not in args:
        args.extend(["--output", OUTPUT_PATH])
    if "--progress" not in args:
        args.extend(["--progress", PROGRESS_PATH])
    sys.argv = [sys.argv[0], *args]
    engine.main()

    path = Path(OUTPUT_PATH)
    if "--output" in args:
        path = Path(args[args.index("--output") + 1])
    output = json.loads(path.read_text(encoding="utf-8"))
    output["meta"]["target"] = "US.SPY"
    output["meta"]["benchmark"] = None
    output["meta"]["auxiliary_benchmark"] = None
    output["meta"]["current_app_note"] = "No existing App personalized strategy template was found for US.SPY."
    output["meta"]["selection_rule"] = "2026YTD is used only as final validation gate; ranking uses 2021-2025 training metrics."
    output["meta"]["external_reference"] = "No external benchmark, QQQ filter, SPY-vs-benchmark relative strength, or market filter was used."
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
