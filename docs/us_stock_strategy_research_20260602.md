# App 个股专属策略记录

## 2026-06-06 下一轮重测任务

当前文档记录的是 App 已写入的个股专属策略模板。下一步任务是把这些原有模板重新按统一口径回测一遍，再由用户决定是否替换。

2026-06-06 更新：`US.QQQ` 已按统一研究口径替换稳健型和进取型 Top1；`US.NVDA` 进取型已替换为无 SPY 的通道 + ATR Top1。搜索只使用 `2021-2025`，`2026YTD` 仅作为最终验证段；本次同步更新后端模板、后端测试和本文档。

2026-06-07 更新：`US.AMD` 已按统一口径替换稳健型 Top2（`AMD SMA8/44 稳健型`）和进取型 Top1（`AMD 20 日通道进取型`）。本次搜索均只使用 `2021-2025` 筛选，`2026YTD` 仅做最终验证；同步更新后端模板、后端测试和本文档。

重测范围：

- `US.GOOGL`
- `US.QQQ`
- `US.NVDA`
- `US.AMD`
- `US.MU`
- `US.DELL`
- `US.MSFT`
- `US.AAOI`

推荐回测口径：

1. 数据区间使用 `2021-01-04` 到最新可用交易日。
2. 先用 `2021-2025` 作为寻找候选策略区间，再用 `2026YTD` 做验证；禁止用 2026 反向调参后再宣称验证通过。
3. 年度分段至少输出 `2022`、`2023`、`2024`、`2025`、`2026YTD`。
4. 成交口径为第 T 日收盘生成信号，第 T+1 个交易日开盘成交；区间结束仍持仓时按最后一个可用收盘价强制平仓统计。
5. 收益必须扣除单边滑点和交易费用。美股默认使用单边滑点 `0.05%`、佣金 `0.138%` 且单笔最低 `18 USD`；卖出侧 SEC fee / TAF 如使用近似模型必须说明。
6. 每个候选至少输出净收益、最大回撤、胜率、买卖回合、多/空次数、最低年度收益、年度最大回撤。
7. 如果用户要求“稳健型”，排序优先低回撤和年度均衡；如果用户要求“进取型”，排序优先全周期收益，但仍需满足回撤和胜率约束。
8. 任何策略写入 App 前，必须同步更新后端模板、后端测试和本文档。

最后更新：2026-06-07

范围：记录当前 App 后端 `backend/app/services/personalized_strategies.py` 中的美股个股专属策略模板。本文档用于对照 App 里的“个股专属策略”，不是交易建议，也不写入 App 回测历史。

当前覆盖标的：`US.GOOGL`、`US.QQQ`、`US.NVDA`、`US.AMD`、`US.MU`、`US.DELL`、`US.AAOI`、`US.MSFT`。

统一口径：

- 基准标的：`US.QQQ`。
- 信号口径：日线收盘产生策略状态，App 扫描时展示今日预估信号和昨日收盘信号。
- 回测口径：研究回测按第 T 日收盘生成信号、第 T+1 个交易日开盘成交，计入滑点和手续费。
- `direction_mode = long_short` 表示允许做多和做空；`direction_mode = long_only` 表示只做多。
- 参数不存在表示该条件不启用。例如没有 `fixed_stop` 就是不使用固定止损。
- 默认模板：用户用股票代码直接扫描时，优先返回该标的稳健型模板；进取型通过模板 `code` 单独扫描。

## 总览

| 标的 | 默认模板 | 稳健型 | 进取型 |
|---|---|---|---|
| `US.GOOGL` | `personal_googl_sma5_113_steady` | `GOOGL SMA5/113 相对强弱（稳健型）` | `GOOGL SMA5/116 样本增强进取型` |
| `US.QQQ` | `personal_qqq_sma7_111_steady` | `QQQ SMA7/111 稳健型` | `QQQ SMA12/101 进取型` |
| `US.NVDA` | `personal_nvda_ma30_40_steady` | `NVDA MA30/40 稳定型` | `NVDA 15日通道 ATR 趋势突破（进取型）` |
| `US.AMD` | `personal_amd_ma10_20_steady` | `AMD SMA8/44 稳健型` | `AMD 20 日通道进取型` |
| `US.MU` | `personal_mu_sma24_40_steady` | `MU SMA24/40 稳健型` | `MU SMA22/30 进取型` |
| `US.DELL` | `personal_dell_channel19_steady` | `DELL 19 日通道稳健型` | `DELL 42 日通道进取型` |
| `US.AAOI` | `personal_aaoi_sma37_53_steady` | `AAOI SMA37/53 稳健型` | `AAOI SMA5/30 进取型` |
| `US.MSFT` | `personal_msft_channel61_steady` | `MSFT 54 日通道稳健型（最接近）` | `MSFT 59 日通道 ATR 进取型` |

