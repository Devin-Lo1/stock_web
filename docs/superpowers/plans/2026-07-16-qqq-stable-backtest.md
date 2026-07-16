# QQQ Stable High-Win-Rate Backtest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run a local-only QQQ research pipeline that evaluates at least 800,000 unique strategies with T+1 execution, realistic long/short costs, independent annual tests, expanding walk-forward selection, stability checks, and family-deduplicated Top3 reporting.

**Architecture:** Keep production backtesting unchanged. Add a small `scripts/qqq_research` package: immutable domain records, validated frozen data, lazy indicator cache, vectorized batch execution, deterministic candidate generation, training-only walk-forward selection, and auditable reporting. A thin CLI freezes cloud data, runs smoke/formal searches, and writes JSON/Markdown artifacts.

**Tech Stack:** Python 3.11+, NumPy 2.x, standard-library dataclasses/argparse/hashlib/heapq/json/subprocess, pytest 8.x, existing SSH access to the cloud candle cache.

## Global Constraints

- Target only `US.QQQ`; do not deploy, modify App templates, or write production backtest history.
- Read at least 2020 data for warm-up; report from `2021-01-04` through the latest complete frozen trading day.
- Generate signals from data through T close and execute ordinary orders at T+1 open.
- Use `100000 USD`, 100% maximum gross exposure, no leverage, 0.05% one-way slippage, 0.138% commission with 18 USD minimum, SEC/TAF approximation on sells, 1% annual baseline short borrow, and 2% borrow stress.
- Search at least 800,000 unique valid candidates with at most eight active tunable parameters; keep the current App candidate as an exempt fixed baseline.
- Never use 2026 metrics for generation, refinement, ranking, replacement, or family deduplication; use them only for pass/fail reporting after Top3 is frozen.
- Treat 2026YTD as a reused validation segment because earlier repository artifacts already expose it.
- Enforce full-period and stitched out-of-sample maximum drawdown no worse than -20%, every independent year no worse than -20%, at least four positive years across 2022-2026YTD, no year below -5%, at least 15 completed round trips, Profit Factor at least 1.40, and positive net expectancy.
- Target raw win rate at least 60% and Wilson 95% lower bound at least 50%; treat 3-24 completed round trips per year as the preferred frequency range.

---

### Task 1: Frozen QQQ Data And Domain Records

**Files:**
- Create: `scripts/qqq_research/__init__.py`
- Create: `scripts/qqq_research/domain.py`
- Create: `scripts/qqq_research/data.py`
- Test: `scripts/tests/test_qqq_research_data.py`

**Interfaces:**
- Produces: `Candidate`, `CostModel`, `MarketData`, `Metrics`, `Trade`, `DetailedResult`.
- Produces: `MarketData.from_rows(rows)`, `MarketData.validate()`, `MarketData.snapshot_hash()`.
- Produces: `fetch_cloud_rows() -> list[dict[str, object]]` and `freeze_cloud_data(path: Path) -> MarketData`.

- [ ] **Step 1: Write failing validation and snapshot tests**

```python
def test_market_data_rejects_duplicate_dates():
    rows = candle_rows("2021-01-04", "2021-01-04")
    with pytest.raises(ValueError, match="duplicate candle date"):
        MarketData.from_rows(rows)


def test_snapshot_hash_changes_when_price_changes():
    first = MarketData.from_rows(candle_rows("2021-01-04", "2021-01-05"))
    changed = candle_rows("2021-01-04", "2021-01-05")
    changed[-1]["close"] = 999.0
    second = MarketData.from_rows(changed)
    assert first.snapshot_hash() != second.snapshot_hash()
```

- [ ] **Step 2: Run the tests and confirm the missing package failure**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_data.py -q`

Expected: collection fails with `ModuleNotFoundError: No module named 'scripts.qqq_research'`.

- [ ] **Step 3: Implement immutable records and strict data validation**

```python
@dataclass(frozen=True)
class Candidate:
    family: str
    direction: Literal["long_only", "short_only", "long_short"]
    params: tuple[tuple[str, object], ...]
    name: str = ""

    def key(self) -> tuple[object, ...]:
        return (self.family, self.direction, self.params)


