# App 项目结构说明

最后更新：2026-05-13

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
- 收益计算属性。
- 展示格式化属性。

开发持仓、收益、列表、详情页时经常会用到。

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

### `lib/models/stock_search_result.dart`

后端股票搜索结果模型。

对应：

```text
GET /api/v1/stocks/search
```

### `lib/models/stock_suggestion.dart`

添加持仓弹窗中的本地/远程候选项模型。

## 6. Flutter 仓储目录

### `lib/repositories/position_repository.dart`

持仓仓储层。

职责：

- 协调后端持仓 API。
- 协调行情 API。
- 协调本地缓存。
- 后端失败时 fallback。
- 创建、编辑、删除持仓后同步本地缓存。

开发持仓数据流时优先改这里，不要直接在页面里组合多个 service。

## 7. Flutter 服务目录

### `lib/services/api_client.dart`

统一 HTTP 客户端。

职责：

- baseUrl。
- GET/POST/PUT/DELETE。
- JSON 编解码。
- 请求超时。
- API 异常。

所有后端请求都应经过它。

### `lib/services/position_api_service.dart`

持仓 API service。

职责：

- 获取持仓。
- 创建持仓。
- 更新持仓。
- 删除持仓。
- 后端 JSON 与 `StockPosition` 转换。

### `lib/services/quote_api_service.dart`

行情和 K 线 API service。

职责：

- 获取行情快照。
- 刷新行情快照。
- 获取 K 线缓存。
- 刷新 K 线。

注意：

- 当前 K 线刷新会优先读缓存，缓存为空才请求刷新接口。

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

如果要加排序、搜索、分组，优先从这里开始。

### `lib/screens/position_detail_screen.dart`

持仓详情页。

职责：

- 当前股票价格。
- 报价概览。
- K 线图。
- MA 指标。
- 横屏全图。
- 收益指标。
- 编辑/删除持仓。

当前仍较大，后续开发 K 线或图表相关功能时，应优先继续拆到 `widgets/chart/`。

### `lib/screens/signals_screen.dart`

信号页。

职责：

- 展示本地策略信号。
- 空状态。
- 刷新。

后续信号历史、已读未读、推送记录可从这里扩展，但复杂信号组件应放 `widgets/signal/`。

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

- `position_tile.dart`
- `compact_metric.dart`
- `position_detail_metric.dart`

### `lib/widgets/quote/`

行情展示组件：

- `quote_overview_grid.dart`

后续盘口、逐笔、买卖盘组件放这里。

### `lib/widgets/chart/`

图表组件：

- `kline_chart_period.dart`

后续 K 线交互、Painter、指标图层、横屏图表应放这里。

### `lib/widgets/signal/`

信号组件：

- `signal_tile.dart`

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
  main.py
  database.py
  mock_store.py
  schemas.py
  services/
    __init__.py
    futu_client.py
    futu_import.py
    stock_search.py
```

### `backend/app/main.py`

FastAPI 入口。

当前包含：

- 系统健康检查。
- 持仓 API。
- 行情 API。
- K 线 API。
- 信号 API。
- 股票搜索 API。
- 富途健康检查。
- 富途报价。
- 富途 K 线额度。
- 刷新行情。
- 刷新 K 线。

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

### `backend/app/database.py`

数据库和缓存操作。

后续数据库正式化时优先改这里或拆出 repositories。

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
mobile_app/lib/repositories/notification_repository.dart
mobile_app/lib/screens/notification_settings_screen.dart
```

后端：

```text
backend/app/services/push_service.py
backend/app/routers/notifications.py
```

## 15. 当前最需要关注的结构问题

- `position_detail_screen.dart` 仍大，应继续拆图表。
- `add_position_sheet.dart` 可继续拆 UI 子组件。
- `backend/app/main.py` 后续应拆 routers。
- `backend/app/schemas.py` 后续应按领域拆。
- 策略和回测必须独立建目录，不要挤进现有信号服务。