## GOOGL

### `personal_googl_sma5_113_aggressive`

名称：GOOGL SMA5/116 样本增强进取型

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 5
long_window = 116
trend_ma = 100
benchmark_ma = 200
benchmark_roc_days = 120
benchmark_roc_min = -0.02
fixed_stop = 0.06
trailing_stop = 0.16
take_profit = 0.24
max_hold_days = 60
filtered_reverse_exit = true
```

入场规则：

```text
做多：SMA5 上穿 SMA116，且 GOOGL 高于 SMA100，QQQ 高于 SMA200。
QQQ 120 日动量大于 -2%。
做空为对称条件：SMA5 下穿 SMA116，趋势与 QQQ 动量均转弱。
```

退出规则：

```text
出现合格反向均线交叉信号。
固定止损 6%，移动止损 16%，止盈 24%，或虚拟持仓满 60 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +44.81% | -7.45% | 100.00% | 2 |
| 2023 | +31.34% | -6.66% | 100.00% | 2 |
| 2024 | +37.36% | -9.28% | 100.00% | 2 |
| 2025 | +23.00% | -6.62% | 50.00% | 2 |
| 2026YTD | +14.61% | -14.59% | 50.00% | 2 |

### `personal_googl_sma5_113_steady`

名称：GOOGL SMA5/113 相对强弱（稳健型）

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 5
long_window = 113
trend_ma = 100
benchmark_ma = 120
own_roc_days = 80
own_roc_min = 0.02
relative_strength_days = 20
relative_strength_min = -0.08
exit_ma = 150
fixed_stop = 0.12
trailing_stop = 0.10
take_profit = 0.20
max_hold_days = 40
```

入场规则：

```text
做多：SMA5 上穿 SMA113，且 GOOGL 高于 SMA100，QQQ 高于 SMA120。
GOOGL 80 日动量大于 2%，且 GOOGL 20 日相对 QQQ 强弱不弱于 -8%。
做空为对称条件：SMA5 下穿 SMA113，趋势、动量与相对强弱均转弱。
```

退出规则：

```text
反向均线交叉，或跌破/站回 SMA150。
固定止损 12%，移动止损 10%，止盈 20%，或虚拟持仓满 40 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +22.49% | -5.17% | 100.00% | 1 |
| 2023 | +22.27% | -6.67% | 100.00% | 2 |
| 2024 | +30.16% | -4.21% | 100.00% | 2 |
| 2025 | +14.37% | -3.77% | 100.00% | 1 |
| 2026YTD | +21.72% | -2.75% | 100.00% | 2 |

## QQQ

### `personal_qqq_sma7_111_steady`

名称：QQQ SMA7/111 稳健型

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

全周期研究结果：收益 `+98.59%`，最大回撤 `-7.43%`，胜率 `88.89%`，完整买卖回合 `9`，多/空次数 `5 / 4`。

参数：

```text
short_window = 7
long_window = 111
benchmark_ma = 120
own_roc_days = 20
own_roc_min = 0.02
exit_ma = 150
fixed_stop = 0.10
trailing_stop = 0.10
take_profit = 0.14
filtered_reverse_exit = true
```

入场规则：

```text
做多：SMA7 上穿 SMA111，且 QQQ 高于 SMA120。
QQQ 20 日动量大于 2%。
做空为对称条件：SMA7 下穿 SMA111，且 QQQ 低于 SMA120，QQQ 20 日动量低于 -2%。
```

说明：标的和基准同为 `US.QQQ`，相对强弱项不提供额外区分度，因此本模板不启用相对强弱过滤。

