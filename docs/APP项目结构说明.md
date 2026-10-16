# App 项目结构说明

## 0. 2026-07-09 当前代码结构快照

当前本地代码在 2026-06-06 结构基础上又新增了美股组合建议后端线。本节优先于后续历史结构描述。该功能已决定暂作为后备功能保留，当前不继续产品化。

当前关键事实：

- 后端测试文件当前为 14 个，移动端测试文件当前为 16 个。
- 后端全量 pytest 当前验证为 `155 passed`。
- Flutter analyze 当前无静态问题，Flutter test 当前验证为 `71 passed`。
- `backend/app/main.py` 已挂载 `portfolio_strategy.router`。
- `portfolio_strategy` 相关文件当前仍是 untracked；当前定位为后备雏形，不作为下一步主线开发目标。

后备组合建议调用关系：

```text
backend/app/routers/portfolio_strategy.py
  -> backend/app/services/us_portfolio_strategy.py
  -> backend/app/repositories/positions.py
  -> backend/app/repositories/market_data.py
  -> backend/app/schemas/portfolio_strategy.py
```

接口：

```text
GET /api/v1/portfolio-strategy/us?cash=0
```

用途：按当前美股持仓和手工输入现金计算资产列表、组合权重、风险指标和人工确认建议。当前尚未确认云端已部署，也没有完整移动端入口；后续重新启用前再补产品边界和验收。

## 0. 2026-06-06 代码结构快照

本轮交接前已逐份读取项目代码文件，并按后端、移动端、测试、脚本四类梳理。当前仓库主要源码规模：

- 后端 Python：`backend/app` 约 70 个模块，`backend/tests` 约 12 个测试文件。
- 移动端 Dart：`mobile_app/lib` 约 100+ 个模块，`mobile_app/test` 覆盖 API service、模型和部分页面。
- 脚本：`scripts/deploy_backend.sh`、`scripts/build_mobile_lan_debug.ps1`、Futu 安装和 PostgreSQL 备份脚本等。

核心调用关系：

- 后端：`main.py` -> `routers/*` -> `services/*` -> `repositories/*` -> `db/core.py`、`db/converters.py`。
- 回测：`routers/backtests.py` -> `backtest/engine.py` 或 `backtest/volume_profile.py` -> `strategies/*`、`repositories/market_data.py`、`services/futu_client.py`。
- 个股专属策略：`routers/personalized_strategies.py` -> `services/personalized_strategies.py` -> `repositories/market_data.py` / `services/futu_client.py`。
- 移动端：`main.dart` -> `screens/app_shell.dart` -> 各 repository -> 各 API service -> `ApiClient` -> 后端 `/api/v1/*`。
- 量化页：`screens/quant_screen.dart` 负责五个板块入口，具体 UI 拆到 `widgets/quant/*`。

下一步如果要更新专属策略，主要改动点只应落在：

- `backend/app/services/personalized_strategies.py`
- `backend/tests/test_personalized_strategies.py`
- `docs/us_stock_strategy_research_20260602.md`

除非接口字段发生变化，否则不应改动移动端模型和页面结构。

最后更新：2026-05-26

最新功能基线：

```text
a92a987 fix: make kline query postgres compatible
```

本次文档已同步持仓详情页、量化策略监控、推送记录、场外基金管理结构和云服务器部署交接。当前最新功能还包括：基金搜索、基金持仓、基金估算/正式净值、基金交易记录、基金阈值提醒、多个提醒时间 scheduler、基金详情页业绩走势、沪深300对比、成本价均线、区间切换、净值列表和买卖点标记、估算收益小圆圈“估”、下一参考净值/日期、云服务器本机 FutuOpenD 安全接入、域名 HTTPS 服务器侧初配，以及 PostgreSQL K 线查询兼容修复。

云服务器、Gitee、部署脚本、PostgreSQL 备份和 FutuOpenD 可用性说明见：

```text
docs/APP服务器部署与Futu交接说明.md
docs/APP下一位开发者交接清单.md
```

本文档用于说明当前项目每个主要代码文件的职责。新接手者看完后，应能判断某个功能应该在哪个目录、哪个文件下开发。

## 1. 项目顶层结构

```text
stock_web/
  backend/
  docs/
  mobile_app/
  scripts/
  ppt_assets/
  ppt_preview/
```

主要开发目录：

- `mobile_app/`：Flutter Android App。
- `backend/`：FastAPI 后端。
- `docs/`：项目文档。
- `scripts/`：开发、部署和服务器维护脚本。当前包含局域网 APK 构建、后端部署、PostgreSQL 备份、备份 timer 安装和云服务器 FutuOpenD 安装脚本。

## 2. Flutter App 结构

```text
mobile_app/
  lib/
  test/
  android/
  pubspec.yaml
```

### 2.1 `mobile_app/lib/`

```text
lib/
  main.dart
  data/
  models/
  repositories/
  screens/
  services/
  sheets/
  utils/
  widgets/
```

## 3. Flutter 入口

### `lib/main.dart`

职责：

- App 入口。
- 创建 `StockSignalApp`。
- 管理全局显示模式。
- 创建 `MaterialApp`。
- 挂载 `AppShell`。

开发规则：

- 不要在这里写页面 UI。
- 不要在这里写业务逻辑。
- 不要在这里接 API。

## 4. Flutter 数据目录

### `lib/data/sample_positions.dart`

本地样例持仓。

用于：

- 后端不可用时 fallback。
- 本地缓存为空时初始数据。
- 测试和开发样例。

### `lib/data/stock_suggestion_catalog.dart`

本地股票搜索候选目录。

用于：

- 添加持仓弹窗的本地建议。
- 后端股票搜索失败时兜底。

## 5. Flutter 模型目录

### `lib/models/app_enums.dart`

全局枚举：

- `MarketFilter`
- `DisplayMode`

### `lib/models/backend_connection_state.dart`

后端连接状态模型。

用于首页和设置页展示：

- connecting
- connected
- offline

### `lib/models/stock_position.dart`

核心持仓模型。

包含：

- 持仓基础字段。
- 行情字段。
- 后端成本字段：真实平均成本、券商式摊薄成本、已实现盈亏。
- 后端收益快照字段：市值、今日盈亏、持仓盈亏、总收益、持仓占比。
- 收益计算属性。
- 展示格式化属性。

开发持仓、收益、列表、详情页时经常会用到。

券商式持仓表展示后端 `position_snapshots` 计算结果；后端快照不可用时只显示未同步/空值，不再静默退回 App 端即时计算核心收益指标。

### `lib/models/position_snapshot.dart`

持仓收益快照模型。

对应后端：

```text
POST /api/v1/positions/snapshots/capture
GET  /api/v1/positions/snapshots/latest
```

用于承接后端计算后的市值、今日盈亏、持仓盈亏、总收益、持仓占比和成本口径。

### `lib/models/position_trade.dart`

持仓交易记录模型。

包含：

- `PositionTrade`：后端 `position_trades` 返回结构。
- `PositionTradeDraft`：App 提交加仓、减仓、清仓时的请求草稿。
- `actionLabel`：将 `open`、`add`、`reduce`、`close` 转为界面展示文案。

对应后端：

```text
GET  /api/v1/positions/{position_id}/trades
POST /api/v1/positions/{position_id}/trades
```

用于持仓详情页交易历史、加仓、减仓和清仓。

### `lib/models/quote_snapshot.dart`

行情快照模型。

对应后端：

```text
GET  /api/v1/quotes
POST /api/v1/quotes/refresh
```

### `lib/models/candle.dart`

K 线模型。

对应后端：

```text
GET  /api/v1/klines/{stock_code}
POST /api/v1/klines/refresh
```

### `lib/models/strategy_settings.dart`

策略阈值设置模型。

用于设置页和本地信号生成。

### `lib/models/trade_signal.dart`

本地信号展示模型。

当前用于 `SignalsScreen` 和首页最新信号。

当前后端信号字段必须保留：

- `code`：股票代码，用于 App 信号筛选。
- `signal_type`：具体信号类型，例如 `price_break_ma_sell`。
- `strategy_code`：策略编号，用于筛选和解释来源。
- `read_status`：未读、已读、已忽略状态。

### `lib/models/signal_scan_config.dart`

后端信号扫描配置模型。

用于 App 信号设置页：

- `enabled` 控制该扫描条件是否参与后端信号生成。
- `push_candidate` 控制该扫描条件生成的信号是否进入推送候选。

### `lib/models/strategy_monitor.dart`

策略监控模型。

用于 App 策略监控页面和 scheduler 状态展示：

- `StrategyMonitor`：后端 `strategy_monitors` 的 App 端结构。
- `StrategyMonitorCreateRequest`：创建监控请求。
- `StrategyMonitorSchedulerStatus`：后端调度器运行状态。

对应后端：

```text
GET    /api/v1/strategies/monitors
POST   /api/v1/strategies/monitors
PUT    /api/v1/strategies/monitors/{monitor_id}
DELETE /api/v1/strategies/monitors/{monitor_id}
GET    /api/v1/strategies/monitors/scheduler/status
POST   /api/v1/strategies/monitors/scheduler/start
POST   /api/v1/strategies/monitors/scheduler/stop
```

