# App 马上解决任务顺序

最后更新：2026-05-20

本文档用于交接“下一位开发者马上应该做什么”。它不是长期规划文档，而是当前版本之后最优先的执行清单。

当前 Git 基线：

```text
b4a17f7 chore: detect LAN API address for debug APK
```

当前工作区要求：

- 开始前先确认 `git status --short` 为空。
- 先读 `docs/APP开发强约束规范.md`。
- 所有代码改动必须执行 format、analyze、test。
- 涉及后端改动必须执行 `python -m compileall app`。
- 涉及真机体验必须重新构建并安装 APK。
- 当前真机调试采用局域网后端地址。重新打 debug APK 时禁止裸跑 `flutter build apk --debug`，必须直接运行 `.\scripts\build_mobile_lan_debug.ps1` 自动探测当前电脑局域网 IP，或手动传 `--dart-define=API_BASE_URL=http://电脑当前局域网IP:8000`。

## 0. 2026-05-20 当前马上任务

当前已经完成一次完整架构审计，结果记录在：

```text
docs/APP架构审计与优化路线.md
```

后续马上按该文档分阶段优化。当前第一步：

```text
信号模型和 UI 解耦
```

第一轮只做低风险结构优化：

- 新增信号分类 UI helper。
- 从 `mobile_app/lib/models/trade_signal.dart` 移出分类标题、图标、颜色等 UI 展示逻辑。
- 保持当前信号页视觉和行为不变。
- 完成后运行 Flutter format、analyze、test。

后续阶段依次处理：

- Futu `SH.`、`SZ.` 市场和币种映射。
- `signal_scanner.py` 扫描配置化。
- `app_shell.dart` 状态控制器拆分。
- `quant_screen.dart` 参数校验和历史/搜索控制器拆分。
- docs 中旧 IP、旧文件名和历史“下一步”描述清理。

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

- 局域网真机调试方式已验证，注意电脑换 Wi-Fi、热点或路由器后 IP 会变化，必须重新构建安装 APK：

```text
API_BASE_URL=http://电脑当前局域网IP:8000
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
..\scripts\build_mobile_lan_debug.ps1
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

### 2026-05-16 历史回测复盘体验完成

已完成：

- 点击历史回测后自动滚动到结果区。
- 结果区新增“当前查看历史回测 / 刚刚完成的回测”上下文提示。
- 结果区展示回测名称、策略、股票和日期区间。
- 失败历史回测会显示参数快照和失败原因。
- K 线数据不足时，买卖点图区域显示明确提示。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
debug APK install: Success
```

下一步马上做：

```text
整理 App 动态参数结构
  -> 统一策略参数定义
  -> 统一默认值回填
  -> 统一参数输入渲染
  -> 统一请求参数构建和校验
  -> 再进入 BOLL / 成交量动量等未完成策略
```

### 2026-05-16 MACD 后端第一阶段完成

已完成：

- 后端新增 MACD 指标计算。
- 后端新增 `macd_trend` 策略。
- 策略 registry 已支持 `macd_trend`。
- 种子策略新增 MACD Trend。
- 后端测试覆盖 MACD 正常回测和参数错误。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 19 passed
```

下一步马上做：

```text
App 接入 macd_trend 动态参数
  -> 参数区显示快线周期 / 慢线周期 / 信号周期
  -> 提交回测传 fast_window / slow_window / signal_window
  -> 结果区参数快照显示 MACD 参数
  -> Flutter format / analyze / test
```

### 2026-05-16 App 接入 MACD 参数完成

已完成：

- App 参数区已支持 `macd_trend`。
- MACD 参数：快线周期、慢线周期、信号周期。
- App 提交前校验快线周期必须小于慢线周期。
- 回测请求会传 `fast_window`、`slow_window`、`signal_window`。
- 结果区参数快照会显示 MACD 参数。
- 失败提示已兼容 `invalid_macd_parameters`。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 19 passed
```

下一步马上做：

```text
真机验证 MACD Trend 回测
  -> 重新构建并安装 debug APK
  -> 后端确保 seed 中已有 macd_trend
  -> App 量化页刷新策略列表
  -> 选择 MACD Trend 发起回测
```

### 2026-05-16 持仓 K 线 VOL 副图完成

已完成：