退出规则：

```text
出现合格反向 SMA7/SMA111 均线交叉信号，或跌破/站回 SMA150。
固定止损 10%，移动止损 10%，止盈 14%。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +16.21% | -6.81% | 100.00% | 3 |
| 2023 | +15.63% | -7.43% | 100.00% | 1 |
| 2024 | +12.92% | -3.42% | 50.00% | 2 |
| 2025 | +14.57% | -2.94% | 100.00% | 2 |
| 2026YTD | +14.23% | -2.54% | 100.00% | 1 |

### `personal_qqq_sma12_101_aggressive`

名称：QQQ SMA12/101 进取型

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

全周期研究结果：收益 `+194.56%`，最大回撤 `-13.37%`，胜率 `100.00%`，完整买卖回合 `9`，多/空次数 `6 / 3`。

参数：

```text
short_window = 12
long_window = 101
trend_ma = 50
benchmark_ma = 150
own_roc_days = 80
own_roc_min = -0.12
take_profit = 0.12
filtered_reverse_exit = true
use_trend_ma_as_exit = false
```

入场规则：

```text
做多：SMA12 上穿 SMA101，且 QQQ 高于 SMA50 与 SMA150。
QQQ 80 日动量大于 -12%。
做空为对称条件：SMA12 下穿 SMA101，且 QQQ 低于 SMA50 与 SMA150，QQQ 80 日动量低于 12%。
```

说明：`trend_ma = 50` 只作为进场趋势过滤，不作为退出均线；因此写入 `use_trend_ma_as_exit = false` 以匹配研究公式。

退出规则：

```text
出现合格反向 SMA12/SMA101 均线交叉信号。
止盈 12%；不启用固定止损、移动止损、退出均线或最大持仓天数。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +26.60% | -13.37% | 100.00% | 2 |
| 2023 | +18.24% | -7.43% | 100.00% | 2 |
| 2024 | +25.23% | -7.01% | 100.00% | 2 |
| 2025 | +30.71% | -5.12% | 100.00% | 2 |
| 2026YTD | +12.68% | -2.54% | 100.00% | 1 |

## NVDA

### `personal_nvda_channel35`

名称：NVDA 15日通道 ATR 趋势突破（进取型）

方向：`long_short`
仓位：`1.0`
引擎：`channel`

参数：

```text
entry_channel_days = 15
exit_channel_days = 57
benchmark_ma = 80
benchmark_ma_kind = ema
benchmark_roc_days = 60
benchmark_roc_min = 0.02
own_roc_days = 80
own_roc_min = -0.08
relative_strength_days = 80
relative_strength_min = 0.0
own_slope_days = 20
own_slope_min = 0.0015
benchmark_slope_days = 20
benchmark_slope_min = 0.0005
atr_days = 50
atr_pct_min = 0.01
atr_pct_max = 0.06
volume_window = 20
volume_ratio_min = 0.8
exit_ma = 40
exit_ma_kind = sma
fixed_stop = 0.2
trailing_stop = 0.24
take_profit = 0.2
atr_stop_mult = 2.0
atr_trail_mult = 4.0
max_hold_days = 20
filtered_reverse_exit = false
```

入场规则：

```text
做多：收盘突破过去 15 日高点，NVDA 80 日动量不低于 -8%，且 20 日价格斜率不低于 0.15%。
QQQ 高于 EMA80，QQQ 60 日动量大于 2%，20 日价格斜率不低于 0.05%，且 NVDA 80 日相对 QQQ 强弱不低于 0。
ATR50/收盘价位于 1% 到 6%，成交量不低于 20 日均量的 80%；做空为对称条件。
```

退出规则：