### `lib/models/notification_models.dart`

通知和推送模型。

当前包含：

- `NotificationDevice`：设备 token 和通知开关。
- `NotificationRegistrationResult`：设备注册结果。
- `PushRecord`：推送记录，用于展示通道、状态、设备、尝试次数、错误和发送时间。

### `lib/models/strategy_definition.dart`

量化策略定义模型。

用于：

- 解析后端策略列表。
- 支撑量化页策略下拉选择。
- 描述策略编号、名称、说明和参数定义。

### `lib/models/backtest_models.dart`

回测输入和结果模型。

包含：

- `BacktestRequest`：回测请求参数。
- `BacktestResult`：回测汇总结果。
- `BacktestTrade`：买卖交易记录。
- `BacktestEquityPoint`：收益曲线点。

量化页、回测结果图、买卖点图都应复用这里的模型，不要在 UI 文件里重复定义结构。

### `lib/models/stock_search_result.dart`

后端股票搜索结果模型。

对应：

```text
GET /api/v1/stocks/search
```

### `lib/models/stock_suggestion.dart`

添加持仓弹窗中的本地/远程候选项模型。

### `lib/models/fund_models.dart`

场外基金模型。

包含：

- `FundSearchResult`：基金搜索结果。
- `FundNavPoint`：基金净值点，包含正式净值、估算净值、日期和涨跌幅。
- `FundPosition`：基金持仓。
- `FundPositionSummary`：基金账户汇总、当日收益、持有收益和每只基金摘要。
- `FundGridRecommendation`：基于用户阈值和基准净值生成的加仓/减仓观察提醒。
- `FundAlertSettingsDraft`：单只基金阈值、买入金额、卖出比例等提醒设置。
- `FundAlertSchedulerStatus` / `FundAlertSchedulerDraft`：基金提醒 scheduler 状态和配置。
- `FundTradeDraft` / `FundTrade`：基金买入、卖出、分红等交易记录。

对应后端：

```text
GET    /api/v1/funds/search
GET    /api/v1/funds/positions/summary
GET    /api/v1/funds/benchmarks/hs300/navs
GET    /api/v1/funds/{fund_code}/quote
GET    /api/v1/funds/{fund_code}/navs
POST   /api/v1/funds/positions
PUT    /api/v1/funds/positions/{position_id}
PUT    /api/v1/funds/positions/{position_id}/holding
DELETE /api/v1/funds/positions/{position_id}
GET    /api/v1/funds/positions/{position_id}/trades
POST   /api/v1/funds/positions/{position_id}/trades
GET    /api/v1/funds/positions/{position_id}/trade-records
POST   /api/v1/funds/positions/{position_id}/trade-records
DELETE /api/v1/funds/positions/{position_id}/trade-records/{record_id}
GET    /api/v1/funds/alerts/scheduler/status
PUT    /api/v1/funds/alerts/scheduler/config
POST   /api/v1/funds/alerts/scheduler/run-once
POST   /api/v1/funds/alerts/scan
```

## 6. Flutter 仓储目录

### `lib/repositories/position_repository.dart`

持仓仓储层。

职责：

- 协调后端持仓 API。
- 协调行情 API。
- 协调本地缓存。
- 后端失败时 fallback。
- 持仓接口成功但 Futu 刷新失败时保留后端连接状态，并使用缓存行情。
- 创建、编辑、删除持仓后同步本地缓存。
- 加载单只持仓交易历史。
- 加载单只持仓收益快照历史。
- 提交加仓、减仓、清仓交易后重新加载持仓列表，并返回最新持仓给详情页。

开发持仓数据流时优先改这里，不要直接在页面里组合多个 service。

### `lib/repositories/backtest_repository.dart`

回测仓储层。

职责：

- 加载策略定义。
- 提交回测。
- 加载历史回测列表和详情。
- 删除、重命名历史回测。

量化页只调用 repository，不直接拼 HTTP。

### `lib/repositories/signal_repository.dart`

信号仓储层。

职责：

- 加载后端落库信号事件。
- 手动触发信号扫描。
- 加载和更新信号扫描配置。

信号页分类筛选通过 repository 传参到 `SignalApiService`，不要在页面里拼 URL。

### `lib/repositories/notification_repository.dart`

通知仓储层。

职责：

- 注册当前设备 token。
- 发送测试通知。
- 读取推送记录。

设置页和推送记录页都应通过这里访问通知相关 API。

### `lib/repositories/strategy_monitor_repository.dart`

策略监控仓储层。

职责：

- 加载策略监控列表。
- 创建、更新、删除策略监控。
- 加载 scheduler 状态。
- 启动、停止 scheduler。

策略监控页只做表单和状态展示，不直接拼 HTTP。

### `lib/repositories/fund_repository.dart`

基金仓储层。

职责：

- 搜索场外基金。
- 加载基金账户汇总和基金持仓列表。
- 加载单只基金净值历史和交易记录。
- 创建、删除基金持仓。
- 提交基金买入、卖出、分红等交易记录。
- 读取和保存基金阈值提醒设置。
- 读取、保存、启动基金提醒 scheduler 配置。
- 手动触发基金提醒扫描。

基金页面和基金详情页只调用 repository，不直接拼 HTTP。

## 7. Flutter 服务目录

### `lib/services/api_client.dart`

统一 HTTP 客户端。

职责：

- baseUrl。
- 可选 `API_ACCESS_TOKEN` Bearer token。
- GET/POST/PUT/DELETE。
- JSON 编解码。
- 请求超时。
- 结构化 API 异常。
- 兼容旧版后端错误。
- 将网络超时归一为 `NETWORK_TIMEOUT`。
- 将网络不可达归一为 `NETWORK_UNAVAILABLE`。

所有后端请求都应经过它。

公网 API 启用 token 时，App 通过 `--dart-define=API_ACCESS_TOKEN=...` 注入 token，`ApiClient` 统一添加 `Authorization` header。页面和各业务 service 不要重复拼鉴权 header。当前 App 仍使用 `http://119.91.47.141`，域名 HTTPS 真机验证完成后再切到 `https://devinstock.cloud`。

### `lib/services/position_api_service.dart`

持仓 API service。

职责：

- 获取持仓。
- 创建持仓。
- 更新持仓。
- 删除持仓。
- 触发后端持仓快照计算。
- 读取最新持仓快照。
- 读取单只持仓交易历史。
- 读取单只持仓收益快照历史。
- 创建单只持仓交易记录，用于加仓、减仓和清仓。
- 后端 JSON 与 `StockPosition` 转换。

### `lib/services/quote_api_service.dart`

行情和 K 线 API service。

职责：

- 获取行情快照。
- 刷新行情快照。
- 获取 K 线缓存。
- 刷新 K 线。

注意：

- 当前 K 线刷新会优先请求后端 refresh 接口。
- refresh 成功时直接使用富途返回并写入后端缓存的真实 K 线。
- refresh 失败时才读取真实缓存，且读取真实缓存时会使用 `include_mock=false` 避免误把 mock 数据当成真实 K 线。
- 真实缓存也不可用时，才允许走后端 mock fallback，保证开发和离线场景仍可展示。

### `lib/services/backtest_api_service.dart`

回测 API service。

职责：

- 获取策略列表。
- 提交回测请求。
- 解析回测结果。
- 将后端结构化错误交给 `ApiClient` 统一处理。

量化页不直接拼 HTTP 请求；新增回测接口时优先扩展这里。

### `lib/services/signal_api_service.dart`

信号 API service。

职责：

- 读取后端 `signal_events`。
- 调用手动扫描接口。
- 读取和更新扫描配置。

当前支持按股票、信号类型、级别、来源分类、策略、推送候选和已读状态筛选。

### `lib/services/notification_api_service.dart`

通知 API service。

职责：

- 注册设备。
- 发送测试通知。
- 读取推送记录。

推送记录接口用于 App 展示某条信号是否已发送、跳过或失败。

### `lib/services/strategy_monitor_api_service.dart`

策略监控 API service。

职责：

- 访问 `strategies/monitors` 相关接口。
- 创建、更新、删除监控配置。
- 读取和控制 scheduler。

新增策略监控接口时优先扩展这里，再由 repository 暴露给页面。

### `lib/services/fund_api_service.dart`

场外基金 API service。

职责：

- 搜索基金。
- 获取基金账户汇总、持仓和净值历史。
- 获取基金交易记录。
- 创建和删除基金持仓。
- 创建基金交易记录。
- 读取和保存基金阈值提醒设置。
- 读取和保存基金提醒 scheduler 配置。
- 手动触发基金提醒扫描。

注意：

- 场外基金不走 Futu 行情接口。
- 盘中估算净值只能作为收盘前辅助判断，正式净值更新后以后端返回的正式净值和正式日涨跌为准。
- API 解析测试见 `mobile_app/test/fund_api_service_test.dart`。

### `lib/services/position_storage_service.dart`

本地持仓缓存。

用于后端不可用时保持 App 可用。

### `lib/services/stock_search_api_service.dart`

