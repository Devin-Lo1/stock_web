# App 后续开发方案

最后更新：2026-05-25

本文档用于持续记录“下一步怎么做”。每次完成重要功能后，应更新本文件，让新接手者知道当前最优先的开发内容、依赖关系和验收标准。

## 0. 当前接手重点

当前最新接手入口是：

```text
docs/APP新开发者接手指南.md
docs/APP服务器部署与Futu交接说明.md
```

2026-05-25 最新进展：

- 已建立 Gitee 远程仓库并用于本地到服务器同步。
- 已购买并初始化腾讯云轻量应用服务器：Ubuntu 22.04、Nginx、PostgreSQL、FastAPI systemd 服务。
- App debug APK 已构建为连接公网 API：`http://119.91.47.141`。
- 已新增 `scripts/deploy_backend.sh`，用于服务器 `git pull` 后重启后端并检查状态。
- 已新增 PostgreSQL 备份脚本和 timer 安装脚本。
- Futu 连接参数已从硬编码改为环境变量：`FUTU_HOST`、`FUTU_PORT`、`FUTU_CONNECT_TIMEOUT_SECONDS`。
- 当前 Futu 不可用的原因是云服务器没有运行可达的 FutuOpenD，不代表后端整体离线。

当前下一步：

1. 先确认服务器 systemd、Nginx、PostgreSQL、备份 timer、UFW 和腾讯云防火墙。
2. 决定 FutuOpenD 方案：云服务器本机、家里电脑安全隧道、或独立行情节点。
3. 公网 API 加访问保护，再上域名和 HTTPS。
4. 真机继续核对基金历史交易迁移、养基宝规则、三点前后确认日、费率、份额/金额换算。

2026-05-24 最新进展：

- 持仓列表已经接入后端 `position_snapshots`，核心收益指标以后端为准。
- 持仓详情页已经接入后端交易历史和单股收益快照曲线。
- 持仓详情页已经提供加仓、减仓、清仓入口，提交后刷新后端持仓和页面状态。
- 交易历史支持删除，删除后后端按剩余交易重新回放持仓数量、成本和已实现盈亏。
- 历史信号支持忽略，普通列表和单股详情页不再显示已忽略信号。
- 单股详情页已经整合策略监控、历史信号和推送记录。
- 单股详情页可直接停用/启用监控、开启/关闭推送、删除监控。
- 推送记录支持按股票代码和状态筛选，支持删除和重试。
- 日间模式已改为纯白背景、中性灰卡片和更清晰边框，夜间模式保留原有深色风格。
- 场外基金管理已加入：基金搜索、持仓、估算/正式净值、基金交易、阈值提醒、多个提醒时间 scheduler、基金详情页 50 日净值趋势和买卖点标记。
- 移动端测试已更新到 56 个通过，后端测试 88 个通过。

当前下一步优先级：

1. 真机检查基金主页面和基金详情页，确认账户汇总、列表密度、深色详情头部、50 日净值和买卖点标记都符合预期。
2. 验证基金提醒 scheduler，确认多个提醒时间到点后能刷新基金数据、判断阈值并写入 `signal_events`。
3. 给基金数据源补缓存 TTL、重试、超时和降级提示，减少刷新慢带来的等待。
4. 把基金提醒信号接入推送记录页和信号页筛选，明确展示 `source_category=fund`。
5. 补基金交易编辑/删除、确认提示和操作后基准净值更新。

本节优先于下方历史“下一步”描述；旧章节保留为开发脉络。

当前已完成策略监控前端第一版：

- 信号页新增策略监控入口。
- 策略监控页可创建、开关、删除监控。
- 策略监控页可查看和控制 scheduler。
- 信号页新增推送记录入口。
- 推送记录页可查看 provider、状态、设备、尝试次数、错误和发送时间。

下一步先做真机链路验证：

```text
持仓股票
-> 策略监控
-> scheduler 扫描
-> signal_events
-> push_records
-> App 展示
```

单股详情页策略监控、历史信号和推送记录整合已经完成。后续不要重做这些基础入口，下一步应启用并验证 scheduler，再补扫描日志、真实推送和策略监控总览。

## 0.1 后续功能完善路线图

本节用于归档后续功能池。每次只取一个小闭环开发，不要并行铺太多页面。

### A. 近期高优先级

1. 场外基金真机验收与数据源稳定
   - 检查基金主页是否足够紧凑，贴近养基宝式账户汇总和列表密度。
   - 检查基金详情页深色头部、近 50 日净值、买入/卖出点位和页签切换。
   - 基金刷新慢时，先补缓存 TTL、重试、超时和降级提示。
   - 明确显示估算净值和正式净值更新时间，避免用户误把估算当成最终收益。

2. 基金提醒和推送闭环
   - 多个提醒时间到点后后端自动刷新基金数据。
   - 触发阈值后写入 `signal_events`。
   - 基金页显示最近扫描时间、触发数量、下次扫描。
   - 推送记录页和信号页能区分基金提醒。
   - 误触发提醒、交易记录和基金持仓删除都需要确认提示。

3. 扫描日志与原因说明
   - 后端记录每次策略监控扫描结果。
   - 字段建议：`monitor_id`、`code`、`strategy_code`、`stage`、`status`、`message`、`scanned_at`。
   - 状态建议：`triggered`、`not_triggered`、`cooldown`、`insufficient_klines`、`market_error`、`strategy_error`。
   - App 展示上次扫描结果、下次预计扫描时间和失败原因。
   - 支持按股票、状态、时间筛选；不想看的日志可删除。

4. 真实推送通道
   - 优先 Huawei Push Kit，适配当前华为真机环境。
   - 保留 FCM provider 作为 Google 设备通道。
   - 验证链路：设备注册 -> 策略扫描触发信号 -> 后端发送 -> 手机收到通知 -> `push_records` 显示 `sent`。
   - 失败记录支持重试，误发/测试记录支持删除。

5. 策略监控总览
   - 汇总所有股票的监控状态。
   - 显示启用/停用、推送开关、上次扫描、下次扫描、最近信号、最近错误。
   - 支持按股票、策略、启用状态、异常状态筛选。
   - 从总览可进入单股详情或监控编辑。

6. 信号处置流
   - 信号支持已读、忽略、加入观察、关联交易、复盘备注。
   - 已忽略信号保留审计入口，不在普通列表打扰。
   - 可从信号进入对应股票详情、策略监控和推送记录。

7. 交易记录增强
   - 在已有删除能力基础上补编辑、备注、手续费、税费、币种汇率。
   - 已实现收益明细按交易批次展示。
   - 清仓后仍可查看历史交易、历史收益曲线和历史信号。

### B. 中期功能

1. 持仓风险雷达
   - 单股风险：跌破成本、跌破均线、回撤过大、波动异常、亏损扩大、仓位过重。
   - 风险信号进入 `signal_events`，重要风险可进入推送候选。

2. 组合层面风控
   - 总仓位、市场分布、单票集中度、行业集中度、今日总盈亏、最大回撤。
   - 首页或持仓页提供组合风险摘要。

