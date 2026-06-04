# App 个股专属策略记录

最后更新：2026-06-05

范围：记录当前 App 后端 `backend/app/services/personalized_strategies.py` 中的美股个股专属策略模板。本文档用于对照 App 里的“个股专属策略”，不是交易建议，也不写入 App 回测历史。

当前覆盖标的：`US.GOOGL`、`US.QQQ`、`US.NVDA`、`US.AMD`、`US.MU`、`US.DELL`、`US.AAOI`。

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
| `US.GOOGL` | `personal_googl_sma5_113_steady` | `GOOGL SMA5/113 相对强弱（稳健型）` | `GOOGL SMA5/113 趋势交叉（进取型）` |
| `US.QQQ` | `personal_qqq_sma34_77_steady` | `QQQ SMA34/77 稳健型` | `QQQ 41 日通道进取型` |
| `US.NVDA` | `personal_nvda_ma30_40_steady` | `NVDA MA30/40 稳定型` | `NVDA 35日通道趋势突破（进取型）` |
| `US.AMD` | `personal_amd_ma10_20_steady` | `AMD SMA10/20 稳健型` | `AMD 66 日通道进取型` |
| `US.MU` | `personal_mu_sma24_40_steady` | `MU SMA24/40 稳健型` | `MU 48 日通道进取型` |
| `US.DELL` | `personal_dell_channel19_steady` | `DELL 19 日通道稳健型` | `DELL 42 日通道进取型` |
| `US.AAOI` | `personal_aaoi_sma37_53_steady` | `AAOI SMA37/53 稳健型` | `AAOI SMA5/30 进取型` |

## GOOGL

### `personal_googl_sma5_113_aggressive`

名称：GOOGL SMA5/113 趋势交叉（进取型）

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 5
long_window = 113
trend_ma = 100
benchmark_ma = 200
benchmark_roc_days = 120
benchmark_roc_min = 0.0
fixed_stop = 0.12
trailing_stop = 0.12
take_profit = 0.20
max_hold_days = 60
filtered_reverse_exit = true
```

入场规则：

```text
做多：SMA5 上穿 SMA113，且 GOOGL 高于 SMA100，QQQ 高于 SMA200。
QQQ 120 日动量大于 0。
做空为对称条件：SMA5 下穿 SMA113，趋势与 QQQ 动量均转弱。
```

退出规则：

```text
出现合格反向均线交叉信号。
固定止损 12%，移动止损 12%，止盈 20%，或虚拟持仓满 60 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +46.41% | -6.74% | 100.00% | 2 |
| 2023 | +26.96% | -6.67% | 100.00% | 2 |
| 2024 | +31.25% | -9.30% | 100.00% | 2 |
| 2025 | +27.30% | -8.29% | 100.00% | 1 |
| 2026YTD | +10.25% | -14.01% | 50.00% | 2 |

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

### `personal_qqq_sma34_77_steady`

名称：QQQ SMA34/77 稳健型

方向：`long_short`
仓位：`1.0`
引擎：`ma_cross`

参数：

```text
short_window = 34
long_window = 77
trend_ma = 120
benchmark_ma = 80
benchmark_roc_days = 80
benchmark_roc_min = 0.0
relative_strength_days = 60
relative_strength_min = -0.02
exit_ma = 120
trailing_stop = 0.20
take_profit = 0.06
max_hold_days = 60
```

入场规则：

```text
做多：SMA34 上穿 SMA77，且 QQQ 高于 SMA120 与 SMA80。
QQQ 80 日动量大于 0。
做空为对称条件：SMA34 下穿 SMA77，且 QQQ 低于 SMA120 与 SMA80，QQQ 80 日动量转弱。
```

说明：标的和基准同为 `US.QQQ`，相对强弱项只用于保留回测参数口径，不提供额外区分度。

退出规则：

