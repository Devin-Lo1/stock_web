# App 总体开发规划

最后更新：2026-05-22

当前最新状态：

- 持仓列表已接入后端收益快照并采用券商式横向表格。
- 持仓详情页已接入后端交易历史、单股收益快照曲线、加仓、减仓和清仓入口。
- 持仓详情页已整合单股策略监控、历史信号和推送记录。
- 交易历史支持删除，历史信号支持忽略。
- 推送记录支持按股票代码和状态筛选，支持删除和重试。
- 核心持仓收益、市值、仓位占比以后端 `position_snapshots` 为权威来源。
- 下一阶段重点是启用并验证现有策略监控 scheduler，然后补扫描日志、真实推送和策略监控总览。

本文档用于让新接手者快速理解项目目标、阶段路线、技术架构和长期方向。内容整合自：

- `docs/安卓App一周MVP开发计划.md`
- `docs/完整技术方案文档.md`
- `docs/项目记忆与交接.md`
- `docs/项目开发计划与技术方案整合.md`
- `docs/Flutter安卓环境准备.md`
- 当前实际代码与后端接口状态

## 1. 项目定位

本项目是一个面向个人持仓监控和策略辅助的智能量化交易助手 App。

第一阶段不是自动交易，也不是投资顾问，而是：

- 手动维护持仓。
- 展示实时或准实时行情。
- 计算当日收益、持有收益、涨跌幅。
- 根据阈值生成止盈观察、止损观察、异动提醒。
- 展示 K 线与行情概览。
- 后续接入后端、富途 API、推送、策略量化和回测。

核心闭环：

```text
手动录入持仓
  -> 后端保存/本地缓存
  -> 获取行情与 K 线
  -> 计算盈亏
  -> 生成策略信号
  -> App 展示
  -> 后续推送提醒
```

长期闭环：

```text
持仓与关注标的
  -> 行情/基本面/因子数据
  -> 策略配置
  -> 后端回测
  -> 回测结果展示
  -> 生成实盘观察信号
  -> App/推送提醒
```

当前功能完善方向：

```text
策略监控配置
  -> scheduler 定时扫描
  -> 扫描日志解释结果
  -> 历史信号落库
  -> 真实推送通道
  -> 推送记录追溯
  -> 单股详情和总览页统一查看
```

## 2. 当前实际状态

### 2.1 Flutter App

路径：

```text
mobile_app/
```

已实现：

- `main.dart` 已保持薄入口。
- 首页、持仓、量化、信号、设置、我的、显示设置、持仓详情、添加/编辑弹窗。
- 港股/美股切换。
- 本地添加、编辑、删除持仓。
- 后端连接状态展示。
- FastAPI 持仓 API 接入。
- 本地持仓缓存和后端失败 fallback。
- 行情快照模型 `QuoteSnapshot`。
- K 线模型 `Candle`。
- 详情页交互 K 线、MA 标签、横屏全图。
- 详情页 K 线 VOL 副图。
- 股票搜索建议，本地候选 + 后端搜索。
- 后端落库信号展示和本地信号兜底。
- 信号分类筛选。
- 信号设置入口。
- 策略监控选择入口。
- scheduler 状态展示。
- 推送记录查看入口。
- 推送记录按股票代码/状态筛选、删除和重试。
- 量化回测入口、历史回测、参数快照、收益曲线和买卖点 K 线。
- 日间/夜间模式。
- 真机 debug APK 安装验证。

最近验证已通过：

```text
Flutter analyze: No issues found
Flutter test: 37 passed
Backend pytest: 63 passed
LAN debug APK build: Success
```

### 2.2 后端

路径：

```text
backend/
```

当前后端是 FastAPI 服务，已不只是最小壳子。

当前接口包括：