- 持仓详情 K 线新增 VOL 成交量副图。
- VOL 直接使用 K 线接口返回的 `volume` 字段。
- 副图绘制成交量柱和 VOL MA5/MA10/MA20。
- 颜色口径：绿色表示流入/上涨量，红色表示流出/下跌量。
- 竖屏和横屏共用同一 painter，横屏也会显示 VOL。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

下一步马上做：

```text
重新构建并安装 APK
  -> 真机检查持仓详情日 K / 周 K / 月 K 的 VOL 显示
  -> 真机检查横屏 K 线 VOL 显示
  -> 如布局拥挤再调整价格区和 VOL 区比例
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
3. 之后开始做第二个策略，优先 RSI。当前 RSI、MACD Trend 和策略分发均已完成，该条为历史记录。

## 13. 已完成：RSI 策略和多策略分发

当前量化模块已经具备：

- 启动双均线回测。
- 展示收益曲线、买卖点 K 线和交易记录。
- 管理历史回测。
- 编辑历史回测名称。
- 按股票代码、策略和状态筛选历史回测。
- 支持 `ma_cross`、`rsi_reversal`、`macd_trend` 三个策略。
- 通过 `strategies/registry.py` 完成多策略分发。

本节原本是 RSI 和多策略分发的开发计划，当前已经完成，后续不要重复开发同一套分发结构。

### 后端第一步，已完成

新增 RSI 策略：

```text
strategy_code: rsi_reversal
parameters:
  rsi_window: 14
  oversold: 30
  overbought: 70
```

交易规则第一版建议：

- RSI 低于超卖线后回升，产生买入信号。
- RSI 高于超买线后回落，产生卖出信号。
- 手续费、滑点、仓位管理继续沿用现有回测引擎。

### 后端第二步，已完成

拆出多策略分发：

```text
backend/app/strategies/base.py
backend/app/strategies/factors.py
backend/app/strategies/registry.py
backend/app/strategies/ma_cross.py
backend/app/strategies/rsi_reversal.py
```

职责边界：

- `factors.py`：计算 RSI、MA 等指标。
- `ma_cross.py`：只负责双均线信号。
- `rsi_reversal.py`：只负责 RSI 信号。
- `registry.py`：根据 `strategy_code` 找到策略实现。
- `backtest/engine.py`：只负责回测执行、交易撮合、手续费、滑点、净值曲线、交易记录和结果保存。

### App 第三步，已完成

后端 RSI 接口跑通后，App 参数区已完成动态化：

- 选 MA Cross 时显示短均线和长均线。
- 选 RSI 时显示 RSI 周期、超卖线、超买线。
- 参数区必须按策略动态显示，不能把所有策略参数固定堆在一个表单里。

### App 第四步，已完成

历史记录策略显示优化：

- 历史记录优先显示策略名称，例如 `MA Cross`、`RSI 反转`。
- 策略 code 作为辅助信息，不作为主要展示文本。

### 验收标准，已完成

- `POST /api/v1/backtests` 使用 `strategy_code=rsi_reversal` 能返回 completed 或明确 failed 原因。
- RSI 回测结果能写入 `backtest_runs`、`backtest_equity_curve`、`backtest_trades`。
- 原有 MA Cross 回测不回归。
- 后端 `pytest` 必须新增 RSI 策略测试。
- App 动态参数 UI 上线前，至少后端接口测试先通过。

### 2026-05-16 当前完成状态

已完成后端 RSI 第一阶段：

- 新增 `backend/app/strategies/` 包。
- 新增 `base.py`、`factors.py`、`registry.py`、`ma_cross.py`、`rsi_reversal.py`。
- `engine.py` 已从直接写死 MA 策略改为通过 registry 获取策略并执行信号。
- `rsi_reversal` 已接入策略种子数据。
- 后端测试新增 RSI 正常回测、RSI 参数错误、种子策略包含 RSI。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 15 passed
```

### 2026-05-16 手机本地通知第一阶段完成

已完成：