```text
反向 SMA34/SMA77 均线交叉，或跌破/站回 SMA120。
移动止损 20%，止盈 6%，或虚拟持仓满 60 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +11.16% | -7.68% | 100.00% | 2 |
| 2023 | +10.97% | -6.89% | 100.00% | 2 |
| 2024 | +12.89% | -3.27% | 100.00% | 2 |
| 2025 | +13.72% | -5.35% | 100.00% | 1 |
| 2026YTD | +10.93% | -2.61% | 100.00% | 2 |

### `personal_qqq_channel41_aggressive`

名称：QQQ 41 日通道进取型

方向：`long_short`
仓位：`1.0`
引擎：`channel`

参数：

```text
entry_channel_days = 41
exit_channel_days = 65
trend_ma = 200
benchmark_ma = 120
benchmark_roc_days = 40
benchmark_roc_min = 0.0
own_roc_days = 40
own_roc_min = 0.04
relative_strength_days = 20
relative_strength_min = -0.04
exit_ma = 150
fixed_stop = 0.06
trailing_stop = 0.24
take_profit = 0.08
max_hold_days = 30
```

入场规则：

```text
做多：QQQ 收盘价突破过去 41 日高点，且高于 SMA200 与 SMA120。
QQQ 40 日动量大于 0 且大于 4%。
做空为对称条件：跌破过去 41 日低点，且低于 SMA200 与 SMA120，QQQ 40 日动量小于 -4%。
```

说明：标的和基准同为 `US.QQQ`，相对强弱项只用于保留回测参数口径，不提供额外区分度。

退出规则：

```text
反向 65 日通道突破，或跌破/站回 SMA150。
固定止损 6%，移动止损 24%，止盈 8%，或虚拟持仓满 30 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +15.06% | -10.83% | 60.00% | 5 |
| 2023 | +24.43% | -7.71% | 100.00% | 5 |
| 2024 | +18.98% | -5.34% | 100.00% | 4 |
| 2025 | +29.27% | -5.44% | 100.00% | 5 |
| 2026YTD | +12.53% | -7.85% | 66.67% | 3 |

## NVDA

### `personal_nvda_channel35`

名称：NVDA 35日通道趋势突破（进取型）

方向：`long_short`
仓位：`1.0`
引擎：`channel`

参数：

```text
entry_channel_days = 35
exit_channel_days = 50
trend_ma = 200
benchmark_ma = 80
benchmark_roc_days = 40
benchmark_roc_min = 0.03
own_roc_days = 80
own_roc_min = 0.0
relative_strength_days = 80
relative_strength_min = 0.0
exit_ma = 120
fixed_stop = 0.24
trailing_stop = 0.12
max_hold_days = 20
```

入场规则：

```text
做多：收盘突破过去 35 日高点，且价格高于 SMA200。
QQQ 高于 SMA80，QQQ 40 日动量大于 3%，NVDA 80 日强于 QQQ。
做空为对称条件：跌破过去 35 日低点，且趋势、QQQ 动量和相对强弱均转弱。
```

退出规则：

```text
反向 50 日通道突破，或跌破/站回 SMA120。
固定止损 24%，移动止损 12%，或持仓满 20 个交易日。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2023 | +89.03% | -10.10% | 80.00% | 5 |
| 2024 | +92.94% | -12.90% | 100.00% | 4 |
| 2025-2026 | +63.23% | -13.96% | 100.00% | 5 |

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

名称：AMD SMA10/20 稳健型

方向：`long_short`
仓位：`0.8`
引擎：`ma_cross`

参数：

```text
short_window = 10
long_window = 20
trend_ma = 100
benchmark_ma = 100
benchmark_roc_days = 120
benchmark_roc_min = 0.06
own_roc_days = 20
own_roc_min = -0.04
relative_strength_days = 80
relative_strength_min = -0.06
exit_ma = 120
fixed_stop = 0.10
trailing_stop = 0.12
take_profit = 0.08
filtered_reverse_exit = true
```

入场规则：

```text
做多：SMA10 上穿 SMA20，且 AMD 高于 SMA100，QQQ 高于 SMA100，QQQ 120 日动量大于 6%。
AMD 20 日动量大于 -4%，且 AMD 80 日相对 QQQ 强弱大于 -6%。
做空为对称条件：SMA10 下穿 SMA20，AMD 低于 SMA100，QQQ 低于 SMA100，QQQ 120 日动量小于 -6%。
```

退出规则：

```text
出现合格反向均线交叉信号，或价格跌破/站回 SMA120。
固定止损 10%，移动止损 12%，止盈 8%。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +16.97% | -5.34% | 100.00% | 2 |
| 2023 | +13.13% | -2.51% | 100.00% | 2 |
| 2024 | +11.47% | -1.39% | 100.00% | 1 |
| 2025 | +34.49% | -2.41% | 100.00% | 2 |
| 2026YTD | +10.10% | -7.17% | 100.00% | 1 |