```text
GET    /
GET    /health
GET    /api/v1/positions
POST   /api/v1/positions
PUT    /api/v1/positions/{position_id}
DELETE /api/v1/positions/{position_id}
GET    /api/v1/quotes
GET    /api/v1/klines/{stock_code}
GET    /api/v1/signals
GET    /api/v1/stocks/search
GET    /api/v1/futu/health
GET    /api/v1/futu/quote
GET    /api/v1/futu/kline-quota
POST   /api/v1/quotes/refresh
POST   /api/v1/klines/refresh
GET    /api/v1/strategies
POST   /api/v1/backtests
GET    /api/v1/backtests
GET    /api/v1/backtests/{run_id}
GET    /api/v1/signals/events
POST   /api/v1/signals/scan
GET    /api/v1/signals/configs
PUT    /api/v1/signals/configs/{config_id}
GET    /api/v1/strategies/monitors
POST   /api/v1/strategies/monitors
PUT    /api/v1/strategies/monitors/{monitor_id}
DELETE /api/v1/strategies/monitors/{monitor_id}
GET    /api/v1/strategies/monitors/scheduler/status
POST   /api/v1/strategies/monitors/scheduler/start
POST   /api/v1/strategies/monitors/scheduler/stop
GET    /api/v1/notifications/push-records
POST   /api/v1/notifications/push-records/{record_id}/retry
DELETE /api/v1/notifications/push-records/{record_id}
```

当前后端包含：

- `backend/app/main.py`
- `backend/app/routers/`
- `backend/app/schemas/`
- `backend/app/repositories/`
- `backend/app/db/`
- `backend/app/backtest/`
- `backend/app/strategies/`
- `backend/app/services/futu_client.py`
- `backend/app/services/stock_search.py`
- `backend/app/services/signal_scanner.py`
- `backend/app/services/strategy_monitor_scanner.py`
- `backend/app/services/strategy_monitor_scheduler.py`
- `backend/app/services/push_service.py`
- `backend/app/services/push_providers/`

### 2.3 文档

后续新接手优先阅读：

```text
docs/APP开发强约束规范.md
docs/APP新开发者接手指南.md
docs/APP项目结构说明.md
docs/APP马上解决任务顺序.md
docs/APP架构审计与优化路线.md
docs/APP总体开发规划.md
docs/APP后续开发方案.md
```

原始文档作为历史背景保留。

### 2.4 后续功能完善路线图

后续功能按“先可信、再好用、最后高级”的顺序推进。

近期优先：

1. 启用并验证现有策略监控 scheduler。
2. 增加扫描日志与原因说明，让用户知道每次扫描为什么触发或未触发。
3. 接入真实推送通道，优先 Huawei Push Kit，再补 FCM。
4. 建立策略监控总览，统一查看所有股票监控状态。
5. 完善信号处置流：已读、忽略、加入观察、关联交易、复盘备注。

中期完善：

1. 持仓风险雷达：成本、均线、回撤、波动、仓位风险。
2. 组合层面风控：市场分布、集中度、总盈亏、最大回撤。
3. 回测到监控一键落地：从回测结果保存为单股策略监控。
4. K 线交互增强：十字光标、指标开关、买卖点和信号标记。
5. 数据健康检查：FutuOpenD、行情权限、K 线更新时间、失败股票。

长期高级：

1. 自动复盘日报。
2. 策略参数推荐。
3. 多账户 / 多券商支持。
4. 云同步与备份。
5. 权限、安全和推送内容脱敏。

详细拆解和验收标准见 `docs/APP后续开发方案.md` 的“后续功能完善路线图”。

## 3. 推荐总体架构

```text
Flutter Android App
  |
  | REST / WebSocket
  v
FastAPI Backend
  |
  +-- 持仓服务
  +-- 行情服务
  +-- K 线服务
  +-- 策略服务
  +-- 回测服务
  +-- 推送服务
  |
  | futu-api / FutuOpenD
  v
富途行情与账户能力

Backend
  |
  +-- SQLite / PostgreSQL: 用户、持仓、行情、K线、信号、回测
  +-- Redis: 行情缓存、信号队列、推送队列
  +-- Firebase 或厂商推送
  +-- 聚宽/JQData: 后续基本面与多因子数据
```

原则：

- Flutter 只负责展示、交互和调用后端。
- FastAPI 是 App 与富途、聚宽、数据库、推送之间的统一服务层。
- 富途 API 不放在 Flutter 端。
- 回测和多因子计算不放在 Flutter 端。

## 4. 技术栈

### 4.1 移动端

当前：

- Flutter
- Dart
- Material 3
- `http`
- 自定义 `CustomPainter` K 线
- Android MVP 优先

后续可加入：

- `web_socket_channel`：实时行情/信号推送。
- `shared_preferences` 或 `sqflite`：更完整本地缓存。
- `riverpod` / `provider` / `bloc`：状态管理。
- 图表库或继续增强自定义 K 线。
- 推送相关插件。

