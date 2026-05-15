# App 马上解决任务顺序

最后更新：2026-05-13

本文档用于交接“下一位开发者马上应该做什么”。它不是长期规划文档，而是当前版本之后最优先的执行清单。

当前 Git 基线：

```text
8b77fa4 优化K线数据刷新与图表交互
```

当前工作区要求：

- 开始前先确认 `git status --short` 为空。
- 先读 `docs/APP开发强约束规范.md`。
- 所有代码改动必须执行 format、analyze、test。
- 涉及后端改动必须执行 `python -m compileall app`。
- 涉及真机体验必须重新构建并安装 APK。

## 1. 当前真实状态

已经完成：

- 后端 K 线 GET 支持 `include_mock=false`。
- Flutter K 线刷新逻辑已改为先请求后端 refresh，失败才读真实缓存，最后才允许 mock fallback。
- 分时已改为 `1m`，后端富途映射使用 `K_1M`。
- 日 K 默认请求数量已从 240 调整为 360。
- K 线图支持双指缩放。
- 竖屏和横屏 K 线区域已调整为：

```text
选中 K 线详情
MA 指标
K 线图
```

- 局域网真机调试方式已验证：

```text
API_BASE_URL=http://192.168.1.4:8000
```

## 2. 第一优先级：同步文档中的旧描述

### 背景

状态：已处理。

此前 `docs/APP项目结构说明.md` 仍然写着：

```text
当前 K 线刷新会优先读缓存，缓存为空才请求刷新接口。
```

这已经不是当前代码逻辑。当前逻辑是：

```text
先请求后端 refresh
失败才读真实缓存
最后才允许 mock fallback
```

### 要改的文件

```text
docs/APP项目结构说明.md
docs/APP后续开发方案.md
```

### 具体任务

1. 更新 `lib/services/quote_api_service.dart` 的说明。
2. 在后续开发方案中补充“已完成 K 线刷新修复、1m 分时、双指缩放、日 K 360、横竖屏 K 线布局调整”。
3. 保留后续仍需拆分 K 线模块的任务。

### 验收标准

```powershell
rg -n "\x{FFFD}" docs mobile_app\docs
```

扫描无 Unicode replacement character。

### 当前结论

本文档创建后，旧描述已同步，并已完成 `position_detail_screen.dart` 的 K 线模块拆分、后端 API 错误结构统一、后端中文乱码修复保护。下一位开发者可以从“完善持仓持久化与数据库迁移”开始。

## 3. 已完成：拆分 `position_detail_screen.dart`

### 背景

此前 `mobile_app/lib/screens/position_detail_screen.dart` 过大，同时包含持仓详情布局、K 线预览交互、K 线 Painter、选中 K 线信息面板、MA 计算和横屏全图。

后续还要做成交量图、更多指标、策略量化入口，如果不拆，维护成本会快速上升。

### 已落地结构

```text
mobile_app/lib/screens/position_detail_screen.dart
mobile_app/lib/widgets/chart/position_kline_chart.dart
mobile_app/lib/widgets/chart/fullscreen_kline_screen.dart
mobile_app/lib/widgets/chart/kline_painter.dart
mobile_app/lib/widgets/chart/kline_info_panel.dart
mobile_app/lib/widgets/chart/kline_chart_values.dart
mobile_app/lib/widgets/chart/kline_chart_period.dart
```

当前职责：

- `position_detail_screen.dart`：持仓详情状态、周期切换、K 线加载、页面编排。
- `position_kline_chart.dart`：竖屏 K 线卡片、点选、缩放、拖动、加载/错误/空状态。
- `fullscreen_kline_screen.dart`：横屏全图、横屏锁定、顶部行情、横屏手势。
- `kline_painter.dart`：蜡烛图、MA、高低点标签、十字线、日期轴。
- `kline_info_panel.dart`：MA 条、选中 K 线详情面板。
- `kline_chart_values.dart`：MA 计算、K 线格式化、涨跌颜色。
- `kline_chart_period.dart`：周期参数。

### 已验证