- 当前修改前已先提交 git：`09a0d2f Add MACD strategy and volume chart`。
- App 新增 `flutter_local_notifications`。
- AndroidManifest 新增 `POST_NOTIFICATIONS` 权限。
- Android Gradle 已开启 core library desugaring，并增加 `desugar_jdk_libs`，满足通知插件构建要求。
- 新增 `mobile_app/lib/services/notification_service.dart`，负责初始化通知、请求权限、展示持仓信号通知。
- `TradeSignal` 新增 `notificationKey`，用于同一轮运行期间去重。
- `AppShell` 在持仓刷新、新增、编辑和信号阈值变化后重新计算信号，并对新信号弹本地通知。
- App 启动首次加载持仓不弹通知，避免历史信号刷屏。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
gradlew :app:assembleDebug
```

历史备注：

- 本节只记录 2026-05-16 本地通知第一阶段。
- “重要信号在 App 不打开时也能到手机”的真实推送方案，已统一移动到文末 `2026-05-17 当前马上任务`。

### 2026-05-16 胜率指标补充

已完成：

- 后端回测 summary 新增胜率相关字段：
  - `round_trip_count`
  - `win_count`
  - `loss_count`
  - `win_rate`
- 胜率只统计完整买入/卖出回合，未平仓买入不算输赢。
- App 结果区新增“胜率”和“买卖回合”。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 17 passed
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

## 14. 已完成：历史详情和参数快照

本节原本是历史详情和参数快照的开发计划，当前基础能力已经完成，后续只保留少量体验优化。

### 为什么可以做历史详情

历史详情对数据库压力不大。

一次历史详情主要读取：

- `backtest_runs`：回测参数、状态、summary。
- `backtest_equity_curve`：净值曲线。
- `backtest_trades`：交易记录。
- `klines`：按股票、周期、日期范围读取已有 K 线。

不要为每次回测复制一份 K 线。K 线必须继续复用 `klines` 表。

### 当前数据量判断

如果一次日 K 回测 5 年，大约 1200 个交易日：

- `backtest_runs`：1 行。
- `backtest_equity_curve`：约 1200 行。
- `backtest_trades`：通常几十行。

即使以后有 1000 次回测，也大约是 120 万行净值曲线。这个量级对 PostgreSQL 是轻量的。

### 当前实现必须保持

- 历史列表只读摘要，不要加载完整曲线。
- 点击某条历史记录后才加载完整结果。
- App 打开历史详情时再读取对应 K 线，不要重复存 K 线。
- 历史记录继续限制数量或分页，当前 30 条只是第一版。

### 当前实现状态和下一步顺序

历史回测详情基础链路已经完成，不需要从零开发。

已完成：

- 历史列表只读取 `BacktestRun` 摘要。
- 点击某条历史记录后调用 `GET /api/v1/backtests/{run_id}` 加载完整 `BacktestResult`。
- 完整结果包含 `run`、`equity_curve` 和 `trades`。
- App 会按历史回测的股票、周期和日期区间重新读取 K 线，并复用量化页买卖点 K 线图。
- 结果区已经能展示参数快照、收益指标、收益曲线、买卖点 K 线和交易记录。

历史复盘体验当前状态：

1. 点击历史记录后已经能定位到结果区。
2. 结果区已经能展示“当前查看历史回测 / 刚刚完成的回测”上下文。
3. 结果区已经能展示历史名称、策略、股票和日期区间。
4. 旧历史、失败历史或 K 线为空时已经有清晰提示。
5. 历史列表胜率摘要仍可作为后续小优化；胜率字段已由后端 summary 提供，App 结果区已经展示。

### 2026-05-16 参数快照完成状态

已完成：

- App 结果区新增“参数”小节。
- 参数快照展示策略、股票、日期区间、初始资金、手续费率、滑点率。
- `ma_cross` 展示短均线、长均线。
- `rsi_reversal` 展示 RSI 周期、超卖线、超买线。
- 历史回测详情复用同一结果区，因此点开历史记录后也能看到当时参数。
- 参数快照已改为紧凑三栏布局，日期区间单独占满一行，避免手机端文本溢出。
- 历史回测列表已压缩为紧凑展示：名称一行、省略超长文本，下方展示股票、策略和日期，右侧保留收益、编辑和删除操作。

当前已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
UTF-8 replacement scan: replacement_char_files=0
debug APK 已安装到真机验证
```

### 2026-05-16 App 动态参数进展

已完成：

- App 参数区已按策略动态显示。
- `MA Cross` 显示短均线、长均线。
- `RSI Reversal` 显示 RSI 周期、超卖线、超买线。
- App 提交 RSI 回测时会传 `rsi_window`、`oversold`、`overbought`。
- App 提交前会校验 RSI 周期必须大于 1，超卖线必须小于超买线。
- 历史回测记录已优先展示策略可读名。

已验证：

```text
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 15 passed
```