### 4.2 后端

当前与推荐：

- Python 3.11+
- FastAPI
- Uvicorn
- Pydantic
- SQLite MVP，后续 PostgreSQL
- futu-api / FutuOpenD
- APScheduler MVP，后续 Celery
- Redis 后续用于行情缓存和队列

### 4.3 行情数据

推荐路径：

- 富途：实时行情、K 线、成交额、换手、PE、权证字段。
- 聚宽/JQData：后续基本面、多因子、行业、财务、因子库。
- 后端统一输出 App 所需结构。

## 5. 阶段路线

### 阶段 1：Flutter MVP 与本地闭环

状态：基本完成。

目标：

- 页面框架。
- 本地持仓。
- 收益计算。
- 本地信号。
- 日间/夜间模式。
- 详情页和 K 线展示。

### 阶段 2：后端模拟 API 与 Flutter 接入

状态：已部分完成。

已实现：

- 持仓 CRUD API。
- 行情/K 线接口。
- Flutter `ApiClient`。
- `PositionRepository`。
- 本地缓存 fallback。
- 真机通过 `adb reverse` 访问本机后端。

仍需补强：

- 后端中文编码数据修复。
- 后端错误结构统一。
- API 测试。
- 本地数据库/正式数据库迁移策略。

### 阶段 3：富途行情稳定接入

目标：

- FutuOpenD 健康检查。
- 单股票报价。
- 多股票行情刷新。
- K 线缓存。
- 股票搜索。
- 行情权限与错误状态展示。

当前已有雏形，但仍需做：

- 更稳定重连机制。
- 明确行情更新时间。
- 失败时展示延迟或缓存状态。
- 对衍生品字段做更完整适配。

### 阶段 4：推送与信号历史

目标：

- 信号落库。
- 信号已读/未读。
- 推送设置。
- 后端触发推送。
- App 前后台接收提醒。

建议：

- MVP 可先做 App 内信号历史。
- 当前已完成 App 本地通知第一阶段，但它只覆盖 App 运行或刷新后的提醒。
- 真正“重要信号立刻到手机”需要后端信号扫描、设备 token、推送记录和真实推送通道。
- 第一版真实推送优先接 FCM，跑通闭环后再按设备品牌评估华为、小米、OPPO、vivo 等厂商推送。
- 推送内容只放信号摘要和信号 id，详细持仓和策略信息由 App 打开后再拉取。

### 阶段 5：策略量化与回测

目标：

- 新增“量化”入口。
- 策略列表。
- 因子开关。
- 参数设置。
- 选择标的、周期、区间。
- 后端运行回测。
- App 展示收益曲线、回撤、胜率、交易记录。
- 回测结果可保存为股票监控策略。
- 支持按股票绑定策略参数，并按 15 分钟等周期做盘中扫描。
- 盘中扫描触发后生成买入观察 / 卖出观察信号，先落库，再按推送设置分发。

第一版策略：

- 双均线策略。
- MACD 趋势策略。
- RSI 超买超卖策略。
- BOLL 突破/回归策略。
- 成交量放大 + 动量策略。

原则：

- 策略逻辑和回测引擎自己写。
- 聚宽/JQData 可作为数据源，不替代策略系统。
- 回测只做辅助，不构成投资建议。
- 盘中策略监控必须有去重和冷却时间，不能因价格反复穿越指标而刷屏。
- App 文案使用“买入观察 / 卖出观察”，不写绝对投资建议。

### 阶段 5.1：持仓生命周期与策略监控

目标：

- 建仓、加仓、减仓、清仓都保留历史记录。
- 当前持仓成本逐步从交易记录聚合计算。
- 每只股票保留单股收益曲线。
- 每只股票可绑定一个或多个监控策略。
- 监控策略可以来自量化页回测或多因子优化结果。

建议流程：

```text
建仓 / 加仓
-> 写入交易记录
-> 更新当前持仓快照
-> 生成或更新单股收益曲线
-> 可绑定回测得到的策略参数
-> 后端按周期扫描并生成信号
```

注意：