```powershell
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

### 后续提醒

- 不要把 K 线绘制、指标计算、横屏布局重新堆回 `position_detail_screen.dart`。
- 后续新增成交量、MACD、RSI、BOLL 时，优先扩展 `widgets/chart/`。
- 竖屏和横屏仍各自维护一套可见区间/缩放状态，后续如继续增长，可以再抽一个 K 线 viewport controller。

## 4. 已完成：统一后端 API 错误结构

### 背景

此前 Flutter 对后端错误的感知偏粗，容易把 FutuOpenD 不可用、富途无数据、网络超时都展示成笼统的“后端连接失败”。

现在已经完成第一版结构化错误：

### 后端已落地

新增统一错误格式，FastAPI 仍使用标准 `detail` 字段，但内部结构固定：

```json
{
  "detail": {
    "code": "FUTU_UNAVAILABLE",
    "message": "FutuOpenD 不可用或富途接口调用失败",
    "detail": {
      "reason": "..."
    }
  }
}
```

已处理文件：

```text
backend/app/main.py
backend/app/errors.py
```

当前错误码：

- `POSITION_NOT_FOUND`
- `FUTU_DEPENDENCY_MISSING`
- `FUTU_UNAVAILABLE`
- `FUTU_NO_DATA`
- `NETWORK_TIMEOUT`
- `NETWORK_UNAVAILABLE`

### Flutter 已落地

已处理文件：

```text
mobile_app/lib/services/api_client.dart
mobile_app/lib/repositories/position_repository.dart
mobile_app/lib/screens/app_shell.dart
mobile_app/test/api_client_test.dart
```

已完成：

- `ApiException` 增加 `code/message/detail`。
- 支持解析后端结构化错误。
- 支持兼容旧版 `{"detail":"..."}` 错误。
- 网络超时归一为 `NETWORK_TIMEOUT`。
- 无法连接后端归一为 `NETWORK_UNAVAILABLE`。
- 持仓接口成功但 Futu 刷新失败时，不再误判成后端离线。

### 已验证

```powershell
cd C:\Users\58229\Desktop\stock_web\backend
python -m compileall app

cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

### 后续可继续优化

- 设置页增加独立的 Futu 状态行：正常、未启动、权限不足、无数据。
- K 线错误区根据 `ApiException.code` 展示更明确的按钮和提示。
- 后端可继续把富途权限不足、订阅不足拆成更细错误码。

## 5. 已完成：修复后端历史中文乱码数据

### 背景

后端历史持仓名称中仍可能存在中文乱码数据。此问题属于历史数据污染，不是 Flutter 字体或渲染问题。

### 当前结论

- 当前 SQLite 数据库 `backend/data/stock_mvp.sqlite3` 中持仓名称为正常中文。
- 已备份数据库到 `backend/data/stock_mvp.sqlite3.bak_20260513_encoding_fix`。
- 已在 `backend/app/database.py` 增加历史名称修复保护。
- 已在 `backend/app/main.py` 明确 JSON 响应头为 `application/json; charset=utf-8`。
- 已重启局域网后端服务，监听 `0.0.0.0:8000`。

### 已落地保护

- 已知股票代码名称映射：
  - `HK.00700`：腾讯控股。
  - `HK.02318`：中国平安。
  - `HK.02628`：中国人寿。
  - `HK.03988`：中国银行。
  - `US.AAPL`：Apple。
- 如果旧库中这些代码的名称为空、含问号、含 Unicode 替换字符，或出现典型拉丁扩展乱码，会在 `init_database()` 时自动修复。
- 正常中文名称不会被覆盖。

### 已验证

```powershell
cd C:\Users\58229\Desktop\stock_web\backend
.\.venv\Scripts\python.exe -m compileall app
```

Python 直接请求 `/api/v1/positions`，响应头为：

```text
application/json; charset=utf-8
```

响应内容中文正常。

## 6. 下一优先级：完善持仓持久化与数据库迁移

### 背景

现在后端已经有 SQLite，但数据库迁移、数据备份、字段演进仍比较简陋。

### 建议步骤