3. 回测到监控的一键落地
   - 回测结果页支持“保存为监控策略”。
   - 保留来源回测 id、策略参数、收益率、最大回撤、交易次数、胜率。
   - 保存后进入策略监控总览，并按 scheduler 自动扫描。

4. K 线交互增强
   - 横屏全屏细节优化。
   - 十字光标、成交量/均线开关、买卖点标记、信号标记。
   - 指标逐步扩展到 MACD、RSI、BOLL，但继续放在 `widgets/chart/`。

5. 数据健康检查
   - 设置页或独立健康页显示：FutuOpenD 在线状态、行情权限、K 线最后更新时间、刷新失败股票。
   - 区分后端在线、Futu 不可用、行情无权限、K 线无数据。

### C. 后续高级功能

1. 自动复盘日报
   - 每日汇总今日盈亏、触发信号、推送结果、风险变化、需要关注的股票。
   - 可先在 App 内展示，再考虑推送日报。

2. 策略参数推荐
   - 基于历史回测结果推荐 MA、RSI、MACD、BOLL 参数组合。
   - 第一版做有限网格和结果排序，不做黑盒自动交易建议。

3. 多账户 / 多券商支持
   - 区分模拟仓、真实仓、不同券商账户。
   - 持仓、交易、收益快照都要带账户维度。

4. 云同步与备份
   - 支持后端数据库备份、恢复和跨设备同步。
   - 先做本地导出/恢复，再考虑云端。

5. 权限与安全
   - App 本地锁屏。
   - 敏感金额隐藏。
   - 推送内容脱敏。
   - 后端密钥和厂商推送凭证只放 `.env`，不提交 Git。

## 1. 当前基线

当前已完成：

- Flutter App 基本功能。
- 持仓列表、详情页、添加/编辑/删除。
- 后端连接状态。
- FastAPI 持仓 API。
- 行情快照与 K 线模型。
- 详情页交互 K 线。
- K 线真实刷新逻辑：先请求后端 refresh，失败才读真实缓存，最后才允许 mock fallback。
- 分时 K 线已改为富途 `1m`。
- 日 K 默认拉取数量已改为 360 根，减少 MA60 左侧断裂。
- K 线支持双指缩放、单指横向浏览、点选查看详情。
- 竖屏和横屏 K 线区域已调整为“选中 K 线详情 -> MA 指标 -> K 线图”的内部层级。
- 本地缓存与后端 fallback。
- 股票搜索建议。
- 部分代码拆分。
- 真机安装验证。
- 策略监控选择入口。
- scheduler 状态展示。
- 信号推送记录查看。

当前验证通过：

```text
Flutter analyze: No issues found
Flutter test: 56 passed
Backend pytest: 88 passed
LAN debug APK build: Success
```

## 2. 开发优先级总览

推荐按以下顺序推进：

1. 完善持仓持久化与数据库迁移。
2. 增加信号历史和策略信号落库。
3. 新增量化入口和第一版回测框架。
4. 增加推送与提醒设置。
5. 生产化部署与监控。

## 3. 已完成：后端中文乱码修复

### 背景

后端历史持仓名称中存在乱码，例如中文名称被错误编码为连续拉丁扩展字符形态。此问题属于历史数据污染，不是 Flutter 渲染问题。

### 当前结论

- 当前 SQLite 持仓名称已确认正常。
- 已备份数据库到 `backend/data/stock_mvp.sqlite3.bak_20260513_encoding_fix`。
- 已在 `backend/app/database.py` 增加历史名称修复保护。
- 已在 `backend/app/main.py` 明确 JSON 响应头为 `application/json; charset=utf-8`。
- 已重启本机后端服务。

### 修复保护

后端启动时会对已知股票代码的异常名称做保护性修复：

- 空名称。
- 含问号。
- 含 Unicode replacement character。
- 含典型拉丁扩展乱码。

正常中文名称不会被覆盖。

### 已验证

- `.\.venv\Scripts\python.exe -m compileall app` 通过。
- `/api/v1/positions` 响应头为 `application/json; charset=utf-8`。
- Python 按 UTF-8 解码接口内容，中文正常。

## 4. 已完成：持仓详情页 K 线模块拆分

### 背景

此前 `mobile_app/lib/screens/position_detail_screen.dart` 同时包含 K 线交互、画布、横屏全图和信息面板，后续扩展成交量图、指标图层和量化入口会导致维护成本升高。

### 当前结构

```text
mobile_app/lib/screens/position_detail_screen.dart
mobile_app/lib/widgets/chart/position_kline_chart.dart
mobile_app/lib/widgets/chart/fullscreen_kline_screen.dart
mobile_app/lib/widgets/chart/kline_painter.dart
mobile_app/lib/widgets/chart/kline_info_panel.dart
mobile_app/lib/widgets/chart/kline_chart_values.dart
mobile_app/lib/widgets/chart/kline_chart_period.dart
```

### 当前分工

- `position_detail_screen.dart`：持仓详情状态、周期切换、K 线加载和页面编排。
- `position_kline_chart.dart`：竖屏 K 线卡片、手势、可见区间、加载/错误/空状态。
- `fullscreen_kline_screen.dart`：横屏全图、横屏锁定、顶部行情、横屏手势。
- `kline_painter.dart`：蜡烛图、MA、高低点标签、十字线、日期轴绘制。
- `kline_info_panel.dart`：MA 条和选中 K 线详情面板。
- `kline_chart_values.dart`：MA 计算、K 线价格/日期/大数格式化、涨跌颜色。
- `kline_chart_period.dart`：周期参数。

### 后续约束

- 新增 K 线指标时，优先扩展 `kline_chart_values.dart` 和 `kline_painter.dart`。
- 新增图表交互时，先判断竖屏和横屏是否都需要，避免两处逻辑长期分叉。
- 新增横屏布局内容时，只改 `fullscreen_kline_screen.dart`。
- 不把 K 线绘制代码重新写回 `position_detail_screen.dart`。

### 已验证

- `position_detail_screen.dart` 不再包含 K 线 Painter。
- `position_detail_screen.dart` 只负责页面编排、持仓状态、调用图表组件。
- 竖屏 K 线图功能不变。
- 横屏 K 线图功能不变。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。

## 5. 已完成：后端 API 结构与错误处理

### 目标

- 统一 API 错误返回。
- 明确富途不可用、权限不足、网络超时、无数据等状态。
- Flutter 能展示明确状态，而不是只显示“连接失败”。

### 当前后端错误格式

```json
{
  "detail": {
    "code": "FUTU_UNAVAILABLE",
    "message": "FutuOpenD 不可用或富途接口调用失败",
    "detail": {}
  }
}
```

### 已落地

- 后端新增 `backend/app/errors.py`。
- 后端持仓不存在、Futu 依赖缺失、Futu 不可用、K 线无数据统一返回结构化错误。
- Flutter `ApiException` 增加 `code/message/detail`。
- Flutter 兼容旧版 `{"detail":"..."}` 错误。
- Flutter 将超时和网络不可达归一为 `NETWORK_TIMEOUT`、`NETWORK_UNAVAILABLE`。
- 持仓接口成功但 Futu 刷新失败时，App 不再误判为后端离线。

### 已验证