```text
反向 15 日通道突破、57 日退出通道、跌破/站回 SMA40，或持仓满 20 个交易日。
固定止损 20%，移动止损 24%，止盈 20%，ATR 止损 2.0 倍，ATR 移动止损 4.0 倍。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +21.83% | -5.67% | 100.00% | 1 |
| 2023 | +71.98% | -11.09% | 83.33% | 6 |
| 2024 | +125.25% | -12.89% | 100.00% | 6 |
| 2025 | +36.32% | -6.62% | 100.00% | 3 |
| 2026YTD | +12.49% | -9.60% | 50.00% | 2 |

研究记录：本策略来自 NVDA 进取型无 SPY 搜索，使用 `2021-2025` 搜索筛选，`2026YTD` 仅作最终验证。搜索实际唯一测试组数 1,006,175，进入年度复核 71,221，通过 2021-2025 训练约束 10,777，通过 2026YTD 最终验证 1,467，最终满足全部硬约束 1,236。全周期净收益 +802.68%，最大回撤 -13.69%，胜率 78.26%，完整买卖回合 23，多头 21 次、空头 2 次。当前 App 旧进取策略同口径复核全周期净收益 +439.19%、最大回撤 -34.72%，未满足本次进取型硬约束。

### `personal_nvda_ma30_40_steady`

名称：NVDA MA30/40 稳定型

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 30
long_window = 40
trend_ma = 150
benchmark_ma = 50
own_roc_days = 20
own_roc_min = 0.04
relative_strength_days = 80
relative_strength_min = -0.02
exit_ma = 80
fixed_stop = 0.10
trailing_stop = 0.24
take_profit = 0.16
max_hold_days = 15
filtered_reverse_exit = true
```

入场规则：

```text
做多：SMA30 上穿 SMA40，且 NVDA 高于 SMA150，QQQ 高于 SMA50。
NVDA 20 日动量大于 4%，且 NVDA 80 日动量相对 QQQ 不弱于 -2%。
做空为对称条件：SMA30 下穿 SMA40，趋势、基准、动量和相对强弱均转弱。
```

退出规则：

```text
出现合格反向均线交叉信号，或跌破/站回 SMA80。
固定止损 10%，移动止损 24%，止盈 16%，或虚拟持仓满 15 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +18.26% | -2.82% | 100.00% | 1 |
| 2023 | +12.29% | -10.08% | 100.00% | 1 |
| 2024 | +56.22% | -7.62% | 100.00% | 3 |
| 2025 | +37.93% | -2.86% | 100.00% | 2 |
| 2026YTD | +13.10% | -9.28% | 100.00% | 1 |

## AMD

### `personal_amd_ma10_20_steady`

名称：AMD SMA8/44 稳健型

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 8
long_window = 44
benchmark_roc_days = 60
benchmark_roc_min = -0.04
relative_strength_days = 40
relative_strength_min = -0.03
exit_ma = 30
exit_ma_kind = sma
trailing_stop = 0.10
take_profit = 0.06
atr_days = 10
atr_stop_mult = 2.0
filtered_reverse_exit = true
```

入场规则：

```text
做多：SMA8 上穿 SMA44，且 QQQ 60 日动量大于 -4%。
AMD 40 日相对 QQQ 强弱大于 -3%。
做空为对称条件：SMA8 下穿 SMA44，且 QQQ 60 日动量小于 4%、AMD 相对 QQQ 强弱转弱。
```

退出规则：

