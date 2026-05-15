# App 后续开发方案

最后更新：2026-05-13

本文档用于持续记录“下一步怎么做”。每次完成重要功能后，应更新本文件，让新接手者知道当前最优先的开发内容、依赖关系和验收标准。

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

当前验证通过：

```text
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
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