### `personal_amd_channel66_aggressive`

名称：AMD 66 日通道进取型

方向：`long_short`
仓位：`1.0`
引擎：`channel`

参数：

```text
entry_channel_days = 66
exit_channel_days = 43
trend_ma = 80
benchmark_ma = 50
benchmark_roc_days = 120
benchmark_roc_min = 0.04
own_roc_days = 60
own_roc_min = 0.08
relative_strength_days = 80
relative_strength_min = 0.06
fixed_stop = 0.24
trailing_stop = 0.10
take_profit = 0.20
```

入场规则：

```text
做多：收盘突破过去 66 日高点，且 AMD 高于 SMA80，QQQ 高于 SMA50。
QQQ 120 日动量大于 4%，AMD 60 日动量大于 8%，且 AMD 80 日相对 QQQ 强弱大于 6%。
做空为对称条件：跌破过去 66 日低点，趋势、市场动量、AMD 动量与相对强弱均转弱。
```

退出规则：

```text
反向 43 日通道突破。
固定止损 24%，移动止损 10%，止盈 20%。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +10.71% | -16.93% | 66.67% | 3 |
| 2023 | +54.99% | -10.39% | 100.00% | 4 |
| 2024 | +11.69% | -12.74% | 50.00% | 2 |
| 2025 | +46.43% | -18.31% | 75.00% | 4 |
| 2026YTD | +92.76% | -8.02% | 100.00% | 3 |

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

名称：MU 48 日通道进取型

方向：`long_short`
仓位：`1.0`
引擎：`channel`

参数：

```text
entry_channel_days = 48
exit_channel_days = 25
trend_ma = 100
benchmark_ma = 150
benchmark_roc_days = 120
benchmark_roc_min = 0.08
own_roc_days = 20
own_roc_min = -0.08
relative_strength_days = 20
relative_strength_min = -0.06
exit_ma = 100
trailing_stop = 0.24
take_profit = 0.08
```

入场规则：

```text
做多：收盘突破过去 48 日高点，且 MU 高于 SMA100。
QQQ 高于 SMA150，QQQ 120 日动量大于 8%，MU 20 日动量不弱于 -8%，且 MU 20 日相对 QQQ 强弱不弱于 -6%。
做空为对称条件：跌破过去 48 日低点，且趋势、QQQ 趋势/动量、MU 动量与相对强弱均转弱。
```

退出规则：

```text
反向 25 日通道突破。
跌破或站回 SMA100，移动止损 24%，或止盈 8%。
```

分段记录：

| 年度 | 收益 | 最大回撤 | 胜率 | 回合 |
|---|---:|---:|---:|---:|
| 2022 | +38.83% | -17.11% | 100.00% | 3 |
| 2023 | +29.27% | -4.26% | 100.00% | 3 |
| 2024 | +29.86% | -16.61% | 80.00% | 5 |
| 2025 | +110.40% | -15.80% | 87.50% | 8 |
| 2026YTD | +142.68% | -15.21% | 85.71% | 7 |

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

## 维护要求

- 本文档必须随 `backend/app/services/personalized_strategies.py` 中的 `_TEMPLATES` 同步更新。
- 新增、替换或删除个股专属策略时，需要同步更新总览表、参数、入场规则、退出规则和分段记录。
- 若某些参数在研究脚本里用 `0` 表示“不启用”，写入 App 和本文档时应按实际 App 扫描逻辑处理：不启用的参数不写入模板，避免被扫描器当作真实条件执行。