- `python -m compileall app` 通过。
- `D:\flutter\bin\dart.bat format lib test` 通过。
- `D:\flutter\bin\flutter.bat analyze` 通过。
- `D:\flutter\bin\flutter.bat test` 通过。

### 后续优化

- 设置页增加独立 Futu 状态。
- K 线错误区根据错误码展示更具体提示。
- 后端继续拆分富途权限不足、订阅不足、行情无权限等细分错误码。

## 6. 任务四：持仓持久化和数据库演进

### 当前状态

- Flutter 有本地缓存。
- 后端有数据库/模拟存储雏形。
- 正式数据库设计尚未稳定。

### 目标

- 明确 MVP 数据库方案。
- 持仓数据可靠保存。
- 支持行情快照和 K 线缓存。

### 建议步骤

1. MVP 先稳定 SQLite。
2. 定义 migration 或初始化脚本。
3. 明确 positions、quote_snapshots、candles 表。
4. 后端所有写入统一经过 database/repository 层。
5. 后续迁移 PostgreSQL。

### 验收标准

- 重启后端后持仓不丢失。
- 重启 App 后本地缓存和后端数据一致。
- 行情/K 线缓存可复用。

## 7. 任务五：信号历史

### 当前状态

信号由 Flutter 本地 `buildSignals()` 根据当前可见持仓和阈值生成，尚未作为正式历史记录落库。

### 目标

- 后端保存信号历史。
- App 展示信号记录。
- 支持已读/未读。
- 后续支持推送。

### 建议接口

```text
GET   /api/v1/signals/history
POST  /api/v1/signals/recalculate
PATCH /api/v1/signals/{id}/read
```

### Flutter 建议

```text
models/signal_record.dart
services/signal_api_service.dart
repositories/signal_repository.dart
screens/signal_history_screen.dart
```

### 验收标准

- 信号生成后可在历史中看到。
- 刷新后信号记录不丢失。
- 已读状态可更新。

## 8. 任务六：策略量化与回测第一版

### 核心原则

- 策略逻辑和回测引擎自己写。
- 聚宽/JQData 可作为后续基本面和因子数据源。
- 富途用于实时行情和 K 线。
- 回测在后端跑，App 只负责配置和展示结果。

### 第一版策略

1. 双均线策略：MA5/MA20 或 MA10/MA60。
2. MACD 趋势策略。
3. RSI 超买超卖策略。
4. BOLL 突破/回归策略。
5. 成交量放大 + 动量策略。

### 下一步策略扩展顺序

当前量化模块已经具备回测执行、结果展示、历史回测管理、历史命名和筛选能力。下一步不继续优先打磨历史管理，而是进入多策略扩展，先做 RSI 策略。

建议顺序：

1. 后端新增 RSI 策略。
   - 策略 code 建议为 `rsi_reversal`。
   - 参数：`rsi_window`、`oversold`、`overbought`。
   - 买入：RSI 低于超卖线后回升。
   - 卖出：RSI 高于超买线后回落，或触发退出条件。
2. 回测引擎支持多策略分发。
   - 不要继续把所有策略逻辑堆进 `backend/app/backtest/engine.py`。
   - 建议新增或扩展 `backend/app/strategies/`，把策略信号计算放到策略模块。
   - `engine.py` 负责读取 K 线、执行交易撮合、手续费、滑点、仓位和结果保存。
3. App 参数区按策略动态变化。
   - 选 MA Cross 时显示短均线和长均线。
   - 选 RSI 时显示 RSI 周期、超卖线、超买线。
   - 后续 MACD、BOLL 等策略继续按策略定义动态渲染参数，不要把所有参数固定铺在页面上。
4. 历史记录显示策略中文名或可读名。
   - 历史记录目前以策略 code 为主。
   - 策略变多后，应展示 `MA Cross`、`RSI 反转` 这类可读名称，code 只作为辅助信息。

第一轮建议只做后端 RSI 策略和多策略分发，接口能跑通 RSI 后，再做 App 动态参数 UI。

### 2026-05-16 RSI 后端进展

已完成：

- 新增 `backend/app/strategies/` 策略包。
- `ma_cross` 已从 `backtest/engine.py` 拆到 `strategies/ma_cross.py`。
- 新增 `strategies/rsi_reversal.py`。
- 新增 `strategies/factors.py`，当前包含 MA 和 RSI 计算。
- 新增 `strategies/registry.py`，回测引擎通过 `strategy_code` 获取策略实现。
- `backtest/engine.py` 已改为读取策略信号并统一执行交易、手续费、滑点、净值曲线和结果保存。
- 种子策略新增 `rsi_reversal`，默认参数为 `rsi_window=14`、`oversold=30`、`overbought=70`。
- 后端测试已覆盖 RSI 正常回测和 RSI 参数错误。

待做：

- App 参数区已支持按策略动态显示参数：MA Cross 显示短均线和长均线，RSI Reversal 显示 RSI 周期、超卖线、超买线。
- 历史记录策略展示已优先显示策略可读名。

下一步待做：

- 真机验证 RSI Reversal 能从 App 直接发起回测。
- 后续结果区可增加策略参数快照，让历史结果能直观看到当时使用的 RSI/MA 参数。

### 2026-05-16 回测胜率指标

已新增回测胜率指标：

- 后端根据完整买入/卖出回合计算胜率。
- 未平仓买入不计入胜率分母。
- 盈利回合定义为卖出净收入大于买入成本。
- 回测 summary 新增 `round_trip_count`、`win_count`、`loss_count`、`win_rate`。
- App 结果区新增“胜率”和“买卖回合”展示。
- 旧历史回测如果没有这些字段会显示空值，需要重新跑回测后才有胜率。

### 历史回测详情与数据库压力

历史回测详情页或详情展开可以继续做，不会对当前数据库造成明显压力。

当前历史详情需要保存和读取的数据：

- `backtest_runs`：一次回测的配置、参数、状态和 summary。
- `backtest_equity_curve`：每天一条净值曲线。
- `backtest_trades`：买卖交易记录。
- `klines`：K 线数据统一复用现有行情表，不要为每次回测复制一份完整 K 线。

量级估算：

- 一次日 K 回测 5 年，大约 1200 个交易日。
- 一次回测大约写入 1 行 `backtest_runs`、1200 行 `backtest_equity_curve`、几十行 `backtest_trades`。
- 即使跑 1000 次回测，净值曲线约 120 万行，对 PostgreSQL 属于轻量数据。

强约束：

- 历史详情打开时按 `stock_code`、`period`、`start_date`、`end_date` 从 `klines` 查询 K 线。
- 不要把 K 线快照重复写入每条回测记录。
- 历史列表只读 `backtest_runs` 摘要，不加载净值曲线和交易记录。
- 只有点击某条历史记录后，才加载 `backtest_equity_curve`、`backtest_trades` 和对应 K 线。

后续优化：

- 给 `backtest_equity_curve` 和 `backtest_trades` 保持或补充 `run_id` 相关索引。
- 历史回测数量增多后，将当前最多 30 条改为分页或分页加载。
- 结果区下一步建议增加参数快照，便于打开历史回测后知道当时使用的策略参数。

### 2026-05-16 参数快照进展

已完成结果区参数快照：