股票搜索 API。

用于添加持仓弹窗搜索股票、权证等标的。

### `lib/services/local_signal_service.dart`

本地信号生成服务。

当前规则：

- 止盈观察。
- 止损观察。
- 上涨异动。
- 下跌异动。

后续复杂策略不要继续塞这里。

## 8. Flutter 页面目录

### `lib/screens/app_shell.dart`

App 主壳。

职责：

- 底部导航。
- 当前市场筛选。
- 持仓状态。
- 策略阈值状态。
- 后端连接状态。
- 初始化 repository/service。
- 分发数据给首页、持仓、信号、设置页。

新增底部 Tab 或全局状态时优先看这里。

### `lib/screens/dashboard_screen.dart`

首页。

职责：

- 资产概览。
- 后端连接状态。
- 港股/美股切换。
- 持仓追踪。
- 最新信号。
- 账户入口。

首页不要承载复杂策略和回测功能。

### `lib/screens/positions_screen.dart`

持仓页。

职责：

- 完整持仓列表。
- 市场切换。
- 添加持仓。
- 点击进入详情。
- 当前已升级为券商式持仓记录表：
  - 第一列固定股票名称、代码、币种、市场标签。
  - 右侧指标列横向滑动。
  - 初始列展示可卖/持有、现价/成本、今日盈亏。
  - 右滑展示持仓盈亏、市值、持仓占比。
  - 核心收益指标来自后端 `position_snapshots`。
  - 后端快照不可用时显示未同步或空值，不用前端公式伪装成真实收益。
- 待完成：持仓排序、搜索、分组，以及是否需要订单/历史切换的产品决策。

如果要加排序、搜索、分组，优先从这里开始。持仓表格组件变复杂时，应拆到 `widgets/positions/`，不要把横向表格和行操作全部堆在 `positions_screen.dart`。

### `lib/screens/position_detail_screen.dart`

持仓详情页。

职责：

- 当前股票价格。
- 报价概览。
- 维护当前持仓详情状态。
- 维护 K 线周期、加载状态、刷新状态。
- 调用 `PositionKLineChart` 展示竖屏 K 线。
- 调用 `FullScreenKLineScreen` 展示横屏 K 线。
- 收益指标，核心收益来自后端快照。
- 加载并展示单股收益快照曲线。
- 加载并展示建仓、加仓、减仓、清仓交易历史。
- 打开加仓、减仓、清仓交易弹窗。
- 提交交易记录后刷新持仓列表、详情状态和详情数据。
- 编辑/删除持仓。

约束：

- 不在此文件继续堆叠 K 线绘制、指标计算、横屏布局。
- 新增 K 线指标、成交量图、十字光标、缩放逻辑时，优先放到 `widgets/chart/`。
- 此文件只负责页面状态编排和持仓详情业务动作。
- 不在此文件直接拼 HTTP；交易历史、收益快照、交易提交必须通过 `PositionRepository`。

### `lib/screens/signals_screen.dart`

信号页。

职责：

- 展示本地策略信号。
- 展示后端落库信号事件。
- 按分类进入信号列表。
- 在分类详情页按股票、策略、信号类型筛选。
- 提供信号设置入口，管理后端扫描配置启用状态和推送候选状态。
- 提供策略监控入口。
- 提供推送记录入口。
- 空状态。
- 刷新。

后续信号历史、已读未读、推送记录可从这里扩展，但复杂信号组件应放 `widgets/signal/`。如果筛选、设置、监控入口继续变复杂，应拆出独立 screen 或 widget，不要继续堆在单个文件。

### `lib/screens/strategy_monitor_screen.dart`

策略监控页。

职责：

- 读取当前持仓和后端策略列表。
- 创建股票 + 策略 + 参数的监控配置。
- 设置周期、扫描间隔、冷却时间、启用状态和推送候选。
- 展示已有策略监控列表。
- 开关或删除已有监控。
- 展示 scheduler 运行状态、扫描状态、上次结果和错误。
- 启动、停止或应用 scheduler 配置。

约束：

- 不在页面中实现策略判断。
- 不在页面中实现扫描循环。
- 不直接拼 HTTP。
- 后续如果要增加“从回测保存为监控”“按股票筛选监控”“监控详情页”，应继续拆组件或新增子页面。

### `lib/screens/push_records_screen.dart`

推送记录页。

职责：

- 读取后端 `push_records`。
- 展示信号事件、设备、provider、状态、尝试次数、发送时间和错误信息。
- 支持刷新和空/错状态。

后续如果从某条信号进入，应增加 `signalEventId` 过滤，不要在页面内本地遍历全部记录模拟筛选。

### `lib/screens/funds_screen.dart`

场外基金主页。

职责：

- 展示基金账户资产、当日收益、持有收益。
- 展示基金列表，采用紧凑表格风格，避免卡片过高。
- 搜索并添加场外基金。
- 提交基金买入、卖出、分红等交易记录。
- 设置单只基金涨跌阈值提醒、买入金额和卖出比例。
- 设置多个提醒时间，读取 scheduler 状态。
- 手动触发基金提醒扫描，展示最近扫描时间、触发数量和下次扫描。
- 展示基金策略提醒结果。

后续扩展基金页时，优先拆到 `widgets/fund/`，不要把筛选、表格、弹窗和 scheduler 面板继续堆在一个 screen 中。

### `lib/screens/fund_detail_screen.dart`

基金详情页。

职责：

- 展示单只基金名称、代码、当日涨跌、基金市值和持有收益。
- 顶部保持项目深色金融风格，不使用蓝色基金 App 头部。
- 加载最近 50 日净值数据。
- 展示业绩走势、沪深300对比、成本价均线、区间切换、净值列表、收益信息、我的收益曲线和提醒策略。
- 修改持仓入口支持“修正当前持仓”：按外部平台当前持有金额和持有收益反推份额与成本净值，可指定上次操作时间，并调用后端 `PUT /api/v1/funds/positions/{position_id}/holding` 替换旧导入交易。该修正记录的确认净值/时间会成为基金策略提醒的上次操作基准。
- 业绩走势展示基金自身长期净值收益，不是用户买入后的持仓收益；长期净值优先来自天天基金 `pingzhongdata` 的 `Data_netWorthTrend`，并合并最新净值表。我的收益页使用交易记录和净值重放累计收益曲线；加仓、减仓、修正持仓只能影响交易点、成本和策略基准，不得改变基金自身收益曲线。
- 业绩走势按所选区间固定横轴窗口；若持仓均价明显脱离当前净值区间，图表成本线优先按区间内交易记录推导，避免异常或未进入净值区间的交易压扁曲线。
- 沪深300基准接口优先使用 Eastmoney；云服务器访问 Eastmoney 断开时，后端回退到本机 FutuOpenD 的 `SH.000300` 日K，FutuOpenD 仍只允许本机访问。
- 在净值趋势图上标记买入、卖出等基金交易点位。
- 从基金主页进入，返回后不破坏基金列表状态。

### `lib/screens/quant_screen.dart`

量化页。

职责：

- 维护当前策略、股票代码、日期区间和策略参数状态。
- 调用 `BacktestApiService` 获取策略列表和运行回测。
- 组织量化页各面板展示。
- 展示加载、错误和回测结果。

约束：

- 不在此文件继续堆叠复杂卡片、图表 painter、格式化函数。
- 参数区、结果区、图表区优先放到 `widgets/quant/` 和 `widgets/backtest/`。
- 后续新增策略配置 UI 时，先拆成独立 widget，再由本页编排。

### `lib/screens/settings_screen.dart`

设置页。

职责：

- 策略阈值。
- 显示设置入口。
- 后端 API 状态。
- 推送占位。
- 富途行情占位。
- 版本信息。

如果继续增长，应拆 `widgets/settings/`。

### `lib/screens/notification_settings_screen.dart`

消息提醒设置页。

职责：

- 注册当前设备 token。
- 展示设备注册状态。
- 控制通知开关和重要通知开关。
- 发送测试通知。

App 只负责设备 token、权限和设置展示；后台推送扫描和分发由后端负责。

### `lib/screens/account_screen.dart`

我的/账户页。

职责：

- 用户信息。
- 会员卡片。
- 消息提醒。
- 显示设置。
- 盈亏分析入口。
- 策略实盘记录入口。
- 反馈和关于我们。

### `lib/screens/display_settings_screen.dart`

显示设置页。

职责：

- 日间模式。
- 夜间模式。

## 9. Flutter 弹窗目录

### `lib/sheets/add_position_sheet.dart`

添加/编辑持仓弹窗。

职责：

- 输入代码、名称、数量、成本价。
- 添加模式输入临时现价/昨收。
- 编辑模式展示行情只读卡。
- 本地和远程股票搜索。
- 保存后返回 `StockPosition`。

后续可继续拆：

```text
widgets/position/position_input.dart
widgets/position/stock_suggestion_list.dart
widgets/quote/quote_read_only_card.dart
```

### `lib/sheets/position_trade_sheet.dart`

持仓交易记录弹窗。

职责：