```text
出现合格反向均线交叉信号，或价格跌破/站回 SMA30。
移动止损 10%，止盈 6%，ATR10 止损 2.0 倍。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +12.61% | -7.66% | 100.00% | 2 |
| 2023 | +11.03% | -2.33% | 100.00% | 2 |
| 2024 | +10.34% | -1.91% | 100.00% | 1 |
| 2025 | +14.08% | -4.41% | 100.00% | 2 |
| 2026YTD | +19.82% | -0.60% | 100.00% | 2 |

研究记录：本策略来自 AMD 稳健型搜索 Top2。搜索使用 `2021-2025` 筛选，`2026YTD` 仅作最终验证。实际唯一测试组数 801,461，进入年度复核 18,601，通过 2021-2025 训练约束 30，通过 2026YTD 最终验证 13，最终满足全周期最大回撤 ≤15% 的策略 5 个；本策略全周期净收益 +113.20%，最大回撤 -7.66%，胜率 92.31%，完整买卖回合 13，多头 7 次、空头 6 次。选择 Top2 而非名义 Top1，是因为 Top2 交易样本更多，更适合作为 App 稳健型指引。

### `personal_amd_channel66_aggressive`

名称：AMD 20 日通道进取型

方向：`long_short`
仓位：`1.0`
引擎：`channel`

参数：

```text
entry_channel_days = 20
exit_channel_days = 16
trend_ma = 200
trend_ma_kind = sma
benchmark_roc_days = 120
benchmark_roc_min = 0.0
own_roc_days = 60
own_roc_min = 0.04
relative_strength_days = 60
relative_strength_min = 0.06
atr_days = 20
atr_pct_max = 0.06
exit_ma = 200
exit_ma_kind = ema
fixed_stop = 0.10
trailing_stop = 0.12
```

入场规则：

```text
做多：收盘突破过去 20 日高点，且 AMD 高于 SMA200。
QQQ 120 日动量大于 0%，AMD 60 日动量大于 4%，AMD 60 日相对 QQQ 强弱大于 6%，ATR20% 不高于 6%。
做空为对称条件：跌破过去 20 日低点，且趋势、动量、相对强弱和 ATR% 过滤均转弱或可接受。
```

退出规则：

```text
反向 16 日通道突破，或价格跌破/站回 EMA200。
固定止损 10%，移动止损 12%。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +37.00% | -12.89% | 100.00% | 3 |
| 2023 | +43.94% | -14.54% | 100.00% | 3 |
| 2024 | +26.14% | -8.89% | 100.00% | 1 |
| 2025 | +76.29% | -18.28% | 66.67% | 3 |
| 2026YTD | +131.95% | -9.75% | 100.00% | 1 |

研究记录：本策略来自 AMD 进取型搜索 Top1。搜索使用 `2021-2025` 筛选，`2026YTD` 仅作最终验证。实际唯一测试组数 801,480，进入年度复核 21,480，通过 2021-2025 训练约束 302，通过 2026YTD 最终验证 147，最终满足全部进取型硬约束 135。全周期净收益 +1158.38%，最大回撤 -18.28%，胜率 81.82%，完整买卖回合 11，多头 7 次、空头 4 次。当前 App 旧进取策略同口径复核全周期净收益 +145.82%、最大回撤 -24.83%、胜率 64.00%，未满足本次进取型硬约束。

## MU

### `personal_mu_sma24_40_steady`

名称：MU SMA24/40 稳健型

方向：`long_short`
仓位：`0.8`
引擎：`ma_cross`

参数：

```text
short_window = 24
long_window = 40
trend_ma = 150
benchmark_ma = 120
own_roc_days = 120
own_roc_min = 0.02
relative_strength_days = 80
relative_strength_min = 0.06
exit_ma = 150
trailing_stop = 0.10
take_profit = 0.16
```

入场规则：

```text
做多：SMA24 上穿 SMA40，且 MU 高于 SMA150。
QQQ 高于 SMA120，MU 120 日动量大于 2%，且 MU 80 日相对 QQQ 强弱大于 6%。
做空为对称条件：SMA24 下穿 SMA40，且 MU 低于 SMA150、QQQ 低于 SMA120、MU 动量与相对强弱转弱。
```

退出规则：

```text
反向 SMA24/SMA40 均线交叉。
跌破或站回 SMA150，移动止损 10%，或止盈 16%。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +19.15% | -6.54% | 100.00% | 2 |
| 2023 | +14.57% | -5.68% | 100.00% | 1 |
| 2024 | +16.28% | -4.01% | 100.00% | 1 |
| 2025 | +16.34% | 0.00% | 100.00% | 1 |
| 2026YTD | +24.55% | -0.20% | 100.00% | 1 |

### `personal_mu_channel48_aggressive`

名称：MU SMA22/30 进取型

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 22
long_window = 30
benchmark_ma = 150
take_profit = 0.08
filtered_reverse_exit = true
```

入场规则：

```text
做多：SMA22 上穿 SMA30，且 QQQ 高于 SMA150。
做空为对称条件：SMA22 下穿 SMA30，且 QQQ 低于 SMA150。
```

退出规则：