@dataclass(frozen=True)
class CostModel:
    initial_cash: float = 100_000.0
    slippage: float = 0.0005
    commission_rate: float = 0.00138
    minimum_commission: float = 18.0
    sec_rate: float = 20.60 / 1_000_000
    taf_per_share: float = 0.000195
    taf_max: float = 9.79
    annual_short_borrow_rate: float = 0.01


@dataclass(frozen=True)
class MarketData:
    dates: np.ndarray
    open: np.ndarray
    high: np.ndarray
    low: np.ndarray
    close: np.ndarray
    volume: np.ndarray
    turnover: np.ndarray

    def validate(self) -> None:
        if len(set(self.dates.tolist())) != len(self.dates):
            raise ValueError("duplicate candle date")
        if not np.all(self.high >= np.maximum(self.open, self.close)):
            raise ValueError("high below open or close")
        if not np.all(self.low <= np.minimum(self.open, self.close)):
            raise ValueError("low above open or close")
        if np.any(self.volume < 0):
            raise ValueError("negative volume")
```

- [ ] **Step 4: Implement frozen cloud extraction**

Use one SSH subprocess that queries `list_candles_between('US.QQQ', 'day', date(2020,1,1), date.today())`, serializes OHLCV/turnover, validates the returned rows, and writes `{symbol, fetched_at, snapshot_hash, rows}` to UTF-8 JSON before any search begins. Do not refresh this file during the run.

- [ ] **Step 5: Run tests and commit**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_data.py -q`

Expected: all tests pass.

Commit: `git add scripts/qqq_research scripts/tests/test_qqq_research_data.py && git commit -m "feat: add frozen QQQ research data model"`

### Task 2: Indicators And No-Lookahead Signals

**Files:**
- Create: `scripts/qqq_research/indicators.py`
- Create: `scripts/qqq_research/signals.py`
- Test: `scripts/tests/test_qqq_research_signals.py`

**Interfaces:**
- Consumes: `MarketData`, `Candidate`.
- Produces: `IndicatorCache(data)` with lazy SMA, EMA, ROC, ATR, ADX, RSI, MACD, KDJ, MFI, OBV slope, Bollinger z-score, volume ratio, and prior-channel arrays.
- Produces: `build_signals(candidate, data, cache) -> SignalSet` where all four arrays are indexed by signal date T.

- [ ] **Step 1: Write failing no-lookahead tests**

```python
def test_prior_channel_excludes_current_bar():
    values = np.array([10.0, 11.0, 12.0, 50.0])
    result = prior_extreme(values, 3, "max")
    assert result[-1] == 12.0


@pytest.mark.parametrize("indicator", ["macd", "kdj", "rsi", "mfi"])
def test_indicator_history_is_unchanged_by_future_bar(indicator, market_data):
    before = indicator_values(IndicatorCache(market_data), indicator).copy()
    extended = market_data.append(extreme_future_row())
    after = indicator_values(IndicatorCache(extended), indicator)
    np.testing.assert_allclose(before, after[:-1], equal_nan=True)


def test_signal_on_t_is_unchanged_by_t_plus_one_price(candidate, market_data):
    first = build_signals(candidate, market_data, IndicatorCache(market_data))
    changed = market_data.with_last_open(10_000.0)
    second = build_signals(candidate, changed, IndicatorCache(changed))
    np.testing.assert_array_equal(first.long_entry[:-1], second.long_entry[:-1])
```

- [ ] **Step 2: Run tests and verify missing indicator functions**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_signals.py -q`

Expected: failures identify missing `IndicatorCache`, `prior_extreme`, and `build_signals`.

- [ ] **Step 3: Implement lazy causal indicators**

Use cache keys such as `("ema", window)` and `("macd", fast, slow, signal)`. KDJ must calculate RSV from rolling high/low through T and recursively smooth K/D without reading T+1. MFI must use typical price and signed raw money flow through T. `prior_extreme(values, window, mode)[T]` must read only `[T-window:T]`.

- [ ] **Step 4: Implement strategy families**

Implement explicit branches for `ma_cross`, `channel`, `price_ma`, `roc_trend`, `macd`, `kdj`, `rsi_reversal`, `bollinger_reversal`, `volume_breakout`, and `price_volume`. Optional filters are `trend_ma`, `adx_min`, `atr_pct_max`, and `volume_ratio_min`. Direction handling must zero disallowed entries; reverse, exit-MA, and max-hold exits remain separate from entry filters.

- [ ] **Step 5: Run signal tests and commit**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_signals.py -q`