- App `BacktestRun` 模型新增 `parameters` 解析。
- 结果区新增“参数”小节。
- 通用参数展示：策略、股票、回测区间、初始资金、手续费率、滑点率。
- `MA Cross` 展示短均线、长均线。
- `RSI Reversal` 展示 RSI 周期、超卖线、超买线。
- 点击历史回测加载完整结果后，也会显示当时回测使用的参数快照。
- 参数区已压缩为三栏布局，区间字段单独占一行，避免真机窄屏出现日期溢出。
- 历史回测列表已做紧凑化展示，避免名称、策略、日期堆叠过高。

交接后的短期优先级：

1. 先继续完善历史回测详情体验，确保从历史列表点开后能稳定复盘参数、收益、收益曲线、买卖点 K 线和交易记录。
2. 再考虑把胜率摘要加入历史列表；如果手机布局拥挤，可以只在详情结果区展示胜率。
3. 策略 registry、多策略分发、RSI 和 MACD Trend 已完成；后续新增 BOLL、成交量动量等未完成策略时继续复用现有动态参数表单和后端参数校验模式。

### 后端建议结构

```text
backend/app/strategies/base.py
backend/app/strategies/factors.py
backend/app/strategies/registry.py
backend/app/backtest/engine.py
backend/app/backtest/metrics.py
backend/app/routers/strategies.py
backend/app/routers/backtests.py
```

### Flutter 建议结构

```text
mobile_app/lib/models/strategy_definition.dart
mobile_app/lib/models/backtest_request.dart
mobile_app/lib/models/backtest_result.dart
mobile_app/lib/models/factor_score.dart
mobile_app/lib/services/strategy_api_service.dart
mobile_app/lib/services/backtest_api_service.dart
mobile_app/lib/repositories/strategy_repository.dart
mobile_app/lib/repositories/backtest_repository.dart
mobile_app/lib/screens/strategy_lab_screen.dart
mobile_app/lib/screens/backtest_screen.dart
mobile_app/lib/screens/backtest_result_screen.dart
mobile_app/lib/widgets/strategy/
mobile_app/lib/widgets/backtest/
```

### 回测必须支持

- 股票代码。
- 周期。
- 日期区间。
- 初始资金。
- 手续费。
- 滑点。
- 仓位比例。
- 止盈止损。
- 交易明细。
- 权益曲线。
- 最大回撤。
- 胜率。
- 盈亏比。

### 验收标准

- 能选择一只股票和一种策略运行回测。
- 后端返回权益曲线和交易记录。
- App 展示收益曲线、最大回撤、胜率、交易记录。
- 回测参数可追溯。

## 9. 任务七：推送提醒

### 目标

- 信号触发后通知用户。
- App 内可开关提醒。
- 后端记录推送结果。

### 建议步骤

1. 先做 App 内信号历史。
2. 再做本地通知。
3. 最后接 FCM 或厂商推送。

### 风险

FCM 在国内设备上可能不稳定，后续可能需要华为、小米、OPPO、vivo 厂商推送。

### 2026-05-16 本地通知第一阶段

已完成：

- App 增加 `flutter_local_notifications` 本地通知依赖。
- Android 增加 `POST_NOTIFICATIONS` 权限。
- Android Gradle 已开启 core library desugaring，并增加 `desugar_jdk_libs`，满足通知插件构建要求。
- 新增 `NotificationService`，通知插件初始化、权限申请和信号通知展示统一放在 `services/`。
- 持仓刷新、新增持仓、编辑持仓、调整信号阈值后，会重新计算当前市场的信号。
- 同一轮 App 运行期间按 `信号类型 + 股票` 去重，避免同一条信号重复弹通知。
- 首次打开加载本地持仓时暂不弹通知，避免一进入 App 就被历史信号刷屏。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
gradlew :app:assembleDebug
```

当前边界：

- 这是 App 前台或用户触发刷新后的本地通知，不是后台服务器推送。
- App 被系统杀掉、没有刷新行情、没有后端定时扫描时，不会主动发现新信号。
- 真正后台推送仍需后端信号记录、设备 token、推送通道和推送结果表。
- 当前环境未检测到真机，APK 尚未安装到手机实测。

下一步建议：

1. 增加 App 内提醒开关和权限状态提示。
2. 增加信号历史与已读/未读状态。
3. 后端增加信号扫描与推送记录表。
4. 再评估 FCM、华为、小米、OPPO、vivo 等推送通道。

### 2026-05-17 信息推送可行方案

目标是 App 不打开时，重要信号也能尽快通知到手机。当前本地通知只能在 App 运行或用户触发刷新后弹出，不能替代真正后台推送。

### 2026-05-17 FCM 服务端第一阶段

已完成：

- 后端新增 `backend/app/services/push_service.py`，统一处理设备开关、推送通道分发、推送记录写入和发送结果状态。
- 后端新增 `backend/app/services/push_providers/fcm.py`，第一版 FCM provider 通过 Firebase Admin SDK 发送测试通知。
- `backend/requirements.txt` 已新增 `firebase-admin`，`backend/.env.example` 已补充 `FCM_SERVICE_ACCOUNT_PATH` 和 `FCM_SERVICE_ACCOUNT_JSON`。
- `/api/v1/notifications/test` 已改为通过 `push_service` 调度；通道未配置时写入 `skipped`，FCM 发送成功时写入 `sent` 和 message id。

仍未完成：

- App 端还没有接入 Firebase Android 配置和真实 FCM token。
- 当前仓库没有 `mobile_app/android/app/google-services.json`。
- FCM 服务账号密钥不得提交到 Git，只能放在 `.env`、服务器环境变量或安全密钥管理中。

推荐分三阶段落地：

1. 后端信号中心。
   - 新增信号事件表，记录信号类型、股票、触发价格、触发时间、严重级别、去重 key、已读状态。
   - 新增设备表，记录用户设备、平台、推送 token、通知开关、最后活跃时间。
   - 新增推送记录表，记录每次推送请求、通道、状态、失败原因和重试次数。
   - 后端定时扫描持仓和行情，生成重要信号后先落库，再进入推送队列。
2. 第一版真实推送。
   - Android 优先接 FCM，Flutter 端使用 `firebase_messaging` 获取 token、接收前台/后台消息。
   - 前台消息由 App 转成本地通知展示；后台或已退出时由系统通知栏展示。
   - 后端使用 FCM HTTP v1 API 推送，payload 只放信号 id、股票代码、级别和短标题，详细内容由 App 打开后再拉取，避免把完整持仓或敏感信息放进推送内容。
3. 国内 Android 增强。
   - FCM 在部分国内设备上不稳定，后续需要按设备品牌评估华为、小米、OPPO、vivo 等厂商推送。
   - 服务端推送通道要抽象为 `PushProvider`，先实现 FCM，后续再按品牌增加厂商实现。
   - App 端保留通知权限状态、品牌提示和手动测试通知入口，便于排查设备权限和省电策略影响。

第一版建议只做“重要信号推送”，不要一次做全量消息系统。

重要信号范围建议：

- 止损触发或接近止损。
- 止盈触发或接近止盈。
- 单日涨跌幅或浮盈亏变化超过用户阈值。
- 策略信号由无变为买入/卖出。
- 后续可加入回测任务完成、监控任务异常等低优先级通知。

关键约束：

- 推送不是投资建议，通知文案只能写“触发观察信号”。
- 所有信号先落库，再推送，避免推送成功但 App 内没有记录。
- 同一股票同一信号必须按时间窗口去重，避免行情波动导致刷屏。
- App 通知开关、系统通知权限、设备 token 状态都要可见。
- 推送失败不影响信号落库，但要记录失败原因，方便重试或排查。
- 不要在 Flutter 页面里直接计算后端推送信号；App 只负责 token 注册、设置、展示和打开详情。

当前最小可执行顺序：

1. 后端信号事件表、设备表、推送记录表已完成。
2. App 通知设置页和设备 token 注册接口已完成。
3. 接 FCM 第一版服务端推送。
4. 增加后端定时扫描任务，先扫描用户持仓止盈止损和异动阈值。
5. 真机测试前台、后台、锁屏、App 被清理后的到达情况。
6. 再决定是否接华为、小米、OPPO、vivo 厂商推送。

### 2026-05-17 推送后端地基完成

已完成：

- 新增 `signal_events`，用于保存重要信号事件、级别、去重 key、触发值、阈值、payload 和已读状态。
- 新增 `notification_devices`，用于保存平台、推送通道、设备 token、通知开关、重要信号开关和最后活跃时间。
- 新增 `push_records`，用于保存每次推送尝试、目标设备、通道、状态、请求/响应、错误原因、重试次数和发送时间。
- 新增 `backend/app/schemas/notifications.py`。
- 新增 `backend/app/repositories/notifications.py`。
- `database.py` 已导出通知仓储函数，后续接口可直接复用。
- 后端测试覆盖信号事件、设备 token upsert 和推送记录。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 23 passed
```