```text
出现合格反向 SMA22/SMA30 均线交叉信号。
单笔达到 8% 止盈时退出；区间结束仍持仓则按最后收盘价强制平仓。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +72.55% | -18.20% | 100.00% | 6 |
| 2023 | +32.96% | -15.61% | 100.00% | 3 |
| 2024 | +30.56% | -8.63% | 80.00% | 5 |
| 2025 | +58.20% | -5.35% | 100.00% | 5 |
| 2026YTD | +41.34% | -3.69% | 100.00% | 3 |

## DELL

### `personal_dell_channel19_steady`

名称：DELL 19 日通道稳健型

方向：`long_only`
仓位：`0.8`
引擎：`channel`

参数：

```text
entry_channel_days = 19
exit_channel_days = 73
trend_ma = 100
benchmark_roc_days = 20
benchmark_roc_min = 0.06
own_roc_days = 20
own_roc_min = 0.06
relative_strength_days = 20
relative_strength_min = 0.02
trailing_stop = 0.10
take_profit = 0.16
max_hold_days = 20
```

入场规则：

```text
做多：DELL 收盘价突破过去 19 日高点，且 DELL 高于 SMA100。
QQQ 20 日动量大于 6%，DELL 20 日动量大于 6%，且 DELL 20 日相对 QQQ 强弱大于 2%。
该模板只做多，不生成做空信号。
```

退出规则：

```text
跌破过去 73 日低点。
移动止损 10%，止盈 16%，或虚拟持仓满 20 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +4.76% | -5.55% | 100.00% | 1 |
| 2023 | +13.09% | -6.22% | 100.00% | 2 |
| 2024 | +14.70% | -2.83% | 100.00% | 1 |
| 2025 | +27.48% | -4.84% | 100.00% | 3 |
| 2026YTD | +61.40% | -8.01% | 75.00% | 4 |

### `personal_dell_channel42_aggressive`

名称：DELL 42 日通道进取型

方向：`long_only`
仓位：`0.9`
引擎：`channel`

参数：

```text
entry_channel_days = 42
exit_channel_days = 70
benchmark_roc_days = 20
benchmark_roc_min = 0.0
fixed_stop = 0.16
trailing_stop = 0.16
take_profit = 0.12
max_hold_days = 50
```

入场规则：

```text
做多：DELL 收盘价突破过去 42 日高点。
QQQ 20 日动量大于 0%。
该模板只做多，不生成做空信号。
```

退出规则：

```text
跌破过去 70 日低点。
固定止损 16%，移动止损 16%，止盈 12%，或虚拟持仓满 50 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +11.16% | -3.42% | 100.00% | 1 |
| 2023 | +39.20% | -9.80% | 100.00% | 4 |
| 2024 | +65.49% | -15.30% | 80.00% | 5 |
| 2025 | +46.93% | -13.19% | 100.00% | 3 |
| 2026YTD | +65.58% | -8.86% | 75.00% | 4 |

## AAOI

### `personal_aaoi_sma37_53_steady`

名称：AAOI SMA37/53 稳健型

方向：`long_only`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 37
long_window = 53
trend_ma = 50
benchmark_ma = 80
relative_strength_days = 40
relative_strength_min = 0.0
exit_ma = 120
fixed_stop = 0.08
take_profit = 0.08
max_hold_days = 60
```

入场规则：

```text
做多：SMA37 上穿 SMA53。
AAOI 高于 SMA50，QQQ 高于 SMA80，AAOI 40 日相对 QQQ 强弱大于 0。
该模板只做多，不生成做空信号。
```

退出规则：

```text
SMA37 下穿 SMA53。
跌破 SMA120，固定止损 8%，止盈 8%，或虚拟持仓满 60 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +12.47% | 0.00% | 100.00% | 1 |
| 2023 | +44.25% | -4.99% | 100.00% | 3 |
| 2024 | +12.61% | 0.00% | 100.00% | 1 |
| 2025 | +11.43% | -2.39% | 50.00% | 2 |
| 2026YTD | +14.50% | 0.00% | 100.00% | 1 |

### `personal_aaoi_sma5_30_aggressive`

名称：AAOI SMA5/30 进取型

方向：`long_only`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 5
long_window = 30
trend_ma = 100
own_roc_days = 60
own_roc_min = 0.0
exit_ma = 120
fixed_stop = 0.12
trailing_stop = 0.16
take_profit = 0.20
max_hold_days = 60
```

入场规则：

```text
做多：SMA5 上穿 SMA30。
AAOI 高于 SMA100，AAOI 60 日动量大于 0。
该模板只做多，不生成做空信号。
```