## 15. 2026-05-17 当前马上任务

本节是当前交接入口。上面 2026-05-16 的内容均视为历史完成记录或背景说明，不再作为当前未完成任务执行。

### 量化回测数据刷新和交易记录滚动状态

已完成：

- 后端回测读取 K 线时，如果本地缓存不足，会先尝试通过富途刷新指定回测区间，再重新读取缓存。
- 后端回测失败摘要已补充缓存 K 线数量、要求数量和刷新错误，便于判断是真缺数据还是刷新失败。
- App 启动回测前会按用户选择的股票、周期、开始日期和结束日期主动刷新 K 线，避免新加入股票首次回测因为缓存为空失败。
- 量化结果交易记录已改为固定高度滚动卡片，默认约显示 8 行高度，但可在卡片内滚动查看全部交易记录。
- 交易记录展示规则已同步到 `APP开发强约束规范.md`、`APP项目结构说明.md` 和 `APP后续开发方案.md`。

已验证：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
D:\flutter\bin\flutter.bat build apk --debug
debug APK 已安装到真机验证
```

### 信息推送下一步方案

当前用户目标是：有重要信号时，App 能立刻把信号发到手机。现有本地通知已经能在 App 运行或刷新后提醒，但还不能覆盖 App 未打开、后台长期运行、系统清理后的场景。

当前已完成：

- 后端已新增 `signal_events` 信号事件表。
- 后端已新增 `notification_devices` 设备 token 表。
- 后端已新增 `push_records` 推送记录表。
- 已新增通知相关 schema、repository 和数据库 facade 导出。
- 后端测试已覆盖信号事件创建/读取/已读、设备 token upsert、推送记录写入/查询。
- 后端已新增 `/api/v1/notifications/devices` 设备注册接口。
- 后端已新增 `/api/v1/notifications/test` 测试通知记录接口。
- App 设置页已接入“消息提醒设置”，可自动注册当前设备、切换提醒开关、触发本地测试通知，并在后端写入测试推送记录。
- 后端已新增 `backend/app/services/push_service.py`，统一编排设备开关、推送通道、推送记录写入和发送结果状态。
- 后端已新增 `backend/app/services/push_providers/fcm.py`，FCM provider 支持通过 `FCM_SERVICE_ACCOUNT_PATH` 或 `FCM_SERVICE_ACCOUNT_JSON` 初始化 Firebase Admin SDK。
- 后端已新增 `backend/app/services/push_providers/huawei.py`，Huawei Push Kit provider 支持通过 `HUAWEI_PUSH_APP_ID`、`HUAWEI_PUSH_CLIENT_ID`、`HUAWEI_PUSH_CLIENT_SECRET` 获取 OAuth token 后调用 Push Kit 服务端发送接口。
- `/api/v1/notifications/test` 已改为通过 `push_service` 调度；未配置真实通道时安全写入 `skipped`，FCM/Huawei provider 可用时写入 `sent` 和服务端响应摘要。
- `backend/requirements.txt` 已新增 `firebase-admin`，`backend/.env.example` 已补充 FCM 与 Huawei Push Kit 配置占位。
- App 端 token 注册顺序为 Huawei Push Kit -> FCM -> 本机安装 token。华为设备优先登记 `push_provider=huawei`，Google 设备登记 `push_provider=fcm`，都不可用时登记 `unknown` 并保留本地通知兜底。
- Debug APK 已安装到真机，`adb reverse tcp:8000 tcp:8000` 已设置，后端 `/health` 返回正常。

交接给下一位开发者的先做验证：

1. 打开手机 App，进入 `设置 -> 手机推送 / 消息提醒设置`。
2. 确认页面显示当前设备为“已注册”。
3. 点击“测试”，确认手机能弹出本地测试通知。
4. 如果页面注册失败，先检查后端是否运行、`adb reverse tcp:8000 tcp:8000` 是否存在。
5. 验证通过后，再补真实厂商控制台配置：华为设备配置 AppGallery Connect 和 Huawei 后端密钥，Google 设备配置 Firebase 服务账号。

后续执行顺序：

1. 第一版真实推送优先跑通 Huawei Push Kit 和 FCM 两条闭环。
2. 后端增加定时扫描任务，先覆盖持仓止盈、止损、异动阈值和策略买卖信号。
3. 真机验证前台、后台、锁屏、App 被清理后的通知到达情况。
4. 如果后续还有小米、OPPO、vivo 设备，再按现有 provider 插槽补对应厂商实现。

第一版验收标准：

- App 可以注册或刷新设备 token。
- 后端能保存设备 token 和通知开关。
- 后端能生成信号事件并落库。
- 后端能通过推送通道发送测试通知和真实重要信号。
- App 收到通知后点击可进入信号页或信号详情。
- 同一股票同一信号在设定时间窗口内不会重复刷屏。
- 推送失败会写入推送记录，不影响信号历史展示。

### 当前下一步建议

1. 先完成局域网真机页面验证，确认设置页“后端 API”为电脑当前局域网地址，例如 `http://当前IP:8000`。
2. 暂时拿不到 Huawei Push Kit 配置时，不阻塞信号中心建设；先把信号解释、筛选、落库和去重做好。
3. 然后接外部通知通道，例如 Email、Telegram、短信或 WhatsApp，作为无厂商 Push 配置时的可达提醒方案。
4. 厂商配置具备后，再补 Huawei Push Kit / FCM 的系统级远程推送。
5. 同时保留一个短验证任务：真机复测 3 到 5 只不同港股的新股票回测，确认“App 预刷新 + 后端兜底刷新”对新股稳定。

