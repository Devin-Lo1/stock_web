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