- 根据动作展示加仓、减仓或清仓表单。
- 输入数量、成交价格、手续费和备注。
- 清仓时默认使用当前持仓数量。
- 保存后返回 `PositionTradeDraft`。

约束：

- 不在弹窗里直接调用 HTTP。
- 不在弹窗里计算持仓成本或收益。
- 成本、收益和持仓数量更新以后端交易记录处理结果为准。

## 10. Flutter 工具目录

### `lib/utils/formatters.dart`

基础格式化：

- 金额。
- 百分比。
- 数字输入。
- 货币符号。

### `lib/utils/market_data_formatters.dart`

行情/K 线格式化：

- 报价。
- 成交量。
- 成交额。
- PE。
- 换手。
- 每手。
- K 线日期。

### `lib/utils/stock_suggestion_search.dart`

股票候选搜索工具：

- 本地搜索。
- 搜索关键词标准化。
- 是否包含衍生品。
- 候选列表比较。

### `lib/utils/theme_helpers.dart`

主题颜色工具。

新增 UI 优先使用这里，不要硬编码深色背景。

## 11. Flutter 组件目录

### `lib/widgets/common/`

通用组件：

- `app_tag.dart`
- `empty_state.dart`
- `market_switch.dart`
- `page_title.dart`
- `section_header.dart`

### `lib/widgets/position/`

持仓相关组件：

- `brokerage_position_table.dart`
- `position_tile.dart`
- `compact_metric.dart`
- `position_detail_metric.dart`
- `position_profit_curve.dart`
- `position_trade_history.dart`

#### `brokerage_position_table.dart`

券商式持仓表组件。

职责：

- 左侧固定股票名称、代码、市场和币种。
- 右侧指标区横向滑动。
- 第一屏展示可卖/持有、现价/成本、今日盈亏。
- 右滑展示持仓盈亏、市值和持仓占比。
- 行点击进入单股详情页。

后续订单、历史、排序和更多指标列应优先在本组件或同级拆分组件扩展，不要把横向表格逻辑堆回 `positions_screen.dart`。

#### `position_profit_curve.dart`

单股收益曲线组件。

职责：

- 接收后端 `PositionSnapshot` 历史快照。
- 按快照时间排序。
- 绘制 `totalProfit` 曲线。
- 快照不足时显示空状态。

约束：

- 只做展示，不计算持仓收益。
- 曲线点来自后端 `position_snapshots`。

#### `position_trade_history.dart`

单股交易历史组件。

职责：

- 展示建仓、加仓、减仓、清仓记录。
- 展示数量、成交价、手续费和成交时间。
- 根据动作类型显示不同颜色。

约束：

- 只展示后端 `position_trades`。
- 不在组件里修改持仓，不在组件里计算成本。

### `lib/widgets/quote/`

行情展示组件：

- `quote_overview_grid.dart`

后续盘口、逐笔、买卖盘组件放这里。

### `lib/widgets/chart/`

图表组件：

- `fullscreen_kline_screen.dart`
- `kline_chart_period.dart`
- `kline_chart_values.dart`
- `kline_info_panel.dart`
- `kline_painter.dart`
- `position_kline_chart.dart`

#### `position_kline_chart.dart`

竖屏持仓详情 K 线组件。

职责：

- 竖屏 K 线卡片布局。
- 加载、错误、空状态展示。
- 点选 K 线。
- 双指缩放。
- 单指横向浏览历史 K 线。
- 双击进入横屏全图。

#### `fullscreen_kline_screen.dart`

横屏 K 线全图页。

职责：

- 进入时锁定横屏并隐藏系统 UI。
- 退出时恢复竖屏和系统 UI。
- 展示横屏行情头部。
- 展示横屏周期栏。
- 复用 K 线信息面板、MA 条和 Painter。

#### `kline_painter.dart`

K 线画布绘制。

职责：

- K 线蜡烛图绘制。
- MA5、MA10、MA20、MA60 绘制。
- 高低点标签绘制。
- 十字光标绘制。
- 日期坐标轴绘制。

后续成交量柱、MACD、RSI、BOLL 图层优先在这里或新的同级 Painter 文件扩展。

#### `kline_info_panel.dart`

K 线信息展示组件。

职责：

- `KLineMaStrip` 展示 MA 数值。
- `SelectedCandleInfoPanel` 展示选中 K 线的日期、开高低收、成交量、成交额、涨跌幅。

#### `kline_chart_values.dart`

K 线计算和格式化工具。

职责：

- MA 数值计算。
- K 线价格格式化。
- K 线日期格式化。
- K 线成交量/成交额大数格式化。
- K 线涨跌颜色计算。

#### `kline_chart_period.dart`

定义分时、日 K、周 K、月 K 的周期参数和周期切换标签。

当前周期配置：

```text
分时 -> 1m，默认 240 根
日K  -> day，默认 360 根
周K  -> week，默认 240 根
月K  -> month，默认 180 根
```

后续 K 线相关开发优先在本目录扩展，不要回填到 `position_detail_screen.dart`。

### `lib/widgets/signal/`

信号组件：

- `signal_tile.dart`
- `signal_presentation.dart`

信号展示规则：

- `TradeSignal` 只保存数据。
- 分类标题、颜色、图标等 UI 展示逻辑放在 `signal_presentation.dart`。
- 后续新增复杂筛选控件时，优先拆到本目录。

### `lib/widgets/quant/`

量化页表单和面板组件：

- `quant_common_widgets.dart`
- `quant_panels.dart`
- `quant_strategy_panel.dart`
- `quant_config_panel.dart`
- `quant_stock_suggestion_list.dart`
- `quant_result_panel.dart`
- `quant_trade_list.dart`
- `quant_history_panel.dart`
- `quant_error_panel.dart`

#### `quant_common_widgets.dart`

量化页通用小组件。

当前包含：

- 卡片容器。
- 图标标题。
- 数值指标块。
- 股票代码快捷选择按钮。

#### `quant_panels.dart`

量化页组件导出入口。

职责：

- 统一导出策略、参数、结果、错误等量化组件。
- 保持 `quant_screen.dart` 的 import 简洁。
- 不再承载具体 UI 实现。

#### `quant_strategy_panel.dart`

策略选择面板。

职责：

- 策略选择面板。
- 策略列表加载态。
- 策略列表为空态。
- 刷新策略按钮。

#### `quant_config_panel.dart`

回测参数面板。

职责：

- 参数输入面板。
- 股票代码输入。
- 股票名称展示。
- 日期区间选择。
- 初始资金、手续费率、滑点率、短均线、长均线输入。
- 调用 `QuantStockSuggestionList` 展示股票搜索候选。

#### `quant_stock_suggestion_list.dart`

量化页股票搜索候选列表。

职责：

- 展示搜索加载态。
- 展示候选股票名称、代码、副标题和市场标签。
- 点击候选后回填量化参数。

#### `quant_result_panel.dart`

回测结果面板。

职责：

- 回测结果摘要。
- 收益曲线。
- 买卖点图入口。
- 交易记录列表。

#### `quant_history_panel.dart`

历史回测面板。

职责：

- 展示最近回测运行摘要。
- 展示回测状态、股票代码、策略、日期区间和收益率。
- 点击历史记录后由页面加载完整回测结果。
- 展示历史回测名称，支持编辑名称。
- 支持按股票代码、策略、状态筛选历史记录。
- 当前列表最多加载 30 条记录，后续如果数量继续增多，应改为分页或分页加载。
- 支持按单条历史记录删除，删除前由页面弹确认框。
- 支持一键删除全部历史记录，删除前由页面弹确认框。
- 删除操作必须调用 repository，不在组件内直接拼 HTTP 请求。

#### `quant_trade_list.dart`

交易记录列表。

职责：

- 展示买入/卖出标签。
- 展示交易日期、数量和价格。
- 交易记录必须完整可查看，不允许只截断展示前几条。
- 当前组件采用固定高度滚动卡片，默认约显示 8 行高度，用户可在卡片内滚动查看全部交易。

#### `quant_error_panel.dart`

量化页错误面板。

职责：

- 展示 `ApiException` 的结构化错误消息。
- 兼容普通异常文本。

后续如果策略参数继续增多，应优先新增独立参数组件，不要把实现堆回 `quant_panels.dart`。

### `lib/widgets/backtest/`

回测结果图表组件：

- `backtest_equity_chart.dart`
- `backtest_kline_trade_chart.dart`
- `backtest_kline_trade_painter.dart`
- `backtest_chart_values.dart`

#### `backtest_equity_chart.dart`

收益曲线图。

职责：

- 根据 `BacktestEquityPoint` 绘制资金/收益变化。
- 展示首尾日期和收益刻度。
- 只负责结果展示，不处理回测请求。

#### `backtest_kline_trade_chart.dart`

回测买卖点 K 线图。

职责：

- 维护回测 K 线的可视窗口、选中点和手势状态。
- 处理点击、横向拖动和双指缩放。
- 调用 `BacktestKlineTradePainter` 完成实际绘制。

注意：它是量化页专用图表入口，不要影响持仓详情页的 `widgets/chart/` K 线。

#### `backtest_kline_trade_painter.dart`

回测买卖点 K 线图 painter。