Expected: all tests pass.

Commit: `git add scripts/qqq_research scripts/tests/test_qqq_research_signals.py && git commit -m "feat: add causal QQQ factors and signals"`

### Task 3: T+1 Long/Short Execution Engine

**Files:**
- Create: `scripts/qqq_research/engine.py`
- Test: `scripts/tests/test_qqq_research_engine.py`

**Interfaces:**
- Consumes: `Candidate`, `CostModel`, `MarketData`, `SignalSet`.
- Produces: `evaluate_batch(candidates, data, cache, start, end, costs) -> list[Metrics]`.
- Produces: `simulate_detailed(candidate, data, cache, start, end, costs) -> DetailedResult`.

- [ ] **Step 1: Write failing execution tests**

```python
def test_close_signal_executes_at_next_open():
    result = simulate_detailed(always_buy_candidate(), four_day_data(), costs())
    assert result.trades[0].signal_date == date(2021, 1, 4)
    assert result.trades[0].trade_date == date(2021, 1, 5)
    assert result.trades[0].price == pytest.approx(110.0 * 1.0005)


def test_stop_and_target_same_day_uses_stop_first():
    result = simulate_detailed(bracket_candidate(), both_touched_data(), zero_costs())
    assert result.trades[-1].reason == "fixed_stop"


def test_short_borrow_is_deducted_daily():
    baseline = simulate_detailed(short_candidate(), rising_data(), costs(short_borrow=0.0))
    charged = simulate_detailed(short_candidate(), rising_data(), costs(short_borrow=0.01))
    assert charged.metrics.final_equity < baseline.metrics.final_equity


def test_end_of_period_forces_close_with_adverse_slippage():
    result = simulate_detailed(always_buy_candidate(), four_day_data(), costs())
    assert result.trades[-1].reason == "period_end"
    assert result.trades[-1].price == pytest.approx(130.0 * 0.9995)
```

- [ ] **Step 2: Run tests and verify engine failures**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_engine.py -q`

Expected: failures identify missing simulation functions.

- [ ] **Step 3: Implement daily event order**

For each day: execute queued T-1 ordinary exits at the open; execute queued T-1 entries/reversals at the open; evaluate predeclared intraday stop before target using current OHLC; accrue short borrow for positions held overnight; mark equity at close; update trailing extrema; generate T-close orders for the next trading day. Force-close remaining positions on the final close with adverse slippage.

- [ ] **Step 4: Implement complete metrics**

Track net round-trip PnL after all entry/exit fees, gross profit, gross loss, best trade contribution, long/short counts, hold days, total commission/regulatory/borrow costs, peak equity, drawdown, Profit Factor, expectancy, raw win rate, and Wilson 95% lower bound. `evaluate_batch` must share the same event ordering and fee helpers as `simulate_detailed`.

Also accumulate daily gross exposure divided by equity so every result reports average position. Independent annual runs reset cash and position at each year boundary; the full continuous run initializes once and carries state across years.

- [ ] **Step 5: Run engine tests and commit**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_engine.py -q`

Expected: all tests pass.

Commit: `git add scripts/qqq_research scripts/tests/test_qqq_research_engine.py && git commit -m "feat: add audited QQQ T+1 execution engine"`

### Task 4: Deterministic Candidate Search And Walk-Forward Selection

**Files:**
- Create: `scripts/qqq_research/candidates.py`
- Create: `scripts/qqq_research/search.py`
- Test: `scripts/tests/test_qqq_research_search.py`

**Interfaces:**
- Produces: `CandidateFactory(seed).iter_unique(total) -> Iterator[Candidate]`.
- Produces: `current_app_candidate() -> Candidate` with the frozen App parameters `SMA7/111`, `SMA120` trend filter, `ROC20 > 2%`, `SMA150` exit, 10% fixed stop, 10% trailing stop, 14% take profit, and qualified reverse exit.
- Produces: `active_parameter_count(candidate) -> int` and `neighbors(candidate) -> list[Candidate]`.
- Produces: `TrainingSelector(labels, top_per_family).consider(candidate, metrics_by_year)`.
- Produces: `run_walk_forward_search(data, config, progress) -> SearchOutcome`.