1. 明确当前 SQLite 作为 MVP 正式本地数据库。
2. 增加数据库版本表，例如 `schema_migrations`。
3. 将 `_ensure_column` 和初始化逻辑整理为可追踪迁移。
4. 补充备份和恢复说明。
5. 明确 App 本地缓存与后端数据库的主从关系。

## 7. 后续优先级：信号历史落库

### 背景

当前信号主要由 Flutter 本地生成，属于临时展示，不是真正历史记录。

下一步应先做 App 内信号历史，再考虑推送。

### 后端建议接口

```text
GET   /api/v1/signals/history
POST  /api/v1/signals/recalculate
PATCH /api/v1/signals/{id}/read
```

### Flutter 建议结构

```text
mobile_app/lib/models/signal_record.dart
mobile_app/lib/services/signal_api_service.dart
mobile_app/lib/repositories/signal_repository.dart
mobile_app/lib/screens/signal_history_screen.dart
mobile_app/lib/widgets/signal/
```

### 验收标准

- 信号生成后可保存。
- App 重启后历史不丢。
- 支持已读/未读。
- 后续可接推送。

## 8. 后续优先级：再进入量化和回测

不要马上直接做复杂量化。建议等以下基础完成：

- K 线组件拆分完成。
- 后端错误结构稳定。
- 信号历史落库。
- K 线缓存和刷新逻辑稳定。

然后再新增：

```text
backend/app/strategies/
backend/app/backtest/
backend/app/routers/strategies.py
backend/app/routers/backtests.py
mobile_app/lib/screens/strategy_lab_screen.dart
mobile_app/lib/screens/backtest_screen.dart
mobile_app/lib/screens/backtest_result_screen.dart
```

第一版策略仍按当前规划：

- 双均线策略。
- MACD 趋势策略。
- RSI 超买超卖策略。
- BOLL 突破/回归策略。
- 成交量放大 + 动量策略。

## 7. 每一步必须运行的验证

Flutter 代码改动：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

后端代码改动：

```powershell
cd C:\Users\58229\Desktop\stock_web\backend
python -m compileall app
```

真机体验改动：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://192.168.1.4:8000
D:\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk
D:\Android\Sdk\platform-tools\adb.exe reverse --remove-all
```

文档改动：

```powershell
rg -n "\x{FFFD}" docs mobile_app\docs
```

## 8. 推荐执行顺序一句话版

```text
完善持仓持久化与数据库迁移
  -> 做信号历史落库
  -> 再开始量化和回测
```

## 9. 2026-05-14 当前状态更新

### 已完成

- 本地 PostgreSQL 17 已安装到 `D:\PostgreSQL\17`。
- 已创建项目数据库 `stock_web` 和项目用户 `stock_web`。
- 后端已支持通过 `DATABASE_URL` 切换 PostgreSQL；未配置时仍可回退 SQLite。
- 已新增迁移脚本 `backend/scripts/migrate_sqlite_to_postgres.py`。
- 已将 SQLite 当前数据迁移到 PostgreSQL：
  - `positions`：6 条。
  - `quote_snapshots`：9 条。
  - `klines`：4368 条。
- 已重启后端，并验证 `/health` 与 `/api/v1/positions` 可用。

### 马上继续做

1. 为回测准备数据库表结构：策略定义、回测任务、净值曲线、交易记录、策略信号。
2. 回测模块先做最小闭环：双均线策略、单股票、日 K、固定手续费和滑点。

### 注意事项

- 以后本地开发后端默认使用 `backend/.env` 中的 `DATABASE_URL`。
- `backend/.env` 不提交 Git；提交的是 `backend/.env.example`。
- PostgreSQL 迁云时优先使用 `pg_dump` / `pg_restore` 或云厂商 DMS 工具，不要手动复制数据目录。

### 2026-05-14 数据库测试补充

- 已创建独立测试库 `stock_web_test`。
- 已新增后端数据库测试：
  - 持仓 CRUD。
  - 行情快照 upsert 和查询。
  - K 线 upsert 和按时间查询。
- 已验证测试库运行后会清空，真实库 `stock_web` 未被污染。
- 后续每次修改数据库层必须运行 `python -m pytest`。

### 2026-05-14 后端 routers 拆分补充

- 已将 `backend/app/main.py` 中的接口按业务领域拆到 `backend/app/routers/`。
- `main.py` 当前只负责 FastAPI 初始化、数据库启动初始化和 router 注册。
- 已验证核心接口路径保持不变：
  - `/health`
  - `/api/v1/positions`
  - `/api/v1/quotes`
  - `/api/v1/klines/{stock_code}`
  - `/api/v1/signals`
- 下一步建议拆 `backend/app/schemas.py`，避免策略和回测模型继续挤进单个大文件。

### 2026-05-14 后端 schemas 拆分补充

- 已将 `backend/app/schemas.py` 拆为 `backend/app/schemas/` 包。
- 已按持仓、行情、K 线、信号、股票搜索拆分数据模型。
- `backend/app/schemas/__init__.py` 保留统一导出，现有导入方式不需要改。
- 下一步可以开始设计策略和回测数据库表结构。

## 10. 当前马上要做的策略回测后端任务

当前基础状态：

- PostgreSQL 已迁移。
- 数据库测试已补。
- 后端 routers 已拆。
- 后端 schemas 已拆。
- 文档已同步。
- Git 已保存。

策略和回测后端骨架已开始落地，当前先做后端地基，不做复杂算法，也先不做 App 页面。

### 第一阶段目标

完成策略和回测的数据库地基：

```text
策略/回测数据库表结构
  -> Pydantic schemas
  -> 数据库读写函数
  -> 数据库测试