职责：

- 绘制量化页专用 K 线主体。
- 绘制 MA5、MA20。
- 在 K 线上标记买入、卖出点。
- 绘制选中 K 线的信息面板、十字线、价格和日期标签。
- 绘制图表边框、网格和坐标文案。

约束：

- 不在 painter 内发起网络请求。
- 不在 painter 内维护 widget 状态。
- 新增成交量、MACD、RSI、BOLL 等图层时，优先在本文件或同级新 painter 文件扩展。
- 如果某个指标需要复杂计算，先放到 `backtest_chart_values.dart`，不要直接堆在 painter 里。

注意：它只服务量化页回测结果图，不要复用到持仓详情页，以免破坏现有持仓 K 线交互。

#### `backtest_chart_values.dart`

回测 K 线图的纯计算和格式化工具。

职责：

- `BacktestViewWindow`：根据缩放/拖动状态计算可视窗口。
- `BacktestPriceRange`：根据 K 线、均线、交易点计算绘图区价格范围。
- `calculateMovingAverage`：计算均线。
- `visibleBacktestTrades`：筛选当前可视区间内的交易记录。
- `formatBacktestAxisDate`、`formatBacktestFullDate`、`formatBacktestCompactNumber`：图表日期和数值格式化。

后续新增图表指标时应继续复用本文件，不要把这些计算逻辑搬回 UI 或 painter。

## 12. Flutter 测试目录

### `mobile_app/test/market_data_models_test.dart`

测试：

- `QuoteSnapshot` JSON 解析。
- `Candle` JSON 解析和序列化。

### `mobile_app/test/widget_test.dart`

测试：

- 首页核心区域渲染。

后续应补充：

- 持仓收益计算。
- 信号生成。
- 编辑持仓后留在详情页。
- API service 解析。
- 回测模型解析。

## 13. 后端结构

```text
backend/app/
  __init__.py
  db/
    __init__.py
    core.py
    converters.py
    init.py
    seed.py
  errors.py
  main.py
  database.py
  mock_store.py
  repositories/
    __init__.py
    backtests.py
    fund_alert_scheduler.py
    funds.py
    market_data.py
    notifications.py
    position_snapshots.py
    position_trades.py
    positions.py
    strategies.py
    strategy_monitors.py
  routers/
  schemas/
  schemas.py
  services/
    __init__.py
    fund_alert_scanner.py
    fund_alert_scheduler.py
    fund_provider.py
    funds.py
    futu_client.py
    futu_import.py
    push_service.py
    signal_scanner.py
    stock_search.py
    strategy_monitor_scheduler.py
    strategy_monitor_scanner.py
```

### `backend/app/main.py`

FastAPI 入口。

当前包含：

- UTF-8 JSON 响应头配置。
- lifespan 启动/关闭生命周期。
- 系统健康检查。
- 持仓 API。
- 行情 API。
- K 线 API。
- 信号 API。
- 股票搜索 API。
- 富途健康检查。
- 富途报价。
- 富途 K 线额度。
- 基金 API。
- 基金提醒 scheduler 生命周期。
- 刷新行情。
- 刷新 K 线。
- 统一抛出结构化 API 错误。

后续建议拆分 routers：

```text
backend/app/routers/positions.py
backend/app/routers/quotes.py
backend/app/routers/signals.py
backend/app/routers/stocks.py
backend/app/routers/futu.py
backend/app/routers/strategies.py
backend/app/routers/backtests.py
```

### `backend/app/errors.py`

后端结构化错误定义。

当前错误响应统一为：

```json
{
  "detail": {
    "code": "FUTU_UNAVAILABLE",
    "message": "FutuOpenD 不可用或富途接口调用失败",
    "detail": {}
  }
}
```

当前错误码：

- `POSITION_NOT_FOUND`
- `FUTU_DEPENDENCY_MISSING`
- `FUTU_UNAVAILABLE`
- `FUTU_NO_DATA`

新增后端错误时优先在这里补错误码和 helper，不要在路由里散落裸 `HTTPException` 字符串。

### `backend/app/database.py`

数据库兼容门面。

当前职责：

- 继续导出旧调用方依赖的数据库函数。
- 保留 `init_database`、`list_positions`、`upsert_quote`、`list_candles`、`create_backtest_run` 等原函数名。
- 保留测试中使用的 `_connect`。
- 不再承载具体 SQL 实现。

约束：

- 新增数据库读写不要继续写回 `database.py`。
- 业务读写应放入 `backend/app/repositories/`。
- 连接、SQL 方言兼容、初始化、seed 和转换工具应放入 `backend/app/db/`。

### `backend/app/db/core.py`

数据库底层连接和 SQL 适配。

职责：

- 读取 `.env` 中的 `DATABASE_URL`。
- 管理 SQLite/PostgreSQL 连接。
- 将 SQLite 风格的 `?` 占位符转换为 PostgreSQL 的 `%s`。
- 提供 `_connect`、`_uses_postgres`、`_ensure_column` 等底层工具。

### `backend/app/db/init.py`

数据库表结构初始化。

职责：

- 创建 `positions`、`quote_snapshots`、`klines`、`strategy_definitions`、`backtest_runs`、`backtest_equity_curve`、`backtest_trades`、`strategy_signals`、`fund_positions`、`fund_trades`、`fund_navs`、`fund_alert_scheduler`。
- 补齐历史缺失字段。
- 调用 seed 和历史名称修复。

### `backend/app/db/converters.py`

数据库行转换和序列化工具。

职责：

- Pydantic 模型转 SQL 参数 tuple。
- SQL row 转 Pydantic 模型。
- 日期时间格式化和解析。
- JSON 字段序列化和反序列化。

### `backend/app/db/seed.py`

默认种子数据和历史修复。

职责：

- 初始化默认持仓。
- 初始化默认行情快照。
- 初始化默认策略定义。
- 修复历史持仓名称乱码。

### `backend/app/repositories/positions.py`

持仓数据库读写。

职责：

- `list_positions`
- `create_position`
- `update_position`
- `delete_position`
- `get_position`

创建持仓时会自动写入一条 `open` 建仓交易记录，便于后续保留持仓生命周期。

### `backend/app/repositories/position_trades.py`

持仓交易记录数据库读写。

职责：

- `list_position_trades`
- `create_position_trade_for_position`

交易记录用于保存建仓、加仓、减仓、清仓历史；删除当前持仓不应删除历史交易记录。

当前聚合规则：

- `open`：仅允许空仓建仓。
- `add`：增加数量，并按加权平均更新成本。
- `reduce`：减少数量，真实平均成本不变，券商式摊薄成本按卖出净收入重新摊薄；超过当前持仓数量返回错误。
- `close`：必须等于当前持仓数量，清仓后数量和成本归零。

成本字段口径：

- `cost_price`：兼容旧 App 字段，当前等于非负的券商式摊薄成本。
- `avg_cost_price`：真实平均买入成本，加仓会变，减仓不变。
- `adjusted_cost_price`：券商式摊薄成本，加仓、减仓都会变，可用于持仓表显示。
- `realized_profit`：已实现盈亏，减仓和清仓时累计。

### `backend/app/repositories/position_snapshots.py`

持仓收益快照数据库读写。

职责：

- `save_position_snapshots`
- `list_position_snapshots`
- `list_latest_position_snapshots`

收益快照用于券商式持仓表和单股收益曲线。

### `backend/app/services/position_snapshots.py`

持仓收益快照计算服务。

职责：

- 读取当前持仓。
- 读取当前行情。
- 计算市值、今日盈亏、持仓盈亏、总收益、持仓占比。
- 写入 `position_snapshots`。

### `backend/app/repositories/strategy_monitors.py`

股票/持仓与策略监控配置的数据库读写。

职责：

- 创建、读取、更新、删除 `strategy_monitors`。
- 支持按 `position_id`、股票代码、策略 code、启用状态筛选。
- 保存扫描周期、冷却时间、推送候选、来源回测和最近扫描状态。
- 不直接计算策略信号，策略信号由 service 层生成。

### `backend/app/services/strategy_monitor_scanner.py`

单股策略监控扫描服务。

职责：

- 读取已启用的 `strategy_monitors`。
- 按监控配置读取或刷新 K 线。
- 复用 `backend/app/strategies/` 下的策略语义计算最新信号。
- 按监控 ID、策略、参数、方向和 K 线时间生成去重 key。
- 先写入 `signal_events`，再更新监控扫描状态。
- 遵守扫描间隔和冷却时间，避免盘中反复触发刷屏。

### `backend/app/services/strategy_monitor_scheduler.py`

策略监控后台调度服务。

职责：

- 按固定轮询间隔触发 `strategy_monitor_scanner.py`。
- 通过环境变量控制是否随后端启动自动运行。
- 通过 API 支持状态查询、启动和停止。
- 保存最近运行时间、最近结果和最近错误，便于 App 或运维页面展示。
- 第一版使用轻量 asyncio 后台任务，后续迁移 APScheduler/Celery 时应保留当前 service 边界。

### `backend/app/repositories/funds.py`

场外基金数据库读写。

职责：