### 2026-05-17 App 通知设置和设备注册完成

已完成：

- 后端新增通知路由 `backend/app/routers/notifications.py`。
- `POST /api/v1/notifications/devices` 支持设备注册和 token upsert。
- `POST /api/v1/notifications/test` 支持写入测试推送记录；真实推送通道未配置时状态为 `skipped`。
- App 新增 `NotificationSettingsScreen`，从设置页进入。
- App 新增 `NotificationRepository`、`NotificationApiService`、`PushTokenService` 和通知模型。
- 当前 App 使用本机安装 token 注册设备；真实 FCM token 等接入 Firebase 后替换。
- 设置页可切换手机提醒和重要信号提醒，可重新注册设备，可触发本地测试通知并写入后端测试记录。
- Debug APK 已安装到真机，`adb reverse tcp:8000 tcp:8000` 已设置，后端 `/health` 返回正常。

交接验证：

- 打开手机 App，进入 `设置 -> 手机推送 / 消息提醒设置`。
- 确认当前设备注册成功。
- 点击测试通知，确认手机能弹出本地测试通知。
- 如果注册失败，先检查后端和 `adb reverse`。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 24 passed
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
D:\flutter\bin\flutter.bat build apk --debug
adb install: Success
adb reverse tcp:8000 tcp:8000
backend /health: ok
```

## 10. 任务八：生产化

### 目标

- Docker Compose。
- PostgreSQL。
- Redis。
- Nginx/HTTPS。
- 日志。
- 监控。
- 备份。

### 建议顺序

1. 后端 `.env.example`。
2. Dockerfile。
3. docker-compose。
4. PostgreSQL 迁移。
5. Redis 缓存。
6. 日志与错误追踪。
7. 云服务器部署。

## 11. 每次开发完成后更新

每完成一项功能，应更新本文档：

- 当前状态。
- 已完成任务。
- 下一步任务。
- 新增文件结构。
- 验收状态。
- 已知风险。

### 2026-05-21 策略监控后端地基

已完成：

- 新增 `strategy_monitors` 表，用于记录某只股票/持仓绑定的策略、参数、K 线周期、扫描间隔、冷却时间、推送候选和来源回测。
- 新增 `backend/app/repositories/strategy_monitors.py`，数据库读写继续放在 repository 层，不写回 `database.py`。
- 新增 `backend/app/services/strategy_monitor_scanner.py`，手动扫描已启用监控，复用现有策略模块计算信号。
- 策略监控扫描结果写入 `signal_events`，不直接推送页面内存状态。
- 新增 `GET/POST/PUT/DELETE /api/v1/strategies/monitors` 和 `POST /api/v1/strategies/monitors/scan`。
- 新增 `backend/app/services/strategy_monitor_scheduler.py`，可随后端启动自动轮询扫描，也可通过 API 手动启动、停止和查看状态。
- `backend/app/main.py` 已从 `on_event` 迁移到 lifespan，启动时初始化数据库和 scheduler，关闭时停止 scheduler。
- `backend/.env.example` 已补充 `STRATEGY_MONITOR_SCHEDULER_ENABLED`、`STRATEGY_MONITOR_SCHEDULER_INTERVAL_SECONDS`、`STRATEGY_MONITOR_SCHEDULER_REFRESH`。
- `push_candidate=true` 的策略监控信号已接入 `push_service`，会按设备推送开关、重要通知开关和通道配置写入 `push_records`。
- 新增 `POST /api/v1/notifications/signals/{event_id}/dispatch`，可手动分发某条已落库信号；同一信号同一设备不会重复发送。

下一步：

1. 前端再接策略监控选择入口、持仓详情监控状态和券商式持仓表。
2. 在 App 信号页补充已读/忽略操作和推送记录查看入口。
3. 后续生产部署如果需要多进程或多实例，应把 scheduler 迁移到 APScheduler/Celery/独立 worker，避免多个 API 进程重复扫描。

### 2026-05-16 历史回测复盘体验补充

已完成：

- 点击历史回测后，量化页会自动定位到结果区。
- 结果区顶部会区分“当前查看历史回测”和“刚刚完成的回测”。
- 结果区顶部展示回测名称、策略、股票代码和日期区间，避免用户无法判断当前结果来源。
- 失败的历史回测不再只作为普通错误弹出，会保留结果区上下文、参数快照和失败原因。
- 历史结果已加载但 K 线缓存不足时，会在买卖点区域显示明确提示，不再让用户误以为页面没有响应。
- 交易记录列表已改为固定高度滚动卡片，默认约显示 8 行高度，但可在卡片内滚动查看全部交易记录。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
UTF-8 replacement scan: no matches
debug APK 已重新构建并安装到真机
```

下一步：

- 继续整理 App 动态参数结构，让策略参数 UI、默认值、校验和请求参数构建从统一配置读取。
- 动态参数结构、策略 registry、多策略分发和 MACD Trend 已完成；后续可进入 BOLL、成交量动量等未完成策略扩展。

### 2026-05-16 MACD 后端策略进展

已完成 MACD 后端第一阶段：