```

当前已完成：

```text
strategy_definitions 表
strategy_parameters 表
backtest_runs 表
backtest_equity_curve 表
backtest_trades 表
strategy_signals 表
schemas/strategies.py
schemas/backtests.py
routers/strategies.py
routers/backtests.py
test_strategy_backtest_database.py
```

当前已验证：

```text
pytest: 6 passed
GET /api/v1/strategies: ok
正式库 strategy_definitions: 1
正式库 backtest_runs: 0
测试库策略/回测表: 0
```

### 建议新增文件

```text
backend/app/schemas/strategies.py
backend/app/schemas/backtests.py
backend/app/routers/strategies.py
backend/app/routers/backtests.py
backend/tests/test_strategy_backtest_database.py
```

后续如果 `backend/app/database.py` 继续变大，应再拆：

```text
backend/app/repositories/positions.py
backend/app/repositories/quotes.py
backend/app/repositories/klines.py
backend/app/repositories/strategies.py
backend/app/repositories/backtests.py
```

### 第一批数据库表状态

已设计并落库：

```text
strategy_definitions
strategy_parameters
backtest_runs
backtest_equity_curve
backtest_trades
strategy_signals
```

当前已经具备最小写入和读取能力：

```text
strategy_definitions
backtest_runs
backtest_equity_curve
backtest_trades
```

### 第一版接口

先做最小闭环需要的接口：

```text
GET  /api/v1/strategies
POST /api/v1/backtests
GET  /api/v1/backtests/{run_id}
```

`POST /api/v1/backtests` 必须由前端提交回测配置，后端不得随意固定回测时间。

请求参数应至少包含：

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

其中 `start_date` 和 `end_date` 由 App 用户选择。

### 第一版策略

当前默认策略已写入 `strategy_definitions`：

```text
双均线策略
code = ma_cross
```

第一版目标闭环：

```text
App 配置股票和参数
  -> App 选择开始日期和结束日期
  -> 后端创建回测任务
  -> 后端读取 K 线
  -> 后端跑双均线
  -> 保存回测结果
  -> App 展示收益曲线和交易记录
```

### 验收要求

- 新增数据库表必须有测试库测试。
- 测试必须使用 `stock_web_test`，不得污染 `stock_web`。
- 回测时间区间必须来自前端配置，后端只按参数执行。
- 第一阶段可以先用接口调试，不做 App 页面；最终 App 必须提供回测配置和结果展示。
- 每次后端改动后运行：

```powershell
cd C:\Users\58229\Desktop\stock_web\backend
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
```

### 下一步

最小双均线回测引擎已实现：

```text
读取用户提交的 backtest 参数
  -> 按 stock_code / period / start_date / end_date 查询 K 线
  -> 计算短均线和长均线
  -> 产生买卖交易
  -> 计算净值曲线、收益率、最大回撤
  -> 写入 backtest_equity_curve 和 backtest_trades
  -> 更新 backtest_runs.status 和 summary