### 信号中心马上任务

当前用户反馈：信号页已有很多策略信号，但不知道对应什么策略、为什么触发、哪些需要关注、哪些不需要关注。

当前结论：

- 现有信号页仍偏“提示列表”，不是完整信号中心。
- 现有 `TradeSignal` 缺少策略来源、触发条件、当前值、阈值、是否推送、是否已读/忽略等字段。
- 量化页已有 MA、RSI、MACD 回测策略，但还没有统一转成后端实时扫描信号。

下一步执行顺序：

1. 扩展信号模型：
   - `source_category`：`risk`、`strategy`、`system`。
   - `strategy_code`。
   - `strategy_name`。
   - `condition_label`。
   - `trigger_value`。
   - `threshold_value`。
   - `dedupe_key`。
   - `push_candidate`。
   - `read_status`。

2. 改造信号页展示：
   - 增加筛选：全部、持仓风控、量化策略、重要、已忽略。
   - 每条信号显示策略来源和触发条件。
   - 弱信号只展示，不进入推送候选。

3. 后端新增策略信号扫描：
   - 第一批复用 MA Cross、RSI Reversal、MACD Trend。
   - 扫描结果写入 `signal_events`。
   - 同一股票同一策略同一方向按 dedupe key 去重。

4. 建立信号推送规则：
   - 止损观察、止盈观察默认推送候选。
   - MA 金叉/死叉、MACD 翻多/翻空、RSI 超卖回升/高位回落默认推送候选。
   - 普通日涨跌、数据不足、回测历史记录不默认推送。
   - 多策略同向共振可以提升为重要级别。

5. 再进入外部通知通道：
   - Email。
   - Telegram Bot。
   - 短信。
   - WhatsApp Business。

验收标准：

- 用户能从信号页看懂“哪个股票、哪个策略、什么条件触发、当前值和阈值是多少”。
- 用户能筛掉不关心的信号。
- 后端能生成策略信号并落库。
- 信号重复触发不会刷屏。
- 推送候选和普通展示信号有明确区别。

### 信号中心扫描落地顺序

下一步优先做手动扫描，不直接上定时任务。

执行顺序：

1. 后端新增 `POST /api/v1/signals/scan`。
2. 扫描股票池先使用当前持仓和关注列表。
3. 扫描策略先接 `price_break_ma`、`ma_cross`、`rsi_reversal`、`macd_trend`。
4. 扫描前检查或刷新 K 线，确保最新日期覆盖目标交易日。
5. 扫描结果写入 `signal_events`，并按股票、策略、方向、交易日生成 dedupe key。
6. App 信号页改为读取后端信号事件，并显示策略来源、触发条件、当前值、阈值和触发日期。
7. 手动扫描稳定后，再加后台定时扫描和推送候选分发。

验收标准：

- 点击一次扫描后，信号页能出现可解释的策略信号。
- `price_break_ma` 信号能解释“收盘价跌破/站回 MA”。
- 旧的本地模糊信号不再作为主要信号来源。
- 推送仍然只消费已落库信号。

当前实现状态：

