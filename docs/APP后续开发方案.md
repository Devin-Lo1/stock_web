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

1. 修复后端历史中文乱码数据。
2. 继续拆分 `position_detail_screen.dart` 的 K 线相关代码。
3. 完善后端错误处理和 API 响应结构。
4. 完善持仓持久化与数据库迁移。
5. 增加信号历史和策略信号落库。
6. 新增量化入口和第一版回测框架。
7. 增加推送与提醒设置。
8. 生产化部署与监控。

## 3. 任务一：后端中文乱码修复

### 背景

后端历史持仓名称中存在乱码，例如中文名称被错误编码为连续拉丁扩展字符形态。此问题属于历史数据污染，不是 Flutter 渲染问题。

### 目标

- 修复后端存储中的股票名称。
- 确保 FastAPI 返回 UTF-8 JSON。
- 确保 Flutter 展示中文正常。

### 建议步骤

1. 定位后端持仓数据来源。
2. 备份当前数据文件或数据库。
3. 明确每条乱码记录的正确中文。
4. 用显式 UTF-8 方式修复数据。
5. 调用 `/api/v1/positions` 验证返回正常中文。
6. 真机刷新 App 验证。

### 验收标准

- 后端 `/api/v1/positions` 返回中文正常。
- App 首页、持仓页、详情页中文正常。
- 乱码扫描无新增污染。

## 4. 任务二：继续拆分持仓详情页

### 背景

`mobile_app/lib/screens/position_detail_screen.dart` 仍然较大，主要因为 K 线交互、画布、横屏全图和信息面板仍在同一文件。

### 目标结构

```text
mobile_app/lib/widgets/chart/interactive_kline_preview.dart
mobile_app/lib/widgets/chart/interactive_kline_painter.dart
mobile_app/lib/widgets/chart/selected_candle_info_panel.dart
mobile_app/lib/screens/full_screen_kline_screen.dart
mobile_app/lib/utils/kline_indicators.dart
```

### 建议拆分顺序

1. 抽 `utils/kline_indicators.dart`
   - MA 计算。
   - MA 格式化。
2. 抽 `selected_candle_info_panel.dart`
   - 选中 K 线信息面板。
   - 信息单元格。
3. 抽 `interactive_kline_painter.dart`
   - K 线绘制。
   - MA 绘制。
   - 十字光标。
   - 高低点标签。
4. 抽 `interactive_kline_preview.dart`
   - 手势、可见区间、加载/错误/空状态。
5. 抽 `full_screen_kline_screen.dart`
   - 横屏锁定。
   - 全图展示。
   - 退出恢复竖屏。

### 约束

- 每次只拆一个文件或一组强相关小组件。
- 拆分时不改 UI 行为。
- 拆分后立刻运行 format / analyze / test。

### 验收标准

- 详情页显示与拆分前一致。
- 横屏全图可打开和退出。
- K 线可拖动、点选、显示 MA。
- `flutter analyze` 无问题。
- `flutter test` 通过。

## 5. 任务三：后端 API 结构与错误处理

### 目标

- 统一 API 错误返回。
- 明确富途不可用、权限不足、网络超时、无数据等状态。
- Flutter 能展示明确状态，而不是只显示“连接失败”。

### 建议后端错误格式

```json
{
  "code": "FUTU_UNAVAILABLE",
  "message": "FutuOpenD 未连接",
  "detail": {}
}
```

### Flutter 对应处理

- `ApiException` 增加错误码解析。
- 设置页展示后端/Futu 状态。
- 首页区分：
  - 后端已连接。
  - 后端离线。
  - 富途不可用。
  - 使用缓存数据。

### 验收标准

- 关闭 FutuOpenD 时 App 不崩溃。
- 后端离线时 App 仍显示本地缓存。
- 请求超时时不会无限转圈。

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