- [ ] **Step 1: Write failing uniqueness and leakage tests**

```python
def test_factory_produces_unique_valid_candidates():
    candidates = list(CandidateFactory(20260716).iter_unique(20_000))
    assert len(candidates) == 20_000
    assert len({candidate.key() for candidate in candidates}) == 20_000
    assert max(map(active_parameter_count, candidates)) <= 8
    assert set(candidate.family for candidate in candidates) == EXPECTED_FAMILIES


def test_training_selector_cannot_receive_validation_metrics():
    selector = TrainingSelector(labels=("2021", "2022"), top_per_family=10)
    with pytest.raises(ValueError, match="unexpected metric label"):
        selector.consider(candidate(), {"2021": metrics(), "2022": metrics(), "2026YTD": metrics()})


def test_final_top3_is_frozen_before_2026_is_attached():
    selected = freeze_final_top3(training_records())
    attached = attach_validation(selected, reversed_2026_results())
    assert [item.candidate.key() for item in attached] == [item.candidate.key() for item in selected]
```

- [ ] **Step 2: Run tests and verify missing search components**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_search.py -q`

Expected: failures identify missing factory and selectors.

- [ ] **Step 3: Implement balanced candidate generation**

Cycle evenly through the ten declared strategy families. Draw only from declared finite parameter sets; omit inactive keys; reject invalid MA/MACD/KDJ thresholds; cap active tunables at eight; preserve the fixed seed. Generate the 800,000-candidate broad universe before evaluating returns.

- [ ] **Step 4: Implement efficient fold selection**

Evaluate independent annual metrics for 2021-2025 in vectorized batches of 1024. Maintain per-family heaps for training windows `2021`, `2021-2022`, `2021-2023`, `2021-2024`, and `2021-2025`; each heap receives only those labels. Validate each fold winner on the next year without reranking. Generate local neighbors from each fold's family Top10 using only that fold's training metrics; neighbors may validate only on later unseen periods.

- [ ] **Step 5: Implement training-only final ranking**

Filter and rank 2021-2025 candidates by minimum annual return, positive-year count, drawdown, Calmar/Sortino proxy, Wilson lower bound, Profit Factor, cost ratio, and trade-frequency penalty. Freeze three different families before loading 2026 metrics. Never replace a failed Top3 candidate with a candidate chosen from 2026 results.

- [ ] **Step 6: Run search tests and commit**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_search.py -q`

Expected: all tests pass.

Commit: `git add scripts/qqq_research scripts/tests/test_qqq_research_search.py && git commit -m "feat: add strict QQQ walk-forward search"`

### Task 5: Stability Audit, Report, And CLI

**Files:**
- Create: `scripts/qqq_research/audit.py`
- Create: `scripts/qqq_research/report.py`
- Create: `scripts/research_qqq_robust_tmp.py`
- Test: `scripts/tests/test_qqq_research_report.py`

**Interfaces:**
- Produces: `audit_candidate(candidate, data, outcome) -> AuditResult`.
- Produces: `deduplicate_families(records) -> list[CandidateRecord]`.
- Produces: `build_report(outcome) -> dict[str, object]` and `render_markdown(report) -> str`.
- CLI accepts `--stage1`, `--seed`, `--batch-size`, `--data`, `--output`, `--report`, `--progress`, and `--smoke`.

- [ ] **Step 1: Write failing audit/report tests**

```python
def test_trade_path_dedup_keeps_one_representative():
    records = [record("ma_cross", [1, 5, 10]), record("ma_cross", [1, 5, 10, 11])]
    assert len(deduplicate_families(records)) == 1


def test_report_contains_required_audit_declarations():
    report = build_report(minimal_outcome())
    assert report["audit"]["future_function"] is False
    assert report["audit"]["used_2026_for_tuning"] is False
    assert report["audit"]["validation_2026_status"] == "reused_holdout"
    assert report["counts"]["unique_tested"] >= report["counts"]["requested_stage1"]
```