- 已新增后端手动扫描接口 `POST /api/v1/signals/scan`。
- 已新增后端信号事件列表接口 `GET /api/v1/signals/events`。
- 已新增 `backend/app/services/signal_scanner.py`，扫描当前持仓并复用现有策略模块。
- 已实现按 dedupe key 去重，重复扫描不会重复写同一交易日同一策略信号。
- App 信号页已增加“扫描信号”按钮，并展示后端落库的可解释信号。
- 后端没有信号事件时，App 仍用本地止盈/止损/异动信号兜底。
- App 已支持按分类进入信号页，并在分类详情页按股票、策略、信号类型筛选。
- App 已新增信号设置入口，可切换扫描配置的启用状态和推送候选状态。
- 后端信号事件接口已支持 `signal_type` 筛选。
- 后端扫描器已遵守扫描配置的 `push_candidate`，关闭推送候选后仍落库展示。
- 后端已新增 `strategy_monitors` 表、仓储、接口和手动扫描服务，可把某只股票/持仓绑定到某个策略并生成 `signal_events`。
- 后端已新增策略监控 scheduler，可按环境变量随后端启动自动轮询，也可通过 API 启动、停止和查看状态。
- 后端已把策略监控的推送候选接入 `push_service`，按设备开关、重要通知开关和通道配置写入 `push_records`，并避免同一信号同一设备重复发送。

下一步继续：

1. 增加已读/忽略 UI 操作。
2. 前端接策略监控选择入口、scheduler 状态和券商式持仓页面。
3. 前端补充推送记录查看入口，便于确认某条信号是否已发送、跳过或失败。
4. 后续如果信号筛选和设置继续扩展，应从 `signals_screen.dart` 拆出独立 screen/widget。

### 盘中策略监控后续任务

当前结论：

- 现有量化页主要用于历史回测。
- 现有信号扫描主要是手动扫描，默认基于日 K 最新数据生成收盘确认类信号。
- 当前还不是“盘中每 15 分钟自动判断买入/卖出观察”的实时量化监控。

目标流程：

```text
量化页选择股票
-> 运行单策略或多因子回测
-> 找到该股票较合适的策略参数
-> 保存为该股票的监控策略
-> 后端每 15 分钟扫描一次
-> 生成买入观察 / 卖出观察信号
-> 信号先落库
-> 根据该监控策略的推送开关决定是否推送
```

后端建议新增：

- `strategy_monitors` 或 `position_strategy_links` 表：
  - 股票代码。
  - 策略编号。
  - 策略参数。
  - 监控周期，例如 `15m`。
  - 是否启用。
  - 是否推送。
  - 冷却时间，避免盘中反复提醒。
  - 来源回测 id 或优化任务 id。
  - 最近扫描时间、最近触发时间。
- 盘中扫描服务：
  - 定时读取已启用监控配置。
  - 拉取最新 15 分钟 K 线或实时行情。
  - 复用现有策略模块判断信号。
  - 按股票、策略、参数、方向、时间窗口生成 dedupe key。
  - 先写入 `signal_events`，再进入推送候选分发。
- 多因子优化服务：
  - 先做有限参数网格，不要一开始做复杂自动优化。
  - 输出最佳参数、收益率、最大回撤、交易次数、胜率。
  - 结果只能作为“观察策略”，不能生成绝对买卖建议。

App 建议新增：

- 量化回测结果页增加“保存为监控策略”。
- 股票详情或信号页增加“已绑定策略”列表。
- 信号页区分：
  - 盘中预警。
  - 收盘确认。
  - 普通展示信号。
  - 已忽略信号。
- 当前信号设置继续保留，用于控制普通扫描配置是否启用、是否推送。

验收标准：

- 用户能对某只股票保存一个 15 分钟监控策略。
- 后端能按 15 分钟周期扫描该股票。
- 同一股票同一策略同一方向在冷却期内不会重复刷屏。
- 触发后能在信号页看到策略、参数、触发条件、当前值、阈值和触发时间。
- 推送仍然只消费已落库信号。

### 持仓生命周期与单股收益曲线后续任务

当前结论：

- 当前持仓更像“当前持有列表”，还不是完整的股票生命周期记录。
- 后续需要记录建仓、加仓、减仓、清仓历史，并保留每只股票的收益曲线。
- 删除或清仓当前持仓时，不应删除该股票历史交易和历史收益记录。

目标结构：