退出规则：

```text
SMA5 下穿 SMA30。
跌破 SMA120，固定止损 12%，移动止损 16%，止盈 20%，或虚拟持仓满 60 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +38.92% | -5.65% | 100.00% | 1 |
| 2023 | +25.99% | -3.23% | 100.00% | 1 |
| 2024 | +48.40% | -10.66% | 66.67% | 3 |
| 2025 | +45.27% | -9.69% | 100.00% | 2 |
| 2026YTD | +18.26% | -1.56% | 100.00% | 1 |

## MSFT

### `personal_msft_channel61_steady`

名称：MSFT 54 日通道稳健型（最接近）

方向：`long_short`
仓位：`1.0`
引擎：`channel`

参数：

```text
entry_channel_days = 54
exit_channel_days = 58
trend_ma = 150
trend_ma_kind = ema
benchmark_roc_days = 80
benchmark_roc_min = -0.08
own_roc_days = 120
own_roc_min = -0.02
relative_strength_days = 60
relative_strength_min = 0.06
fixed_stop = 0.08
take_profit = 0.10
```

入场规则：

```text
做多：MSFT 收盘价突破过去 54 日高点，且 MSFT 高于 EMA150。
QQQ 80 日动量大于 -8%，MSFT 120 日动量大于 -2%，MSFT 60 日相对 QQQ 强弱大于 6%。
做空为对称条件：MSFT 跌破过去 54 日低点，且 MSFT 低于 EMA150，QQQ 80 日动量小于 8%，MSFT 120 日动量小于 2%，MSFT 60 日相对 QQQ 强弱小于 -6%。
```

退出规则：

```text
反向 58 日通道突破。
固定止损 8%，或止盈 10%。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +10.61% | -9.61% | 100.00% | 1 |
| 2023 | +33.71% | -5.60% | 100.00% | 3 |
| 2024 | +9.45% | -9.33% | 100.00% | 1 |
| 2025 | +21.74% | -10.14% | 75.00% | 4 |
| 2026YTD | +11.06% | -11.39% | 66.67% | 3 |

### `personal_msft_channel59_aggressive`

名称：MSFT 59 日通道 ATR 进取型

方向：`long_short`
仓位：`1.0`
引擎：`channel`

参数：

```text
entry_channel_days = 59
exit_channel_days = 73
trend_ma = 200
trend_ma_kind = sma
own_roc_days = 120
own_roc_min = -0.04
relative_strength_days = 60
relative_strength_min = 0.04
atr_days = 50
atr_pct_max = 0.03
exit_ma = 200
exit_ma_kind = ema
take_profit = 0.10
max_hold_days = 60
```

入场规则：

```text
做多：MSFT 收盘价突破过去 59 日高点，且 MSFT 高于 SMA200。
MSFT 120 日动量大于 -4%，MSFT 60 日相对 QQQ 强弱大于 4%，且 ATR50/收盘价不高于 3%。
做空为对称条件：MSFT 跌破过去 59 日低点，且 MSFT 低于 SMA200，MSFT 120 日动量小于 4%，MSFT 60 日相对 QQQ 强弱小于 -4%，且 ATR50/收盘价不高于 3%。
```

退出规则：

```text
反向 73 日通道突破，或价格跌破/站回 EMA200。
止盈 10%，或虚拟持仓满 60 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +10.61% | -9.61% | 100.00% | 1 |
| 2023 | +34.96% | -5.60% | 100.00% | 3 |
| 2024 | +10.05% | -9.33% | 100.00% | 2 |
| 2025 | +31.15% | -7.44% | 75.00% | 4 |
| 2026YTD | +13.11% | -8.22% | 66.67% | 3 |

## 维护要求

- 本文档必须随 `backend/app/services/personalized_strategies.py` 中的 `_TEMPLATES` 同步更新。
- 新增、替换或删除个股专属策略时，需要同步更新总览表、参数、入场规则、退出规则和分段记录。
- 若某些参数在研究脚本里用 `0` 表示“不启用”，写入 App 和本文档时应按实际 App 扫描逻辑处理：不启用的参数不写入模板，避免被扫描器当作真实条件执行。