- 基金持仓 CRUD。
- 基金交易记录读写。
- 基金净值缓存读写。
- 基金阈值提醒设置保存和读取。
- 将数据库行转换为基金领域模型。

### `backend/app/repositories/fund_alert_scheduler.py`

基金提醒 scheduler 配置读写。

职责：

- 保存多个提醒时间、启用状态和刷新间隔。
- 保存最近扫描时间、下次扫描时间、触发数量和错误信息。
- 只做配置和状态持久化，不计算基金信号。

### `backend/app/services/fund_provider.py`

场外基金数据源 provider。

职责：

- 搜索基金。
- 获取正式净值、估算净值和净值历史。
- 将第三方数据源字段转换为项目内部字段。

注意：当前基金数据源是第三方基金数据接口，网络和响应稳定性可能弱于 Futu；后续若真机刷新慢，应优先加缓存 TTL、重试和降级提示。

### `backend/app/services/funds.py`

基金业务聚合服务。

职责：

- 汇总基金账户资产、当日收益和持有收益。
- 根据估算净值/正式净值选择展示口径。
- 生成单只基金的阈值提醒建议。
- 处理基金交易后基准净值和份额变化。

### `backend/app/services/fund_alert_scanner.py`

基金提醒扫描服务。

职责：

- 读取基金持仓和提醒设置。
- 刷新基金估算/正式净值。
- 根据用户阈值判断是否触发加仓/减仓观察提醒。
- 将触发结果写入 `signal_events`。

### `backend/app/services/fund_alert_scheduler.py`

基金提醒后台调度服务。

职责：

- 根据用户配置的多个提醒时间自动运行基金扫描。
- 保存最近扫描结果、下次扫描时间和错误信息。
- 支持手动扫描。
- 调度层只负责定时和状态记录，不写策略计算、不写 SQL。

### `backend/app/repositories/market_data.py`

行情和 K 线 repository。

当前特别注意：

- 量化回测和回测历史详情会按股票、周期、日期区间读取 K 线。
- PostgreSQL 子查询必须写成 `FROM (...) AS alias`，不能省略别名。
- 最近一次云端回测 500 就是该兼容性问题导致，已在 `a92a987` 修复。

行情和 K 线数据库读写。

职责：

- `get_quotes`
- `upsert_quote`
- `list_candles`
- `list_candles_between`
- `upsert_candles`

### `backend/app/repositories/strategies.py`

策略定义数据库读写。

职责：

- `list_strategy_definitions`
- `create_strategy_definition`

### `backend/app/repositories/backtests.py`

回测运行和结果数据库读写。

职责：

- `create_backtest_run`
- `list_backtest_runs`
- `get_backtest_result`
- `delete_backtest_run`
- `delete_all_backtest_runs`
- `rename_backtest_run`
- `save_backtest_result`

### `backend/app/mock_store.py`

模拟/本地数据存储。

后续如果全面迁移数据库，应逐步减少这里的正式逻辑。

### `backend/app/schemas.py`

Pydantic schema。

新增 API 输入/输出模型时放这里，后续变大可拆成：

```text
backend/app/schemas/positions.py
backend/app/schemas/quotes.py
backend/app/schemas/signals.py
backend/app/schemas/backtests.py
```

### `backend/app/services/futu_client.py`

富途 API 封装。

职责：

- 富途健康检查。
- 获取行情快照。
- 获取 K 线。
- K 线额度。
- 错误转换。

### `backend/app/services/futu_import.py`

富途 SDK 导入辅助。

### `backend/app/services/stock_search.py`

股票搜索服务。

### `backend/app/services/signal_scan_config.py`

后端策略信号扫描配置。

职责：

- 定义 `SignalScanConfig`。
- 提供默认扫描策略和参数列表。
- 让 `signal_scanner.py` 专注扫描流程，不直接硬编码“扫哪些策略”。

## 14. 后续新增功能应放哪里

### 新增页面

放：

```text
mobile_app/lib/screens/
```

复杂子组件放：

```text
mobile_app/lib/widgets/<domain>/
```

### 新增后端 API 调用

放：

```text
mobile_app/lib/services/<domain>_api_service.dart
```

如果需要合并本地缓存/多个 API：

```text
mobile_app/lib/repositories/<domain>_repository.dart
```

### 新增业务模型

放：

```text
mobile_app/lib/models/
```

### 新增格式化/计算工具

放：

```text
mobile_app/lib/utils/
```

### 新增策略量化

Flutter：

```text
mobile_app/lib/models/strategy_definition.dart
mobile_app/lib/models/backtest_result.dart
mobile_app/lib/services/strategy_api_service.dart
mobile_app/lib/services/backtest_api_service.dart
mobile_app/lib/repositories/strategy_repository.dart
mobile_app/lib/repositories/backtest_repository.dart
mobile_app/lib/screens/strategy_lab_screen.dart
mobile_app/lib/widgets/strategy/
mobile_app/lib/widgets/backtest/
```

后端：

```text
backend/app/strategies/
backend/app/backtest/
backend/app/routers/strategies.py
backend/app/routers/backtests.py
```

### 新增推送

Flutter：

```text
mobile_app/lib/services/notification_service.dart
mobile_app/lib/services/push_token_service.dart
mobile_app/lib/repositories/notification_repository.dart
mobile_app/lib/screens/notification_settings_screen.dart
mobile_app/lib/models/notification_models.dart
```

后端：

```text
backend/app/schemas/notifications.py
backend/app/repositories/notifications.py
backend/app/services/signal_scanner.py
backend/app/services/signal_scan_config.py
backend/app/services/push_service.py
backend/app/services/push_providers/fcm.py
backend/app/routers/notifications.py
```

当前已落地：

- `backend/app/schemas/notifications.py`
- `backend/app/repositories/notifications.py`
- `backend/app/routers/notifications.py`
- `backend/app/services/signal_scanner.py`
- `backend/app/services/signal_scan_config.py`
- `backend/app/services/push_service.py`
- `backend/app/services/push_providers/fcm.py`
- `mobile_app/lib/models/notification_models.dart`
- `mobile_app/lib/repositories/notification_repository.dart`
- `mobile_app/lib/services/notification_api_service.dart`
- `mobile_app/lib/services/push_token_service.dart`
- `mobile_app/lib/screens/notification_settings_screen.dart`
- `signal_events`、`notification_devices`、`push_records` 三张表

推送结构约束：

- `notification_service.dart` 继续负责 App 内本地通知展示。
- `push_token_service.dart` 负责获取、刷新和上报设备 token。
- `notification_repository.dart` 负责通知设置、测试通知、设备注册接口，不在页面里直接拼 HTTP。
- `signal_scanner.py` 负责后端扫描持仓和行情并生成信号事件。
- `signal_scan_config.py` 负责提供后端扫描策略配置，后续可迁移到数据库和 App 设置。
- `push_service.py` 负责编排推送、同一信号同一设备去重、设备开关、重要通知开关和记录结果。
- `push_providers/` 下按通道拆实现，第一版优先 `fcm.py`，后续再加厂商推送。
- 信号必须先落库再推送，推送失败不能导致信号丢失。
- `POST /api/v1/notifications/signals/{event_id}/dispatch` 用于把已落库信号分发到已登记设备。
- 策略监控扫描创建 `push_candidate=true` 信号后，会调用 push service 写入 `push_records`；推送失败或通道未配置时记录为 `failed` 或 `skipped`，不影响信号历史。

## 15. 后端路由结构

```text
backend/app/main.py
backend/app/routers/__init__.py
backend/app/routers/health.py
backend/app/routers/positions.py
backend/app/routers/quotes.py
backend/app/routers/klines.py
backend/app/routers/signals.py
backend/app/routers/stocks.py
backend/app/routers/futu.py
backend/app/routers/funds.py
```

### `backend/app/main.py`

后端应用入口。当前只负责：

- 创建 FastAPI app。
- 设置 UTF-8 JSON response。
- 通过 lifespan 初始化数据库和策略监控 scheduler。
- 注册 routers。

不应继续把具体业务接口写进 `main.py`。

### `backend/app/routers/health.py`

系统健康检查和根路径：

- `GET /health`
- `GET /`

### `backend/app/routers/positions.py`

持仓接口：

- `GET /api/v1/positions`
- `POST /api/v1/positions`
- `PUT /api/v1/positions/{position_id}`
- `DELETE /api/v1/positions/{position_id}`
- `GET /api/v1/positions/trades`
- `GET /api/v1/positions/{position_id}/trades`
- `POST /api/v1/positions/{position_id}/trades`
- `GET /api/v1/positions/snapshots`
- `GET /api/v1/positions/snapshots/latest`
- `POST /api/v1/positions/snapshots/capture`
- `GET /api/v1/positions/{position_id}/snapshots`

交易记录接口用于建仓、加仓、减仓、清仓历史；当前持仓快照仍由 `positions` 表维护。
收益快照接口用于生成和读取券商式持仓表指标。

### `backend/app/routers/quotes.py`

行情快照接口：

- `GET /api/v1/quotes`
- `POST /api/v1/quotes/refresh`