- 清仓或删除当前持仓不应删除历史交易、收益曲线和历史信号。
- 策略监控与推送设置应分开：策略可以继续扫描，但可关闭推送候选。
- 多因子优化先做有限参数网格，稳定后再考虑更复杂优化。
- 持仓记录页应参考券商持仓表：第一列固定股票名称/代码，右侧指标列横向滑动，避免把页面做成冗长卡片列表。

持仓记录页建议列：

```text
固定列：名称、代码、市场、币种
初始指标：可卖/持有、现价/成本、今日盈亏
右滑指标：持仓盈亏、持仓盈亏率、市值、持仓占比、可用数量、累计收益
```

持仓记录页建议操作：

- 港股、美股、沪深股市场切换。
- 持仓、订单、历史切换。
- 按市值、今日盈亏、持仓盈亏、持仓占比排序。
- 行点击进入股票详情。
- 行操作支持加仓、减仓、清仓、编辑备注。

### 阶段 6：生产化与部署

目标：

- Docker Compose。
- PostgreSQL。
- Redis。
- 环境变量配置。
- 日志和监控。
- 备份策略。
- 生产 API 域名和 HTTPS。

## 6. 数据模型规划

### 6.1 持仓

建议字段：

```text
id
user_id
market
code
name
quantity
cost_price
currency
created_at
updated_at
```

行情字段不应长期写死在持仓表，应由行情表或缓存提供。

后续应补充持仓生命周期表：

```text
position_trades
position_snapshots
position_strategy_links
strategy_monitors
```

建议职责：

- `position_trades`：记录建仓、加仓、减仓、清仓。
- `position_snapshots`：记录单股市值、收益、收益率和曲线点。
- `position_strategy_links`：记录股票与策略监控的绑定关系。
- `strategy_monitors`：记录策略编号、参数、扫描周期、启用状态、推送候选、冷却时间和来源回测。

### 6.2 行情快照

```text
code
market
currency
current_price
previous_close
open
high
low
volume
turnover
turnover_rate
pe_ratio
lot_size
change
change_rate
quote_time
```

### 6.3 K 线

```text
code
market
period
time
open
high
low
close
volume
turnover
```

### 6.4 信号

```text
id
user_id
position_id
code
signal_type
level
message
trigger_value
threshold_value
created_at
read_at
notified_at
```

### 6.5 策略与回测

```text
strategy_definitions
strategy_parameters
backtest_runs
backtest_equity_curve
backtest_trades
strategy_signals
```

## 7. API 规划

### 7.1 当前已有接口

```text
GET    /health
GET    /api/v1/positions
POST   /api/v1/positions
PUT    /api/v1/positions/{position_id}
DELETE /api/v1/positions/{position_id}
GET    /api/v1/quotes
GET    /api/v1/klines/{stock_code}
GET    /api/v1/signals
GET    /api/v1/stocks/search
GET    /api/v1/futu/health
GET    /api/v1/futu/quote
GET    /api/v1/futu/kline-quota
POST   /api/v1/quotes/refresh
POST   /api/v1/klines/refresh
```

### 7.2 后续接口

```text
GET    /api/v1/settings/strategy
PUT    /api/v1/settings/strategy
GET    /api/v1/signals/history
PATCH  /api/v1/signals/{id}/read
POST   /api/v1/signals/recalculate
GET    /api/v1/strategies
POST   /api/v1/strategies
PUT    /api/v1/strategies/{id}
POST   /api/v1/backtests
GET    /api/v1/backtests/{id}
GET    /api/v1/backtests/{id}/equity-curve
GET    /api/v1/backtests/{id}/trades
WS     /ws/quotes
WS     /ws/signals
```

## 8. 环境与真机调试

### 8.1 Flutter / Android

常用检查：

```powershell
D:\flutter\bin\flutter.bat doctor -v
D:\flutter\bin\flutter.bat devices
```

真机设备：

```text
NOH AN00
Android 12
device id: PQY0221B24008957
```

### 8.2 后端连接方式

本项目 App 连接后端有三种主要方式：USB ADB reverse、局域网 Wi-Fi、远程服务器。每次切换连接方式，都要确认 `API_BASE_URL`、后端监听地址、防火墙和手机网络状态。

#### 8.2.1 本机后端默认地址

电脑本机访问后端默认使用：

```text
http://127.0.0.1:8000
```

检查：

```powershell
curl http://127.0.0.1:8000/health
```

