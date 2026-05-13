# App 总体开发规划

最后更新：2026-05-13

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

## 2. 当前实际状态

### 2.1 Flutter App

路径：

```text
mobile_app/
```

已实现：

- `main.dart` 已保持薄入口。
- 首页、持仓、信号、设置、我的、显示设置、持仓详情、添加/编辑弹窗。
- 港股/美股切换。
- 本地添加、编辑、删除持仓。
- 后端连接状态展示。
- FastAPI 持仓 API 接入。
- 本地持仓缓存和后端失败 fallback。
- 行情快照模型 `QuoteSnapshot`。
- K 线模型 `Candle`。
- 详情页交互 K 线、MA 标签、横屏全图。
- 股票搜索建议，本地候选 + 后端搜索。
- 本地信号生成。
- 日间/夜间模式。
- 真机 debug APK 安装验证。

最近验证已通过：

```text
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
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
```

当前后端包含：

- `backend/app/main.py`
- `backend/app/database.py`
- `backend/app/mock_store.py`
- `backend/app/schemas.py`
- `backend/app/services/futu_client.py`
- `backend/app/services/futu_import.py`
- `backend/app/services/stock_search.py`

### 2.3 文档

后续新接手优先阅读：

```text
docs/APP开发强约束规范.md
docs/APP总体开发规划.md
docs/APP后续开发方案.md
docs/APP项目结构说明.md
```

原始文档作为历史背景保留。

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
- FCM 在国内环境可能不稳定，后续评估厂商推送。

### 阶段 5：策略量化与回测

目标：

- 新增“量化”入口。
- 策略列表。
- 因子开关。
- 参数设置。
- 选择标的、周期、区间。
- 后端运行回测。
- App 展示收益曲线、回撤、胜率、交易记录。

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

### 8.2 后端

本机后端默认：

```text
http://127.0.0.1:8000
```

检查：

```powershell
curl http://127.0.0.1:8000/health
```

真机访问电脑本机后端：

```powershell
D:\Android\Sdk\platform-tools\adb.exe -s PQY0221B24008957 reverse tcp:8000 tcp:8000
```

如果不用 USB reverse，必须使用电脑局域网 IP。

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
2. `docs/APP总体开发规划.md`
3. `docs/APP后续开发方案.md`
4. `docs/APP项目结构说明.md`

需要历史背景时再读：

- `docs/项目开发计划与技术方案整合.md`
- `docs/项目记忆与交接.md`
- `docs/安卓App一周MVP开发计划.md`
- `docs/完整技术方案文档.md`
- `docs/Flutter安卓环境准备.md`