### `backend/app/routers/klines.py`

K 线接口：

- `GET /api/v1/klines/{stock_code}`
- `POST /api/v1/klines/refresh`

### `backend/app/routers/signals.py`

信号接口：

- `GET /api/v1/signals`
- `GET /api/v1/signals/events`
- `POST /api/v1/signals/scan`
- `PUT /api/v1/signals/events/{event_id}/read`
- `PUT /api/v1/signals/events/{event_id}/ignore`
- `GET /api/v1/signals/configs`
- `POST /api/v1/signals/configs`
- `PUT /api/v1/signals/configs/{config_id}`
- `POST /api/v1/signals/configs/reset-defaults`

`GET /api/v1/signals/events` 当前筛选参数：

- `code`
- `strategy_code`
- `signal_type`
- `source_category`
- `level`
- `push_candidate`
- `read_status`
- `limit`

`PUT /api/v1/signals/configs/{config_id}` 当前用于 App 信号设置页：

- `enabled=false`：不再扫描该策略条件。
- `push_candidate=false`：继续落库展示，但不进入推送候选。

### `backend/app/routers/stocks.py`

股票搜索接口：

- `GET /api/v1/stocks/search`

### `backend/app/routers/futu.py`

富途直连检查和辅助接口：

- `GET /api/v1/futu/health`
- `GET /api/v1/futu/quote`
- `GET /api/v1/futu/kline-quota`

### `backend/app/routers/funds.py`

场外基金接口：

- `GET /api/v1/funds/search`
- `GET /api/v1/funds/positions/summary`
- `GET /api/v1/funds/benchmarks/hs300/navs`
- `GET /api/v1/funds/{fund_code}/quote`
- `GET /api/v1/funds/{fund_code}/navs`
- `POST /api/v1/funds/positions`
- `PUT /api/v1/funds/positions/{position_id}`
- `PUT /api/v1/funds/positions/{position_id}/holding`
- `DELETE /api/v1/funds/positions/{position_id}`
- `GET /api/v1/funds/positions/{position_id}/trades`
- `POST /api/v1/funds/positions/{position_id}/trades`
- `GET /api/v1/funds/positions/{position_id}/trade-records`
- `POST /api/v1/funds/positions/{position_id}/trade-records`
- `DELETE /api/v1/funds/positions/{position_id}/trade-records/{record_id}`
- `GET /api/v1/funds/alerts/scheduler/status`
- `PUT /api/v1/funds/alerts/scheduler/config`
- `POST /api/v1/funds/alerts/scheduler/run-once`
- `POST /api/v1/funds/alerts/scan`

基金接口用于场外开放式基金管理，和 Futu 股票/交易所行情接口分开维护。

### `backend/app/routers/portfolio_strategy.py`

美股组合建议接口：

- `GET /api/v1/portfolio-strategy/us`

当前实现读取 `positions` 中数量大于 0 的美股持仓，并从 `quote_snapshots` 读取最新行情；调用方可通过 `cash` 查询参数传入当前现金。返回内容包括资产明细、核心/现金类/杠杆/半导体/成长权重、指标状态和人工确认建议。该功能当前后端测试已覆盖，但已决定暂作为后备功能，不继续移动端入口和云端部署推进。

### `backend/app/routers/strategies.py`

策略定义和策略监控接口：

- `GET /api/v1/strategies`
- `GET /api/v1/strategies/monitors`
- `POST /api/v1/strategies/monitors`
- `PUT /api/v1/strategies/monitors/{monitor_id}`
- `DELETE /api/v1/strategies/monitors/{monitor_id}`
- `POST /api/v1/strategies/monitors/scan`
- `GET /api/v1/strategies/monitors/scheduler/status`
- `POST /api/v1/strategies/monitors/scheduler/start`
- `POST /api/v1/strategies/monitors/scheduler/stop`
- `POST /api/v1/strategies/monitors/scheduler/run-once`
- `GET /api/v1/strategies/monitors/scan-logs`
- `DELETE /api/v1/strategies/monitors/scan-logs/{log_id}`

后续新增策略和回测时，应继续按领域新增：

```text
backend/app/routers/strategies.py
backend/app/routers/backtests.py
```

## 16. 后端数据模型结构

```text
backend/app/schemas/__init__.py
backend/app/schemas/common.py
backend/app/schemas/positions.py
backend/app/schemas/quotes.py
backend/app/schemas/klines.py
backend/app/schemas/signals.py
backend/app/schemas/stocks.py
backend/app/schemas/funds.py
```

### `backend/app/schemas/__init__.py`

统一导出旧接口，保证现有代码仍可使用：

```python
from app.schemas import Position, Candle
```

### `backend/app/schemas/common.py`

公共类型定义，目前包含市场类型 `Market`。

### `backend/app/schemas/positions.py`

持仓相关数据模型：

- `PositionCreate`
- `PositionUpdate`
- `Position`
- `PositionTradeCreate`
- `PositionTrade`
- `PositionSnapshot`

`PositionTrade` 的 `action` 当前支持：

- `open`
- `add`
- `reduce`
- `close`

### `backend/app/schemas/quotes.py`

行情快照模型：

- `QuoteSnapshot`

### `backend/app/schemas/klines.py`

K 线模型：

- `Candle`

### `backend/app/schemas/signals.py`

信号模型：

- `Signal`

### `backend/app/schemas/stocks.py`

股票搜索模型：

- `StockSearchResult`

### `backend/app/schemas/funds.py`

场外基金模型：

- `FundSearchResult`
- `FundNavPoint`
- `FundPosition`
- `FundPositionSummary`
- `FundGridRecommendation`
- `FundAlertSettings`
- `FundAlertSchedulerStatus`
- `FundTrade`

后续新增策略和回测时，应继续按领域新增：

```text
backend/app/schemas/strategies.py
backend/app/schemas/backtests.py
```

## 17. 策略和回测预留结构

后续策略和回测模块按以下结构新增：

```text
backend/app/schemas/strategies.py
backend/app/schemas/backtests.py
backend/app/routers/strategies.py
backend/app/routers/backtests.py
backend/tests/test_strategy_backtest_database.py
```

当前上述文件已经创建，负责策略定义、回测任务创建和回测结果读取的最小后端骨架。

当前数据库仓储层已经拆出，后续不要再把具体 SQL 写回 `backend/app/database.py`：

```text
backend/app/repositories/positions.py
backend/app/repositories/market_data.py
backend/app/repositories/strategies.py
backend/app/repositories/strategy_monitors.py
backend/app/repositories/backtests.py
```

当前 routers 和 `backend/app/backtest/engine.py` 已经直接引用对应 repository；`database.py` 只保留旧测试和兼容导出。

策略和回测相关数据表预留：

```text
strategy_definitions
strategy_parameters
backtest_runs
backtest_equity_curve
backtest_trades
strategy_signals
```

当前已创建：

```text
strategy_definitions
strategy_parameters
backtest_runs
backtest_equity_curve
backtest_trades
strategy_signals
```

当前默认策略：

```text
code: ma_cross
name: MA Cross
default_parameters: short_window=5, long_window=20
```

下一步策略扩展计划：

```text
backend/app/strategies/base.py
backend/app/strategies/factors.py
backend/app/strategies/registry.py
backend/app/strategies/ma_cross.py
backend/app/strategies/rsi_reversal.py
```

职责边界：

- `base.py`：定义策略输入、信号输出和策略接口。
- `factors.py`：放 MA、RSI 等可复用技术指标计算。
- `ma_cross.py`：只放双均线策略信号逻辑。
- `rsi_reversal.py`：只放 RSI 反转策略信号逻辑。
- `registry.py`：按 `strategy_code` 注册和查找策略。
- `backend/app/backtest/engine.py`：继续负责回测执行、交易撮合、手续费、滑点、仓位、净值曲线和结果保存，不继续堆策略判断。

RSI 策略第一版建议：

```text
strategy_code: rsi_reversal
default_parameters:
  rsi_window: 14
  oversold: 30
  overbought: 70
```

当前上述策略目录已经创建：

- `base.py`：定义策略接口、策略信号和策略配置错误。
- `factors.py`：包含 `moving_average`、`relative_strength_index`、EMA 和 MACD 计算。
- `ma_cross.py`：双均线信号逻辑。
- `rsi_reversal.py`：RSI 超卖回升买入、超买回落卖出信号逻辑。
- `macd_trend.py`：MACD 柱由负转正买入、由正转负卖出信号逻辑。
- `registry.py`：根据 `strategy_code` 查找策略实现。

后续新增 BOLL、成交量动量等策略时，应继续在 `strategies/` 下新增独立文件，不要把策略判断写回 `backtest/engine.py`。

## 18. 回测引擎结构

```text
backend/app/backtest/__init__.py
backend/app/backtest/engine.py
```

### `backend/app/backtest/engine.py`

当前通用回测引擎。当前职责：