- [ ] **Step 2: Run report tests and verify missing outputs**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests/test_qqq_research_report.py -q`

Expected: failures identify missing audit and report modules.

- [ ] **Step 3: Implement robustness audits**

For each frozen Top3 and current App baseline, run parameter neighbors at plus/minus 10%, one-factor-at-a-time ablation, double slippage/commission/borrow stress, and removal of the best completed trade. Calculate trade-date Jaccard overlap and daily-return correlation for deduplication. Record every failed hard constraint without silently relaxing it.

- [ ] **Step 4: Implement JSON and Chinese Markdown reports**

Include frozen data metadata/hash, exact unique count, per-family count, fold training/validation counts, current App comparison, frozen Top3, independent years, full continuous run, stitched walk-forward, trade details, costs, Wilson interval, Profit Factor, expectancy, best-trade share, neighborhood, ablation, stress results, family dedup, and all audit declarations.

- [ ] **Step 5: Implement CLI and smoke mode**

`--smoke` must use 2,000 candidates, retain the same event engine, write separate smoke artifacts, and never overwrite formal outputs. Progress JSON must record stage, completed count, total count, elapsed seconds, and frozen data hash.

- [ ] **Step 6: Run focused and full tests, then commit**

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests -q`

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest -q`

Expected: all research tests and the existing backend suite pass.

Commit: `git add scripts/qqq_research scripts/research_qqq_robust_tmp.py scripts/tests && git commit -m "feat: add robust QQQ research pipeline"`

### Task 6: Smoke Run, Formal 800k Run, And Result Verification

**Files:**
- Generate: `scripts/research_qqq_robust_data.json`
- Generate: `scripts/research_qqq_robust_tmp_smoke.json`
- Generate: `scripts/research_qqq_robust_tmp_smoke.md`
- Generate: `scripts/research_qqq_robust_tmp_result.json`
- Generate: `scripts/research_qqq_robust_tmp_result.md`
- Generate: `scripts/research_qqq_robust_tmp_progress.json`

**Interfaces:**
- Consumes the CLI from Task 5.
- Produces the final auditable artifacts; no production state changes.

- [ ] **Step 1: Freeze and inspect cloud data**

Run: `backend\.venv\Scripts\python.exe scripts/research_qqq_robust_tmp.py --freeze-data --data scripts/research_qqq_robust_data.json`

Expected: output reports `US.QQQ`, earliest date no later than `2020-01-02`, latest complete trading date, row count above 1,600, and a SHA-256 hash.

- [ ] **Step 2: Run smoke search**

Run: `backend\.venv\Scripts\python.exe scripts/research_qqq_robust_tmp.py --smoke --stage1 2000 --data scripts/research_qqq_robust_data.json --output scripts/research_qqq_robust_tmp_smoke.json --report scripts/research_qqq_robust_tmp_smoke.md`

Expected: completed result with exactly 2,000 unique broad candidates, all five walk-forward folds, current App metrics, and three family-distinct frozen candidates when at least three families have records.

- [ ] **Step 3: Audit smoke output mechanically**

Run: `backend\.venv\Scripts\python.exe -m scripts.qqq_research.audit scripts/research_qqq_robust_tmp_smoke.json`

Expected: `audit_ok=true`, `used_2026_for_tuning=false`, no duplicate candidate hashes, and no future-dated trade execution.

- [ ] **Step 4: Run the formal search**

Run: `backend\.venv\Scripts\python.exe scripts/research_qqq_robust_tmp.py --stage1 800000 --seed 20260716 --batch-size 1024 --data scripts/research_qqq_robust_data.json --output scripts/research_qqq_robust_tmp_result.json --report scripts/research_qqq_robust_tmp_result.md --progress scripts/research_qqq_robust_tmp_progress.json`

Expected: progress reaches `done`; `unique_tested >= 800000`; Top3 is frozen from 2021-2025 before 2026 metrics are attached.

- [ ] **Step 5: Verify formal output and rerun tests**

Run: `backend\.venv\Scripts\python.exe -m scripts.qqq_research.audit scripts/research_qqq_robust_tmp_result.json`

Run: `backend\.venv\Scripts\python.exe -m pytest scripts/tests -q`

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest -q`

Expected: audit passes; research and backend tests pass.

- [ ] **Step 6: Review results without changing strategy selection**

Read the final JSON/Markdown, compare frozen Top3 against the current App QQQ strategy, list every failed hard constraint, and explain 2026 degradation without reranking or tuning. Do not deploy or edit App strategy files.