- `backend/app/strategies/factors.py` 新增 EMA 和 MACD 指标计算。
- 新增 `backend/app/strategies/macd_trend.py`。
- `macd_trend` 已接入策略 registry。
- 种子策略新增 `macd_trend`，默认参数为 `fast_window=12`、`slow_window=26`、`signal_window=9`。
- 第一版交易规则：MACD 柱由负转正买入，由正转负卖出。
- 后端回测失败原因新增 `invalid_macd_parameters`。
- 后端测试覆盖 MACD 策略 seed、正常回测和参数错误。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 19 passed
```

下一步：

- App 侧 MACD 动态参数已完成，不需要重复开发。
- 继续真机验证 MACD Trend 在不同股票和日期区间下的回测稳定性。
- 验证通过后再考虑 BOLL 或成交量动量策略。

### 2026-05-16 App 接入 MACD 参数

已完成：

- App 动态参数配置新增 `macd_trend`。
- 量化页选择 MACD Trend 后显示快线周期、慢线周期、信号周期。
- 提交 MACD 回测时传 `fast_window`、`slow_window`、`signal_window`。
- App 端增加快线周期必须小于慢线周期的提交前校验。
- 结果区参数快照新增 MACD 参数展示。
- App 回测失败提示兼容 `invalid_macd_parameters`。
- 参数配置测试覆盖 MACD 参数 spec 和默认值读取。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 19 passed
```

下一步：

- 真机验证 MACD Trend 可以从 App 直接发起回测。
- 验证通过后再考虑 BOLL 或成交量动量策略。

### 2026-05-16 持仓 K 线 VOL 副图进展

已完成：

- 持仓详情 K 线图新增 VOL 成交量副图。
- VOL 使用现有 `Candle.volume` 数据，不需要新增后端接口。
- K 线主图继续显示价格蜡烛和 MA5/MA10/MA20/MA60。
- K 线下方新增成交量柱，并叠加 VOL MA5/MA10/MA20。
- VOL 颜色按当前约定处理：绿色表示流入/上涨量，红色表示流出/下跌量。
- 横屏 K 线复用同一个 painter，因此也会显示 VOL 副图。
- 新增成交量均线工具测试。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

下一步：

- 真机检查竖屏和横屏 K 线的 VOL 区域高度、标签可读性和手势交互。
- 如果拥挤，再调整主图和 VOL 区域比例。

## 12. PostgreSQL 迁移后的开发顺序

当前后端已经具备 PostgreSQL 连接能力，数据库迁移已完成。后续不建议继续把回测、策略、历史行情全部压在 SQLite 上。

### 2026-05-15 已完成：后端数据库层拆分

`backend/app/database.py` 已经从 1000 行以上的混合文件拆为兼容门面和领域 repository：

```text
backend/app/database.py
backend/app/db/core.py
backend/app/db/init.py
backend/app/db/converters.py
backend/app/db/seed.py
backend/app/repositories/positions.py
backend/app/repositories/market_data.py
backend/app/repositories/strategies.py
backend/app/repositories/backtests.py
```

当前边界：

- `database.py` 只做旧调用兼容导出。
- `db/` 负责连接、建表、seed、转换和底层数据库工具。
- `repositories/` 负责具体业务读写。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 7 passed
```

下一步建议：

- 把 routers 从 `app.database` 兼容门面迁移到对应 repository。
- 把 `backtest/engine.py` 从 `app.database` 兼容门面迁移到 `repositories.market_data` 和 `repositories.backtests`。
- 新增数据库能力时优先补 repository 和测试，不再扩大 `database.py`。

### 下一步优先级

1. 策略和回测表结构设计。
2. 回测引擎最小版本。
3. App 量化入口和回测结果展示。

### 数据库相关约束

- 本地开发使用 `DATABASE_URL` 连接 PostgreSQL。
- SQLite 只作为历史迁移来源和临时回退，不再作为后续量化主库。
- 回测结果、策略参数、交易记录、净值曲线必须落 PostgreSQL。
- 后续迁到云服务器或云数据库时，优先通过标准 PostgreSQL 工具迁移。

### 首个回测闭环建议

- 策略：双均线。
- 数据：已有日 K。
- 标的：单股票。
- 输出：收益率、最大回撤、胜率、交易记录、净值曲线。
- App：只负责配置参数和展示结果，不在 Flutter 内计算回测。

### 已补充的测试基础

- `backend/tests/test_database.py` 已覆盖 PostgreSQL 下持仓、行情快照、K 线基础读写。
- 测试库为 `stock_web_test`。
- 真实开发库为 `stock_web`，不得用自动化测试清空真实库。

### 已完成的后端接口拆分

- `backend/app/main.py` 已拆出 routers。
- 当前路由按健康检查、持仓、行情、K 线、信号、股票搜索、富途分组。
- 后续新增策略和回测时，直接增加 `routers/strategies.py` 和 `routers/backtests.py`。

### 已完成的后端模型拆分

- `backend/app/schemas.py` 已拆为 `backend/app/schemas/` 包。
- 当前按持仓、行情、K 线、信号、股票搜索分文件。
- 后续新增策略和回测模型时，直接增加 `schemas/strategies.py` 和 `schemas/backtests.py`。

## 13. 策略和回测后端骨架计划

接下来进入策略和回测模块，但第一步只做后端地基，不先做复杂算法和 App 页面。

### 当前前置条件

- PostgreSQL 已作为后端主库。
- 已有独立测试库 `stock_web_test`。
- 后端数据库基础读写已有 pytest 覆盖。
- routers 已按业务领域拆分。
- schemas 已按业务领域拆分。

### 第一阶段开发内容

已新增策略和回测的最小后端结构：

```text
backend/app/schemas/strategies.py
backend/app/schemas/backtests.py
backend/app/routers/strategies.py
backend/app/routers/backtests.py
backend/tests/test_strategy_backtest_database.py
```

已落库：

```text
strategy_definitions
backtest_runs
backtest_equity_curve
backtest_trades
strategy_parameters
strategy_signals
```

### 第一版接口范围

```text
GET  /api/v1/strategies
POST /api/v1/backtests
GET  /api/v1/backtests/{run_id}
```

`POST /api/v1/backtests` 由 App 提交回测配置。后端不能固定回测时间，也不能脱离用户配置自动决定时间范围。

第一版请求参数建议：

```text
strategy_code
stock_code
period
start_date
end_date
initial_cash
fee_rate
slippage_rate
parameters
```

其中 `start_date` 和 `end_date` 必须由 App 用户选择。

### 第一版回测范围

- 策略：双均线策略。
- 标的：单股票。
- 数据：日 K。
- 参数：短均线、长均线、初始资金、手续费、滑点。
- 输出：收益率、最大回撤、交易记录、净值曲线。

当前状态：

- `GET /api/v1/strategies` 已可返回默认双均线策略。
- `POST /api/v1/backtests` 已可创建回测任务并同步执行最小双均线回测。
- `GET /api/v1/backtests/{run_id}` 已可读取回测任务结果结构。
- 最小双均线回测引擎已实现，会写入净值曲线和交易记录。

### 设计边界

- 回测在后端跑。
- App 负责配置股票、策略、开始日期、结束日期、资金、手续费、滑点和策略参数。
- App 负责展示收益曲线、最大回撤、交易记录和回测摘要。
- 不在 Flutter 中实现回测引擎。
- 策略规则、手续费、滑点、仓位管理必须由后端策略模块控制。
- 回测结果必须落 PostgreSQL，便于后续多人使用和迁云。

### 开发节奏

第一阶段可以先只实现后端接口，用接口请求跑通回测闭环；第二阶段再在 App 增加“量化”入口和结果展示页面。

### 已实现的最小双均线回测引擎

当前执行流程：

```text
输入 BacktestCreate
  -> 查询指定时间区间 K 线
  -> 计算 MA short / MA long
  -> 生成买卖点
  -> 计算资金、持仓、市值、净值和回撤
  -> 保存净值曲线和交易记录
  -> 返回 BacktestResult