```text
股票档案
-> 建仓记录
-> 加仓 / 减仓 / 清仓记录
-> 当前持仓快照
-> 单股收益曲线
-> 绑定策略监控
-> 历史信号记录
```

后端建议新增：

- `position_trades`：
  - 股票代码、交易方向、数量、价格、手续费、交易时间、备注。
  - 用于记录建仓、加仓、减仓、清仓。
- `position_snapshots`：
  - 股票代码、日期或时间桶、持仓数量、成本、市值、当日收益、累计收益、收益率。
  - 用于绘制单股收益曲线。
- `position_strategy_links`：
  - 股票与策略监控配置的绑定关系。
  - 后续可与 `strategy_monitors` 合并或引用。

App 建议新增：

- 建仓入口优化：
  - 建仓必须写入交易记录。
  - 支持分批建仓。
  - 支持加仓、减仓、清仓。
- 持仓记录页按券商持仓表风格设计：
  - 顶部展示账户/市场汇总卡片，例如市场总市值、持仓盈亏、购买力或现金余额。
  - 支持市场分组切换：港股、美股、沪深股，后续可扩展场内基金/ETF。
  - 支持“持仓 / 订单 / 历史”切换。
  - 列表第一列固定为股票名称、代码、币种、市场标签，右侧指标区可横向滑动。
  - 初始可见列建议为：可卖/持有、现价/成本、今日盈亏。
  - 向右滑动后展示：持仓盈亏、持仓盈亏率、市值、持仓占比、可用数量、累计收益等。
  - 列头支持排序，至少支持按市值、今日盈亏、持仓盈亏、持仓占比排序。
  - 行点击进入股票详情，长按或更多按钮进入加仓、减仓、清仓、编辑备注。
  - 页面应是高密度工具型布局，不做营销式大卡片堆叠。
- 股票详情页增加：
  - 当前收益。
  - 单股收益曲线。
  - 建仓/加仓/减仓/清仓历史。
  - 绑定策略。
  - 历史信号。
- 当前持仓成本应逐步从交易记录聚合计算，不再长期只依赖手填成本价。

验收标准：

- 每次建仓、加仓、减仓、清仓都有不可覆盖的历史记录。
- 单只股票能展示持有收益曲线。
- 清仓后仍能查看历史收益和历史信号。
- 策略监控能关联到具体股票和具体建仓周期。
- 持仓记录页能像券商 App 一样横向滑动查看更多列，不因字段多而把单行撑得过高。

当前实现状态：

- 后端已新增 `position_trades` 表。
- 后端已新增 `PositionTradeCreate`、`PositionTrade` 模型。
- 后端已新增交易记录 repository：`backend/app/repositories/position_trades.py`。
- 后端已新增接口：
  - `GET /api/v1/positions/trades`
  - `GET /api/v1/positions/{position_id}/trades`
  - `POST /api/v1/positions/{position_id}/trades`
- 创建持仓时会自动写入一条 `open` 建仓记录。
- 删除当前持仓不会删除历史交易记录。
- 后端已实现交易记录对当前持仓快照的聚合更新：
  - `add`：增加数量，并按原持仓成本和新增买入金额做加权平均成本。
  - `reduce`：减少数量，真实平均成本不变，券商式摊薄成本按卖出净收入重新摊薄；超过当前持仓数量会返回 400。
  - `close`：必须等于当前持仓数量，清仓后数量和成本归零。
- 后端已新增成本字段口径：
  - `avg_cost_price`：真实平均买入成本。
  - `adjusted_cost_price`：券商式摊薄成本。
  - `realized_profit`：已实现盈亏。
  - `cost_price`：兼容旧 App 字段，当前等于非负的券商式摊薄成本。
- 后端已新增 `position_snapshots` 表和收益快照接口：
  - `GET /api/v1/positions/snapshots`
  - `GET /api/v1/positions/snapshots/latest`
  - `POST /api/v1/positions/snapshots/capture`
  - `GET /api/v1/positions/{position_id}/snapshots`
- 收益快照当前已计算：
  - 当前价格。
  - 昨收。
  - 市值。
  - 今日盈亏。
  - 今日盈亏率。
  - 持仓盈亏。
  - 持仓盈亏率。
  - 总收益。
  - 总收益率。
  - 持仓占比。

下一步继续：

1. 增加交易记录的已实现收益详情统计。
2. 再接 App 券商式持仓表、交易记录页面和策略监控选择入口。
3. 增加信号推送记录展示，让用户能看到某条策略信号是否成功通知到设备。