- 接收 `BacktestRun`。
- 按 `stock_code`、`period`、`start_date`、`end_date` 读取 K 线。
- 通过 `strategies/registry.py` 按 `strategy_code` 获取策略实现。
- 当前支持 `ma_cross`、`rsi_reversal`、`macd_trend`。
- 计算买入、卖出、手续费、滑点、现金、持仓、市值、净值和回撤。
- 写入 `backtest_equity_curve` 和 `backtest_trades`。
- 更新 `backtest_runs.status` 和 `summary`。

当前 `POST /api/v1/backtests` 会同步执行回测并返回 `BacktestResult`。

多策略结构约束：

- `engine.py` 不直接判断所有策略细节，必须通过 `strategies/registry.py` 获取策略。
- 策略模块只负责产生买入/卖出信号。
- 回测引擎继续统一处理成交价格、手续费、滑点、持仓、净值曲线、交易记录和保存。
- 新增 BOLL、成交量动量等策略时优先新增策略文件，不要把所有逻辑写回 `engine.py`。

## 19. App 量化入口结构

```text
mobile_app/lib/models/strategy_definition.dart
mobile_app/lib/models/backtest_models.dart
mobile_app/lib/services/backtest_api_service.dart
mobile_app/lib/repositories/backtest_repository.dart
mobile_app/lib/screens/quant_screen.dart
mobile_app/lib/widgets/quant/quant_panels.dart
mobile_app/lib/widgets/quant/quant_common_widgets.dart
mobile_app/lib/widgets/backtest/backtest_equity_chart.dart
mobile_app/lib/widgets/backtest/backtest_kline_trade_chart.dart
```

### `mobile_app/lib/models/strategy_definition.dart`

后端策略定义模型，对应 `GET /api/v1/strategies` 返回的数据。

### `mobile_app/lib/models/backtest_models.dart`

App 端回测模型：

- `BacktestRequest`
- `BacktestRun`
- `BacktestEquityPoint`
- `BacktestTrade`
- `BacktestResult`

### `mobile_app/lib/services/backtest_api_service.dart`

回测 API 调用层：

- `fetchStrategies()`
- `runBacktest()`

### `mobile_app/lib/repositories/backtest_repository.dart`

回测仓储层，负责隔离页面和 API service。

动态参数 UI 要继续通过 repository/service 读取策略定义，不要在页面里写死所有策略参数。

### `mobile_app/lib/screens/quant_screen.dart`

量化页面。当前职责：

- 维护量化页状态。
- 加载策略列表。
- 处理股票搜索状态。
- 调用后端启动回测。
- 加载回测图表 K 线时优先读取后端真实缓存，缓存为空才刷新，避免富途 refresh 返回旧区间导致回测买卖点图被日期过滤为空。
- 根据选中的策略构建参数：
  - `ma_cross`：`short_window`、`long_window`。
  - `rsi_reversal`：`rsi_window`、`oversold`、`overbought`。
- 提交前进行策略参数校验。
- 结果区展示 `summary` 中的总收益、最大回撤、期末权益、交易次数、胜率和买卖回合。
- 胜率来自后端 `win_rate`，App 不重新计算。
- 结果区展示参数快照，包含 `BacktestRun` 中的通用参数和策略参数；手机端使用紧凑三栏布局，长日期区间单独占满一行。

历史详情数据读取约束：

- 历史列表只展示 `BacktestRun` 摘要。
- 点击历史记录后再读取完整 `BacktestResult`。
- K 线数据从现有 `klines` 表按股票、周期和日期范围读取。
- 不要把 K 线快照复制到 `backtest_runs` 或新的回测详情表。

页面展示组件已经拆到 `mobile_app/lib/widgets/quant/`，不要再把策略面板、参数面板、结果面板继续堆回 `quant_screen.dart`。

### `mobile_app/lib/widgets/quant/quant_panels.dart`

量化页主要 UI 面板：

- `QuantStrategyPanel`：策略下拉和刷新。
- `QuantConfigPanel`：股票代码、日期、资金、手续费、滑点和均线参数。
- `QuantResultPanel`：回测摘要、参数快照、收益曲线、K 线买卖点和交易记录。
- `QuantHistoryPanel`：历史回测列表、筛选、编辑名称、单条删除和一键删除；列表项已做紧凑展示，名称一行省略，元信息使用小字号排列。
- `QuantErrorPanel`：接口错误展示。

### `mobile_app/lib/widgets/quant/quant_common_widgets.dart`

量化页通用 UI 小组件：

- `QuantPanel`
- `QuantPanelHeader`
- `QuantNumberField`
- `QuantDateButton`
- `QuantMetric`

股票搜索相关实现：

- 复用 `StockSearchApiService` 调用 `/api/v1/stocks/search`。
- 复用 `stock_suggestion_search.dart` 的本地候选和查询标准化逻辑。
- 输入未完整匹配时展示候选列表，点击候选后自动填入股票代码。
- 输入完整代码时显示股票名称并隐藏候选，避免参数区过度拥挤。

均线参数说明：

- `short_window` 和 `long_window` 默认值为 5 和 20。
- 默认值不代表固定限制，用户可在量化页输入其他正整数。
- 后端要求短均线必须小于长均线，否则回测会返回参数错误。

### `mobile_app/lib/widgets/backtest/backtest_equity_chart.dart`

回测净值曲线组件。当前使用 `BacktestEquityPoint.equity` 绘制折线图，展示回测期间账户权益变化。

### `mobile_app/lib/widgets/backtest/backtest_kline_trade_chart.dart`

量化页专用 K 线买卖点图组件。当前使用回测股票的日 K 绘制蜡烛图、MA5、MA20，并使用 `BacktestTrade` 在交易日期附近标记 B / S。

该组件是回测专用图，不复用也不改动 `mobile_app/lib/widgets/chart/` 下的持仓详情 K 线模块，避免影响现有详情页缩放和横屏逻辑。

当前交互能力：

- 双指缩放可见 K 线数量。
- 单指横向拖动浏览历史 K 线。
- 点击 K 线后显示日期、开高低收、涨跌幅和当日买卖信号。
- 默认信息栏显示当前可见区间最后一根 K 线。

数据来源要求：

- 使用 `AppShell._loadBacktestCandles()` 读取后端缓存 K 线。
- 不直接复用详情页的 `_loadCandles()` refresh 流程。
- 回测图和回测引擎应尽量使用同源历史数据，避免图表区间与回测区间不一致。

当前量化入口已加入 `mobile_app/lib/screens/app_shell.dart` 底部导航，顺序为：

```text
首页 / 持仓 / 量化 / 信号 / 设置
```

## 20. 当前最需要关注的结构问题

- K 线图表已从 `position_detail_screen.dart` 拆到 `widgets/chart/`。
- 后续应继续关注 `fullscreen_kline_screen.dart` 和 `position_kline_chart.dart` 的内部复用，避免横屏/竖屏手势逻辑重复扩大。
- `add_position_sheet.dart` 可继续拆 UI 子组件。
- `backend/app/main.py` 已拆 routers，后续不要重新塞入具体业务接口。
- `backend/app/schemas.py` 已拆为 `backend/app/schemas/` 包，后续策略和回测模型继续按领域新增文件。
- 策略和回测必须独立建目录，不要挤进现有信号服务。

## 21. 后端数据库相关结构

```text
backend/.env.example
backend/app/database.py
backend/scripts/migrate_sqlite_to_postgres.py
backend/tests/conftest.py
backend/tests/test_database.py
backend/data/stock_mvp.sqlite3
```

### `backend/.env.example`

提供本地开发环境变量模板。当前包含 `DATABASE_URL`、推送通道配置和策略监控 scheduler 配置。

策略监控 scheduler 相关变量：

- `STRATEGY_MONITOR_SCHEDULER_ENABLED`
- `STRATEGY_MONITOR_SCHEDULER_INTERVAL_SECONDS`
- `STRATEGY_MONITOR_SCHEDULER_REFRESH`

### `backend/app/database.py`

后端数据库访问层。当前职责：

- 初始化数据表。
- 根据 `DATABASE_URL` 判断使用 PostgreSQL 或 SQLite。
- 持仓 CRUD。
- 行情快照读写。
- K 线读写。
- 修复历史持仓名称乱码。

后续建议把表结构初始化、持仓仓储、行情仓储、K 线仓储继续拆开，避免回测表加入后变成大文件。

### `backend/scripts/migrate_sqlite_to_postgres.py`

一次性迁移脚本，用于把 `backend/data/stock_mvp.sqlite3` 中的数据导入 PostgreSQL。

使用场景：

- 本地从 SQLite 升级到 PostgreSQL。
- 云服务器初始化前先在本机验证迁移结果。
- 后续如需重复迁移，先确认目标库是否已有业务数据，避免覆盖用户真实数据。

### `backend/tests/conftest.py`

后端数据库测试配置文件。当前负责：

- 指定测试库 `stock_web_test`。
- 初始化测试表结构。
- 每个测试前后清空测试表。

### `backend/tests/test_database.py`

后端数据库基础测试。当前覆盖：

- 持仓新增、查询、修改、删除。
- 行情快照写入和更新。
- K 线批量写入、更新和按时间查询。

### `backend/data/stock_mvp.sqlite3`

历史 SQLite 数据库文件，当前已经不是后续量化主库。该目录被 Git 忽略。