```

当前验收：

```text
pytest: 7 passed
HK.02628 日 K 回测: completed
equity_points: 315
trades: 7
```

### 下一步实现重点

App 量化入口和回测结果展示已开始落地：

```text
策略列表
股票选择
开始日期和结束日期
策略参数设置
启动回测
收益曲线
交易记录
回测摘要
```

当前已完成第一版移动端入口：

- 底部导航新增“量化”。
- 量化页读取后端策略列表。
- 支持选择持仓股票或手动输入股票代码。
- 支持选择开始日期和结束日期。
- 支持配置初始资金、手续费、滑点、短均线、长均线。
- 点击启动回测后调用后端 `POST /api/v1/backtests`。
- 展示总收益、最大回撤、期末权益、交易次数、收益曲线和交易记录。

后续继续增强：

- 增加历史回测列表。
- 增加更多策略类型。
- 参数校验和错误提示已经完成第一轮：App 会在提交前校验股票代码、日期区间、初始资金、手续费率、滑点率、短均线、长均线；后端回测失败会在 `summary.error_message` 返回可读原因，App 收到 failed 结果时会展示错误而不是当作正常结果展示。
- 继续增强量化页 K 线买卖点图：增加成交量、缩放、横向拖动和点击查看交易详情；持仓详情页 K 线保持独立维护。

历史回测列表已完成第一版：

- 后端新增 `GET /api/v1/backtests`。
- 支持按 `stock_code`、`strategy_code`、`status`、`limit` 查询回测运行摘要。
- 数据库层新增 `list_backtest_runs`，只返回 `BacktestRun` 摘要，不加载净值曲线和交易记录。
- 数据库层新增 `delete_backtest_run`，按单条 `run_id` 删除历史回测，并同步删除该回测的净值曲线和交易记录。
- 数据库层新增 `delete_all_backtest_runs`，用于一键删除全部历史回测，并同步清空所有回测净值曲线和交易记录。
- 数据库层新增回测名称字段 `name`，新回测会自动生成默认名称，历史回测可后续编辑名称。
- App 量化页新增“历史回测”面板，最多展示最近 30 条。
- 点击历史回测后调用 `GET /api/v1/backtests/{run_id}` 加载完整结果，并复用现有收益曲线、买卖点 K 线和交易记录展示。
- 历史回测列表展示数量从 5 条提升到最多 30 条，并支持按股票代码、策略、状态筛选。
- 每条历史回测支持单独删除；历史回测面板也支持一键删除全部历史。
- 单条删除和一键删除全部都必须弹确认框；删除全部后必须同步清空当前结果区，避免继续展示已删除的回测结果。

历史回测详情当前状态：

- 基础完整详情加载已经完成。
- 点击历史记录后，App 会调用详情接口读取 `BacktestResult`，并展示参数快照、收益指标、收益曲线、买卖点 K 线和交易记录。
- K 线不随回测结果重复保存，而是按历史回测的股票、周期和日期区间从现有 K 线缓存读取。
- 下一步应做复盘体验打磨，而不是重做详情接口。

短期体验优化顺序：

1. 点击历史记录后自动滚动或定位到结果区。
2. 在结果区顶部显示“当前查看历史回测”，并展示历史名称、策略、股票和日期区间。
3. 历史列表增加胜率摘要时要保持手机端紧凑布局，不要重新造成信息拥挤。
4. 对旧历史、失败历史或 K 线为空的情况增加明确提示。

多通道推送当前状态：

- 后端推送统一从 `backend/app/services/push_service.py` 分发，不允许 App 直接拼接业务信号或绕过信号落库。
- 已支持真实 provider：`fcm`、`huawei`。
- 已预留 provider：`xiaomi`、`oppo`、`vivo`、`apns`、`local`、`unknown`。预留 provider 未配置时必须写入 `skipped` 推送记录，不影响信号历史。
- 已支持对 `signal_events` 的推送候选分发：只有 `payload.push_candidate=true` 的信号进入设备分发；同一信号同一设备按 `push_records` 去重。
- 分发 payload 只携带 `signal_event_id`、股票代码、信号类型和必要跳转字段，不携带完整持仓、成本、数量或策略参数。
- App 端只负责获取设备 token 并登记：Android 优先尝试 Huawei Push Kit token，再尝试 FCM token，最后使用本机安装 token 兜底。
- 华为真机要跑通远程推送，需要 AppGallery Connect 的 `agconnect-services.json`，以及后端 `.env` 中的 `HUAWEI_PUSH_APP_ID`、`HUAWEI_PUSH_CLIENT_ID`、`HUAWEI_PUSH_CLIENT_SECRET`。
- Google/海外 Android 设备要跑通远程推送，需要 `google-services.json`，以及后端 `.env` 中的 `FCM_SERVICE_ACCOUNT_PATH` 或 `FCM_SERVICE_ACCOUNT_JSON`。

信号中心优化方案：

当前信号页的问题不是信号数量不够，而是信号解释不足。后续目标是把“信号页”从简单提示列表升级为可解释、可筛选、可配置、可追踪的信号中心。

信号分类：

```text
持仓风控信号
  -> 止盈观察
  -> 止损观察
  -> 当日上涨异动
  -> 当日下跌异动

量化策略信号
  -> MA Cross
  -> RSI Reversal
  -> MACD Trend
  -> BOLL
  -> 成交量动量

系统通知信号
  -> 后端连接状态
  -> 数据刷新失败
  -> 推送通道异常
  -> 定时任务执行异常
```

每条信号必须展示的核心信息：

```text
股票代码
股票名称
信号来源
策略名称
触发条件
当前值
阈值
信号级别
触发时间
是否已推送
是否已读/忽略
```

信号页筛选建议：

```text
全部
持仓风控
量化策略
重要
已忽略
```

第一批可推送信号：

- 止损观察。
- 止盈观察。
- MA 金叉或死叉。
- MACD 趋势翻多或翻空。
- RSI 超卖后回升。
- RSI 超买后回落。
- 放量突破。
- 多个策略在同一股票同一方向触发的共振信号。

默认只在 App 内展示、不直接推送的信号：

- 普通日涨跌。
- 单一弱条件，例如小幅涨跌。
- 重复触发的同一信号。
- 回测历史记录本身。
- 数据不足、策略失败、刷新失败等系统提示。

量化策略实时信号条件建议：

```text
MA Cross
  短均线上穿长均线 -> 趋势转强观察
  短均线下穿长均线 -> 趋势转弱观察

MACD
  DIF 上穿 DEA 且柱体转正 -> 趋势转强观察
  DIF 下穿 DEA 且柱体转负 -> 趋势转弱观察