如果电脑访问该地址失败，先处理后端启动问题，不要直接怀疑 Flutter。

#### 8.2.2 USB ADB reverse 方式

适用场景：

- 手机通过 USB 连接电脑。
- 本地开发速度优先。
- 不想调整 Windows 防火墙或局域网配置。

连接方式：

```text
手机 App -> 手机 127.0.0.1:8000 -> USB/ADB reverse -> 电脑 127.0.0.1:8000 后端
```

命令：

```powershell
D:\Android\Sdk\platform-tools\adb.exe -s PQY0221B24008957 reverse tcp:8000 tcp:8000
D:\Android\Sdk\platform-tools\adb.exe reverse --list
```

此方式下 App 可以继续使用默认地址：

```text
http://127.0.0.1:8000
```

注意：

- `127.0.0.1` 在手机上本来代表手机自己。
- `adb reverse` 会把手机的 `127.0.0.1:8000` 转发到电脑的 `127.0.0.1:8000`。
- 拔插 USB、手机变成 `offline`、重启 ADB、重启电脑后，reverse 可能失效。
- 如果 App 显示“后端连接失败”，优先检查：

```powershell
D:\Android\Sdk\platform-tools\adb.exe devices -l
D:\Android\Sdk\platform-tools\adb.exe reverse --list
curl http://127.0.0.1:8000/health
```

#### 8.2.3 局域网 Wi-Fi 方式

适用场景：

- 手机和电脑连接同一个 Wi-Fi。
- 希望脱离 USB reverse。
- 想提前模拟未来服务器访问方式。

连接方式：

```text
手机 App -> Wi-Fi 局域网 -> 电脑局域网 IP:8000 后端
```

当前电脑 WLAN IP 示例：

```text
192.168.1.4
```

电脑后端必须监听 `0.0.0.0:8000`，不能只监听 `127.0.0.1:8000`。检查命令：

```powershell
netstat -ano | findstr ":8000"
```

应看到类似：

```text
0.0.0.0:8000 LISTENING
```

构建局域网版本 App：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://192.168.1.4:8000
D:\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk
```

为了确认 App 不再依赖 USB reverse，安装后可以清空 reverse：

```powershell
D:\Android\Sdk\platform-tools\adb.exe reverse --remove-all
D:\Android\Sdk\platform-tools\adb.exe reverse --list
```

局域网方式常见故障：

- Windows 防火墙未放行 TCP 8000。
- 手机和电脑不在同一个 Wi-Fi 或同一个网段。
- 路由器开启了 AP 隔离/无线隔离。
- 电脑 IP 变化后，App 仍然使用旧 IP。
- 后端只监听 `127.0.0.1`，没有监听 `0.0.0.0`。

Windows 防火墙放行命令需要管理员 PowerShell：

```powershell
netsh advfirewall firewall add rule name="Stock Web Backend 8000" dir=in action=allow protocol=TCP localport=8000
```

验证顺序：

```powershell
curl http://192.168.1.4:8000/health
D:\Android\Sdk\platform-tools\adb.exe devices -l
D:\Android\Sdk\platform-tools\adb.exe shell ip route
```

如果手机 `ping` 不通电脑，不一定代表 HTTP 不通，因为 ICMP 可能被防火墙拦截。最终以 App 是否能访问 `http://电脑局域网IP:8000/health` 对应服务为准。

#### 8.2.4 远程服务器方式

适用场景：

- 后端部署到云服务器。
- 手机不再依赖开发电脑。
- 准备多人或长期使用。

连接方式：

```text
手机 App -> 公网 HTTPS -> 云服务器 FastAPI 后端
```

推荐要求：

- 使用 HTTPS 域名，不长期使用裸 IP。
- 后端通过 Nginx/Caddy 等反向代理暴露。
- 云服务器安全组放行 80/443。
- App 构建时通过 `--dart-define=API_BASE_URL=...` 指向服务器。

示例：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\flutter.bat build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

远程方式注意：

- 不要把富途、聚宽密钥写入 Flutter。
- API 鉴权、日志、限流、错误码必须在后端统一处理。
- 生产环境不要依赖 `usesCleartextTraffic=true` 的 HTTP 明文访问。
- App 应展示明确的后端连接状态和错误说明。

### 8.3 Java / Flutter JDK