```

当前验收结果：

```text
pytest: 7 passed
POST /api/v1/backtests: completed
正式库 backtest_runs: 1
正式库 backtest_equity_curve: 315
正式库 backtest_trades: 7
测试库回测表: 0
```

下一步建议：

```text
新增 App 量化入口
  -> 策略列表
  -> 股票和日期区间选择
  -> 参数设置
  -> 启动回测
  -> 展示收益曲线、最大回撤、交易记录
```

### 2026-05-15 App 量化入口补充

已开始新增 App 端量化入口，当前实现范围：

```text
底部导航新增“量化”
  -> 读取策略列表
  -> 配置股票、日期区间、初始资金、手续费、滑点、均线参数
  -> 调用 POST /api/v1/backtests
  -> 展示总收益、最大回撤、期末权益、交易次数、交易记录
```

新增移动端文件：

```text
mobile_app/lib/models/strategy_definition.dart
mobile_app/lib/models/backtest_models.dart
mobile_app/lib/services/backtest_api_service.dart
mobile_app/lib/repositories/backtest_repository.dart
mobile_app/lib/screens/quant_screen.dart
```

已修改：

```text
mobile_app/lib/screens/app_shell.dart
```

当前量化页面只负责配置和展示结果，不在 Flutter 端计算回测。

### 2026-05-15 回测净值曲线补充

量化结果页已新增收益曲线：

```text
结果指标
  -> 收益曲线
  -> 交易记录
```

新增文件：

```text
mobile_app/lib/widgets/backtest/backtest_equity_chart.dart
```

该组件使用后端返回的 `equity_curve` 绘制净值曲线，不在 Flutter 端重新计算回测。

### 2026-05-15 回测 K 线买卖点图补充

量化结果页已新增第一版 K 线买卖点图：

```text
收益曲线
  -> K 线买卖点
  -> 交易记录
```

新增文件：

```text
mobile_app/lib/widgets/backtest/backtest_kline_trade_chart.dart
```

当前实现为回测专用 K 线图：

- 使用回测股票的日 K 数据绘制蜡烛图。
- 叠加 MA5 和 MA20。
- 使用回测交易记录标记 B / S。
- 支持双指缩放、单指横向拖动和点击查看日期/开高低收/涨跌幅/当日信号。
- 不复用持仓详情 K 线模块，避免影响现有 K 线缩放和横屏逻辑。
- 当前不支持横屏、成交量和点击交易明细弹层，后续可升级。

已修复一个关键数据源问题：

- 量化页不能直接复用详情页的 K 线 refresh 流程。
- refresh 接口在部分股票上可能返回旧区间 K 线，导致回测日期过滤后图表为空。
- 量化页现在通过 `AppShell._loadBacktestCandles()` 优先读取后端真实缓存，缓存为空才刷新。

### 2026-05-15 量化页股票搜索补充

量化页参数区已经支持股票代码自动识别和搜索：

- 输入完整代码后，在股票代码输入框下方显示股票名称。
- 输入部分代码或名称时，展示候选列表。
- 点击候选后自动填入股票代码。
- 当前复用新增持仓使用的本地候选库和后端股票搜索接口。
- 固定持仓快捷标签已移除，避免参数区重复和拥挤。

均线参数当前不是固定 5/20：

- 5 和 20 只是默认值。
- 用户可在“短均线”和“长均线”输入框中配置其他正整数。
- 后端要求短均线小于长均线。

后续如果增加多市场策略或股票池配置，优先把搜索组件抽成通用 widget，避免量化页、添加持仓页各自维护重复 UI。

### 2026-05-15 后端数据库层拆分补充

已完成：

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

当前状态：

- `database.py` 已变成兼容门面，只保留旧函数名导出。
- 具体 SQL 和业务读写已经迁入 repositories。
- 建表、连接、seed、转换已经迁入 db。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 7 passed
```