RSI
  RSI 低于超卖线后重新上穿超卖线 -> 超卖反弹观察
  RSI 高于超买线后重新下穿超买线 -> 高位回落观察

BOLL
  收盘价跌破下轨后重新站回下轨 -> 下轨修复观察
  收盘价放量突破上轨 -> 突破观察

成交量动量
  涨幅超过阈值且成交量大于近 20 日均量指定倍数 -> 放量异动观察
```

后续开发顺序：

1. 扩展后端 `signal_events` 和 App `TradeSignal` 展示模型，补充策略来源、触发条件、当前值、阈值和推送标记。
2. 信号页增加分类筛选和重要级别筛选。
3. 后端新增策略信号扫描器，先复用已有 `price_break_ma`、MA、RSI、MACD 策略规则。
4. 将量化页已有策略参数定义复用到实时扫描配置，避免回测和信号扫描参数割裂。
5. 增加策略启用/停用、是否推送、阈值参数配置。
6. 后端信号先落库、按 dedupe key 去重，再进入推送分发。
7. 信号详情页展示完整解释，但仍不得写成投资建议。

信号中心扫描实施方案：

- 第一阶段只做手动扫描接口，例如 `POST /api/v1/signals/scan`，不先做定时任务，方便真机验证。
- 扫描股票池第一阶段使用当前持仓和用户关注列表；后续再加入自选场内 ETF/基金观察池。
- 扫描策略第一批使用 `price_break_ma`、`ma_cross`、`rsi_reversal`、`macd_trend`。
- 扫描前必须刷新或检查 K 线缓存，确保最新 K 线覆盖到目标交易日。
- 每条扫描结果必须写入 `signal_events`，字段至少包含股票代码、股票名称、策略 code、策略名称、触发条件、当前值、阈值、触发日期、级别、dedupe key、push_candidate。
- 同一股票、同一策略、同一方向、同一交易日必须去重。
- App 信号页拉取后端信号事件，不再只展示本地 `buildSignals()` 生成的模糊提示。
- 扫描稳定后再增加后台定时任务，定时任务仍然复用同一套扫描器。

2026-05-19 第一版实现进展：

- 后端已新增 `backend/app/services/signal_scanner.py`，第一版支持手动扫描当前持仓。
- 后端已新增 `POST /api/v1/signals/scan` 和 `GET /api/v1/signals/events`。
- 扫描策略第一批接入 `price_break_ma`、`ma_cross`、`rsi_reversal`、`macd_trend`。
- 扫描结果已写入 `signal_events`，并按股票、策略、参数、方向、触发日期生成 dedupe key。
- App 信号页已接入后端信号事件，支持手动“扫描信号”和刷新。
- App 信号页仍保留本地止盈止损信号作为后端无事件时的兜底展示。
- 下一步应把 `signal_events` 字段继续结构化，增加筛选、已读、忽略和推送候选配置。

场内基金/ETF 后续支持方案：

状态更新：场外开放式基金管理已在 2026-05-24 落地第一版，当前实现使用 `backend/app/services/fund_provider.py`、`backend/app/services/funds.py`、`backend/app/repositories/funds.py` 和 `backend/app/routers/funds.py`。下面保留的是场内 ETF 与场外基金边界原则。

- Futu OpenAPI 可以作为 A 股场内 ETF/LOF 行情源，代码形态包括 `SH.510300`、`SZ.159919` 这类交易所证券。
- Futu 不作为 A 股场外开放式基金净值主数据源；`OF.000001`、`CN.000001` 这类场外基金式代码不属于当前 Futu 行情代码体系。
- 支持 A 股场内 ETF 前，必须先修正后端市场/币种映射：`SH.`、`SZ.` 返回市场应为 A 股或 CN，币种应为 CNY。
- 场内 ETF 可以复用现有行情快照、K 线、策略回测和信号扫描链路。
- 场外开放式基金已走独立基金 provider；后续继续补累计净值、申购赎回状态、数据源标签和缓存稳定性。
- 场外基金只适合做净值趋势、持仓收益和估值提醒，不应强行套用分时、盘口、成交量等股票/ETF 指标。

量化数据实时性修复要求：

- 量化页默认结束日期必须跟随当前日期，不允许固定停留在历史日期。
- 回测启动前 App 必须按用户选择的日期区间主动刷新 K 线。
- 后端回测读取缓存时，必须同时检查 K 线数量和最新 K 线日期；如果最新 K 线早于回测结束日期，必须先请求行情刷新。
- 后续实时策略信号扫描必须沿用同一规则，否则会出现详情页已更新、量化买卖点和策略信号仍滞后数日的问题。
- 量化页买卖点图不要求复用详情页 K 线 painter，但必须复用同一份 K 线数据语义，并且指标窗口必须来自当前策略参数。
- MA Cross 当前语义是短均线穿越长均线，不是收盘价跌破 MA；如果要“收盘价跌破 MA5/MA10 就提醒”，应作为单独策略条件设计。

下一步优先任务：`price_break_ma`

目标：

- 解决用户看到详情页收盘价已经跌破 MA，但 MA Cross 没有触发信号时的理解断层。
- 把“价格跌破/站回均线”做成独立策略，不改变 MA Cross 金叉/死叉定义。
- 后续信号页和推送都能明确解释：当前收盘价是多少，对应 MA 是多少，为什么触发。

第一版策略参数：

```text
strategy_code: price_break_ma
ma_window: 5 / 10 / 20 / 60
direction: break_down / recover_up / both
period: day
```

第一版触发条件：

```text
跌破：上一根收盘价 >= 上一根 MA，当前收盘价 < 当前 MA
站回：上一根收盘价 <= 上一根 MA，当前收盘价 > 当前 MA
```

实现顺序：

1. 后端在 `backend/app/strategies/` 新增 `price_break_ma`，复用现有策略接口和 K 线模型。
2. 后端策略列表返回该策略参数定义，默认 `ma_window=10`、`direction=both`。
3. 回测引擎支持该策略信号，交易撮合仍由 `backtest/engine.py` 统一处理。
4. App 量化页按策略动态展示均线周期和方向参数。
5. 信号中心后续实时扫描复用同一个策略语义，不能另写一套判断。
6. 信号文案展示收盘价、MA 值、均线周期、方向和触发日期。

验收标准：

- 美光等已跌破 MA5/MA10 的股票，可以在选择 `price_break_ma` 后看到对应观察信号或回测卖点。
- 选择 MA Cross 时仍然只按短均线/长均线穿越触发，不被价格跌破条件污染。
- 信号页能区分“价格跌破 MA”和“双均线死叉”。
- 所有信号文案保持中性观察，不写成投资建议。

2026-05-19 实现进展：

- 后端已新增 `backend/app/strategies/price_break_ma.py`，支持收盘价跌破 MA 和重新站回 MA 两类信号。
- 策略注册表和默认策略种子已加入 `price_break_ma`，默认参数为 `ma_window=10`、`direction=both`。
- App 量化页已支持 `price_break_ma` 参数：均线周期和触发方向。
- 量化结果参数快照已能显示均线周期和方向；买卖点图对该策略只显示对应 MA 线。
- 已补后端和 Flutter 参数配置测试。