若出现 `JAVA_HOME is not set`，优先检查：

```powershell
D:\flutter\bin\flutter.bat doctor -v
D:\flutter\bin\flutter.bat config --jdk-dir="D:\java\jdk-17.0.19+10"
```

## 9. 风险与处理

### 9.1 富途权限风险

风险：

- 行情权限不足。
- K 线权限不足。
- FutuOpenD 未启动。
- 订阅或刷新失败。

处理：

- 先测单股票报价。
- 再测多股票报价。
- 再测 K 线。
- 最后接 App UI。

### 9.2 推送风险

风险：

- FCM 在国内设备上不稳定。

处理：

- MVP 先做 App 内信号列表。
- 推送作为增强。
- 保留厂商推送方案。

### 9.3 数据准确性风险

处理：

- 展示行情更新时间。
- 标注模拟、延迟或缓存数据。
- 不做自动交易。
- 信号只做提醒，不做投资建议。

### 9.4 策略风险

处理：

- 回测不代表未来收益。
- 多策略组合，不依赖单一指标。
- 保存回测参数和假设。
- 明确手续费、滑点、样本区间。

### 9.5 编码风险

处理：

- 遵守 `docs/APP开发强约束规范.md`。
- 中文文件保持 UTF-8。
- 不使用默认编码 PowerShell 批量写中文文件。

## 10. 推荐阅读顺序

新接手者先读：

1. `docs/APP开发强约束规范.md`
2. `docs/APP新开发者接手指南.md`
3. `docs/APP项目结构说明.md`
4. `docs/APP马上解决任务顺序.md`
5. `docs/APP架构审计与优化路线.md`
6. `docs/APP后续开发方案.md`
7. `docs/APP总体开发规划.md`

旧历史文档若不存在，不再作为接手入口；以 `docs/README.md` 中列出的当前文档为准。

## 11. 数据库路线更新

项目已经从纯 SQLite 本地存储推进到 PostgreSQL 本地主库。这样更适合后续多人使用、云服务器部署、策略回测和历史数据沉淀。

### 2026-05-15 数据库层拆分状态

当前后端数据库层已完成一次结构拆分：

- `backend/app/database.py`：兼容门面，只导出旧函数名。
- `backend/app/db/core.py`：数据库连接、SQLite/PostgreSQL 占位符兼容、字段补齐工具。
- `backend/app/db/init.py`：建表和初始化流程。
- `backend/app/db/converters.py`：row/model/JSON/时间转换。
- `backend/app/db/seed.py`：默认 seed 和历史中文名称修复。
- `backend/app/repositories/positions.py`：持仓读写。
- `backend/app/repositories/market_data.py`：行情和 K 线读写。
- `backend/app/repositories/strategies.py`：策略定义读写。
- `backend/app/repositories/backtests.py`：回测运行和结果读写。

本次拆分已通过：

```text
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
pytest: 7 passed
```

后续开发方向：

- 新增数据库读写必须进入对应 repository。
- 新增表、字段、初始化逻辑进入 `db/init.py`。
- 新增模型转换进入 `db/converters.py`。
- 逐步把 routers 和 backtest engine 从 `app.database` 兼容门面迁移为直接引用 repositories。

### 当前阶段

- 本地 PostgreSQL 已可用。
- 后端通过 `DATABASE_URL` 连接数据库。
- 旧 SQLite 数据已经迁移到 PostgreSQL。
- App 仍通过 FastAPI 访问数据，不直接连接数据库。

### 后续云端迁移

如果采用云服务器自建 PostgreSQL：

- 本机使用 `pg_dump` 导出。
- 云服务器安装 PostgreSQL。
- 上传备份文件。
- 使用 `pg_restore` 或 `psql` 导入。
- 修改后端服务器 `.env` 中的 `DATABASE_URL`。

如果采用云数据库 RDS：

- 本机使用 `pg_dump` 导出。
- 在云厂商创建 PostgreSQL 实例和数据库账号。
- 使用云厂商迁移工具或 `pg_restore` 导入。
- 修改后端服务器 `.env` 中的 `DATABASE_URL`。

### 规划原则

- 回测和策略数据以后全部进入 PostgreSQL。
- Flutter 不直连 PostgreSQL。
- 数据库密码只放 `.env` 或云服务器环境变量，不写入 Git。