### 场内基金/ETF 后续任务

当前结论：

- Futu 可以提供 A 股交易所证券行情，实测 `SH.510300`、`SZ.159919` 这类场内 ETF 可以拿到行情。
- Futu 不适合作为 A 股场外开放式基金净值主数据源。
- 当前后端 `futu_client.py` 对市场和币种映射不完整，非 `US.` 默认被标成 `HK/HKD`，支持 A 股 ETF 前必须先修。

执行顺序：

1. 修正 `futu_client.py` 市场和币种映射：`SH.`、`SZ.` 识别为 A 股/CNY。
2. 股票搜索和添加持仓支持 A 股 ETF/LOF，示例 `SH.510300`、`SZ.159919`。
3. 场内 ETF 复用现有行情快照、K 线、量化回测和信号扫描。
4. App 端资产类型增加区分：股票、场内基金/ETF、场外基金。
5. 场外基金另建 `fund_nav_provider`，不要走 Futu 行情接口。

验收标准：

- 添加 `SH.510300` 后，详情页显示市场为 A 股或 CN，币种为 CNY。
- 场内 ETF 能正常刷新行情和 K 线。
- 场外基金不会被误当成股票/ETF，也不会显示成交量、盘口等不适用字段。

### 量化 K 线实时性问题

已发现问题：

- 同一股票详情页 K 线可刷新到最新交易日，但量化页买卖点图曾停在旧日期。
- 原因之一是量化页默认结束日期曾固定为历史日期。
- 原因之二是后端回测只判断缓存 K 线数量是否足够，没有判断缓存最新日期是否覆盖回测结束日期。

必须保持的修复方向：

1. 量化页默认结束日期使用当前日期。
2. App 启动回测前按请求日期区间强制刷新 K 线。
3. 后端回测如果发现缓存最新 K 线早于结束日期，即使缓存数量足够，也必须先刷新。
4. 后续策略信号扫描也必须按最新 K 线计算，不能使用旧回测结果当作实时信号。
5. 量化页买卖点图可以继续独立于详情页 K 线组件，但均线指标必须按当前策略参数绘制，例如短/长均线为 5/10 时图表显示 MA5/MA10，不能硬编码 MA5/MA20。
6. 价格跌破均线和双均线死叉不是同一个信号；后续若需要“收盘价跌破 MA”提醒，新增独立策略条件。

### 马上下一步：价格跌破均线策略

当前用户关心的是详情页已经显示收盘价跌破 MA5/MA10，但量化页 MA Cross 没有出现卖点。原因是 MA Cross 的规则是短均线下穿长均线，不是收盘价跌破均线。

下一步不要修改 MA Cross 语义，应该新增独立策略：

```text
strategy_code: price_break_ma
策略名称：价格跌破/站回均线
```

第一版参数：

```text
ma_window: 5 / 10 / 20 / 60
direction: break_down / recover_up / both
```

第一版触发：

```text
跌破：上一根收盘价 >= 上一根 MA，当前收盘价 < 当前 MA
站回：上一根收盘价 <= 上一根 MA，当前收盘价 > 当前 MA
```

执行顺序：

1. 后端新增 `backend/app/strategies/price_break_ma.py`，复用现有策略接口。
2. 策略注册到 `backend/app/strategies/__init__.py` 或现有策略注册表。
3. 后端策略列表暴露参数定义，App 量化页能选择该策略。
4. 回测结果买卖点图按该策略参数显示对应 MA 线。
5. 后续信号中心实时扫描复用同一个判断，生成可解释信号。

验收标准：

- 选择 `price_break_ma` 后，可以解释“收盘价跌破 MA10”这类信号。
- 选择 `ma_cross` 时，仍只解释 MA5/MA10 金叉或死叉。
- 信号文案包含收盘价、MA 值、周期、方向和触发日期。
- 推送候选只使用中性“观察信号”，不写投资建议。

当前实现状态：

- 已新增后端 `price_break_ma` 策略，参数为 `ma_window` 和 `direction`。
- 已加入策略注册和默认种子数据。
- App 量化页已支持该策略参数输入，其中触发方向使用下拉选项。
- 量化结果区已显示该策略参数，并在买卖点图只画对应 MA。
- 下一步若继续做信号中心，应复用该策略输出，不要另写一套价格跌破均线判断。