马上下一步：

1. 把后端 routers 从 `app.database` 兼容门面迁移到对应 repository。
2. 把 `backend/app/backtest/engine.py` 从 `app.database` 迁移到 `repositories.market_data` 和 `repositories.backtests`。
3. 每迁移一批都运行后端 compileall 和 pytest。
4. 迁移完成后再继续做策略扩展、参数校验和历史回测列表。

### 2026-05-15 后端 repository 直接引用补充

已完成：

- `backend/app/main.py` 直接引用 `db.init.init_database`。
- `backend/app/mock_store.py` 直接引用 `repositories.market_data` 和 `repositories.positions`。
- `backend/app/routers/positions.py` 直接引用 `repositories.positions`。
- `backend/app/routers/quotes.py` 直接引用 `repositories.market_data` 和 `repositories.positions`。
- `backend/app/routers/klines.py` 直接引用 `repositories.market_data` 和 `repositories.positions`。
- `backend/app/routers/strategies.py` 直接引用 `repositories.strategies`。
- `backend/app/routers/backtests.py` 直接引用 `repositories.backtests`。
- `backend/app/backtest/engine.py` 直接引用 `repositories.market_data` 和 `repositories.backtests`。

当前状态：

- `backend/app` 业务代码已不再直接依赖 `app.database` 兼容门面。
- `app.database` 暂时保留给旧测试和外部兼容。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 7 passed
```

下一步建议：

1. 增加量化参数校验和更清晰的错误提示。
2. 增加历史回测列表接口和 App 展示。
3. 再开始扩展 MACD、RSI、BOLL 等策略。

### 2026-05-15 量化参数校验和错误提示补充

已完成：

- App 提交回测前校验股票代码不能为空且格式应类似 `HK.02628`。
- App 校验开始日期不能晚于结束日期。
- App 校验初始资金必须是大于 0 的数字。
- App 校验手续费率和滑点率必须是非负数字。
- App 校验短均线和长均线必须是正整数。
- App 校验短均线必须小于长均线。
- 后端 `BacktestCreate` 校验开始日期不能晚于结束日期。
- 后端回测失败结果新增 `summary.error_message`。
- App 收到 `failed` 回测结果时展示错误原因，不再把失败结果当作正常回测结果展示。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 8 passed
```

下一步建议：

1. 做历史回测列表接口和 App 展示。
2. 或先补量化页日期/数字输入的更强交互限制，减少用户输入非法字符。

### 2026-05-15 历史回测列表补充

已完成：

- 后端新增 `GET /api/v1/backtests`。
- 后端 repository 新增 `list_backtest_runs`。
- 后端 repository 新增 `delete_backtest_run`，按单条 `run_id` 删除回测主记录、净值曲线和交易记录。
- 后端 repository 新增 `delete_all_backtest_runs`，用于一键删除全部历史回测。
- 后端回测运行新增 `name` 字段，支持编辑历史回测名称。
- 支持 `stock_code`、`strategy_code`、`status`、`limit` 过滤。
- App service/repository 新增历史回测列表、单条详情读取、单条删除、一键删除全部和历史名称编辑。
- 量化页新增“历史回测”面板。
- 点击历史回测后加载完整回测结果，并展示收益曲线、买卖点 K 线和交易记录。
- 历史回测列表从展示最近 5 条调整为最多 30 条。
- 历史回测面板支持股票代码、策略和状态筛选。
- 每条历史回测右侧提供删除按钮，删除前必须二次确认；删除当前正在查看的回测时，需要同步清空当前结果区。
- 历史回测标题右侧提供一键删除全部按钮，删除前必须二次确认；删除全部后需要清空历史列表和当前结果区。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 9 passed
```

下一步建议：

1. 真机安装验证历史回测面板、点击加载详情、名称编辑、筛选、单条删除和一键删除全部。
2. 验证通过后再 git 保存。
3. 之后可以开始做更多策略，优先 MACD 或 RSI。
