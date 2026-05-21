# App 新开发者接手指南

最后更新：2026-05-21

当前代码功能基线：

```text
efcfed4 feat: add strategy monitor frontend
```

本文档给新开发者使用。目标是：读完 `docs/` 后能知道当前项目做到哪、不能做什么、下一步从哪里开始。

## 1. 必读顺序

新开发者开始写代码前，按下面顺序阅读：

1. `docs/APP开发强约束规范.md`
2. `docs/APP新开发者接手指南.md`
3. `docs/APP项目结构说明.md`
4. `docs/APP马上解决任务顺序.md`
5. `docs/APP架构审计与优化路线.md`
6. `docs/APP后续开发方案.md`
7. `docs/APP总体开发规划.md`

如果这些文档出现冲突，优先级为：

```text
APP开发强约束规范
-> APP新开发者接手指南
-> APP马上解决任务顺序
-> APP架构审计与优化路线
-> 其他历史规划文档
```

## 2. 开发前检查

每次接手前先确认：

```powershell
cd C:\Users\58229\Desktop\stock_web
git status --short
git log -1 --oneline
```

要求：

- 工作区应尽量干净。
- 如果有未提交改动，先确认是否是用户或上一位开发者留下的，不要直接回滚。
- 禁止使用 `git reset --hard` 或 `git checkout --` 覆盖用户文件。

## 3. 当前功能状态

### 后端已完成

- FastAPI 后端已按 routers、schemas、repositories、services、db 分层。
- `backend/app/database.py` 只作为兼容门面，新增数据库读写不得写回这里。
- 持仓 CRUD、行情快照、K 线缓存、股票搜索、Futu 健康检查已接入。
- PostgreSQL 本地主库已可用，测试库为 `stock_web_test`。
- 回测系统已具备 MA Cross、RSI Reversal、MACD Trend、Price Break MA。
- 回测结果支持历史列表、详情、收益曲线、交易记录。
- 信号中心已支持：
  - `signal_events` 落库。
  - 手动扫描。
  - 扫描配置启用/停用。
  - 推送候选开关。
  - 分类筛选。
  - 已读/忽略后端接口。
- 策略监控后端已支持：
  - `strategy_monitors` 表。
  - 创建、更新、删除监控。
  - 手动扫描。
  - scheduler 状态、启动、停止。
  - 扫描后先写入 `signal_events`，再按推送候选进入 `push_records`。
- 推送后端已支持多通道抽象：
  - FCM。
  - Huawei Push Kit。
  - 预留小米、OPPO、vivo、APNS、local、unknown。
  - 未配置真实通道时写入 `skipped`，不能丢信号历史。
- 持仓生命周期后端已开始：
  - `position_trades`。
  - `position_snapshots`。
  - 建仓、加仓、减仓、清仓记录。
  - 真实平均成本和券商式摊薄成本字段。

### Flutter 已完成

- `main.dart` 已保持薄入口。
- 首页、持仓、量化、信号、设置底部导航已接好。
- 持仓详情 K 线已拆到 `widgets/chart/`，支持竖屏、横屏、缩放、点选、VOL 副图。
- 量化页已接后端策略、回测、历史回测、参数快照、买卖点 K 线。
- 信号页已支持：
  - 分类入口。
  - 分类详情筛选股票、策略、信号类型。
  - 信号扫描按钮。
  - 信号设置入口。
  - 策略监控入口。
  - 推送记录入口。
- 策略监控前端已支持：
  - 选择持仓股票。
  - 选择后端策略。
  - 按策略渲染参数。
  - 设置周期、扫描间隔、冷却时间、启用、推送候选。
  - 查看、开关和删除已有监控。
  - 查看 scheduler 状态、启动、停止和应用配置。
- 推送记录页已支持查看：
  - 信号事件。
  - 设备。
  - provider。
  - 状态。
  - 尝试次数。
  - 发送时间。
  - 错误信息。

## 4. 当前刚完成的前端验证

最近一次前端功能提交后已运行：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

结果：

```text
Flutter analyze: No issues found
Flutter test: 27 passed
```

最近一次真机安装：

```powershell
cd C:\Users\58229\Desktop\stock_web
.\scripts\build_mobile_lan_debug.ps1
D:\Android\Sdk\platform-tools\adb.exe install -r mobile_app\build\app\outputs\flutter-apk\app-debug.apk
```

安装结果：

```text
Success
```

本次 APK 使用局域网地址：

```text
http://192.168.1.4:8000
```

注意：这个 IP 只是当时网络下的示例。电脑换 Wi-Fi、热点、路由器或网卡后必须重新构建安装 APK，并在 App 设置页核对后端 API 地址。

## 5. 下一位开发者马上要做

先做真机联调，不要马上继续大改页面。

按顺序验证：

1. 打开 App，确认首页、持仓、信号页能正常连接后端。
2. 进入信号页，确认三个入口可打开：
   - 信号设置。
   - 策略监控。
   - 推送记录。
3. 进入策略监控，选择一只持仓股票，创建一个监控：
   - 策略先选 `price_break_ma` 或 `ma_cross`。
   - 周期先用 `日K`。
   - 扫描间隔先用 `15`。
   - 冷却时间先用 `120`。
   - 启用打开。
   - 推送打开。
4. 在策略监控页顶部启动 scheduler。
5. 等待或手动触发扫描后检查：
   - 信号页是否出现对应策略信号。
   - 推送记录页是否出现 `sent`、`failed` 或 `skipped` 记录。

这一条链路必须先确认：

```text
持仓股票
-> 策略监控
-> scheduler 扫描
-> signal_events
-> push_records
-> App 展示
```

验证通过后，再进入持仓详情页和券商式持仓表改造。

## 6. 下一个开发主题：持仓详情页和持仓记录页

完成上面的策略监控链路验证后，建议开始：

```text
券商式持仓页
-> 持仓详情页收益和历史增强
-> 单股策略监控和历史信号整合
```

### 持仓页目标

- 第一列固定股票名称、代码、市场、币种。
- 右侧指标列横向滑动。
- 初始展示：可卖/持有、现价/成本、今日盈亏。
- 右滑展示：持仓盈亏、持仓盈亏率、市值、持仓占比、可用数量、累计收益。
- 支持市场切换：港股、美股、沪深股。
- 支持持仓、订单、历史切换。
- 支持按市值、今日盈亏、持仓盈亏、持仓占比排序。

### 持仓详情页目标

- 展示当前持仓收益。
- 展示单股收益曲线。
- 展示建仓、加仓、减仓、清仓历史。
- 展示该股票已绑定策略监控。
- 展示该股票历史信号。
- 展示该股票相关推送记录。

### 关键约束

- 不要把 K 线 painter、指标计算、横屏逻辑写回 `position_detail_screen.dart`。
- 持仓交易历史和收益快照走后端接口，不在 Flutter 页面里自己拼复杂数据。
- 加仓、减仓、清仓必须写入交易记录。
- 清仓或删除当前持仓时，不应删除历史交易、收益曲线、历史信号和推送记录。

## 7. 关键文件索引

### 策略监控前端

```text
mobile_app/lib/models/strategy_monitor.dart
mobile_app/lib/services/strategy_monitor_api_service.dart
mobile_app/lib/repositories/strategy_monitor_repository.dart
mobile_app/lib/screens/strategy_monitor_screen.dart
mobile_app/test/strategy_monitor_api_service_test.dart
```

### 推送记录前端

```text
mobile_app/lib/models/notification_models.dart
mobile_app/lib/services/notification_api_service.dart
mobile_app/lib/repositories/notification_repository.dart
mobile_app/lib/screens/push_records_screen.dart
mobile_app/test/notification_api_service_test.dart
```

### 信号页入口

```text
mobile_app/lib/screens/signals_screen.dart
mobile_app/lib/widgets/signal/
```

### 持仓生命周期后端

```text
backend/app/routers/positions.py
backend/app/repositories/position_trades.py
backend/app/repositories/position_snapshots.py
backend/app/schemas/positions.py
```

### 策略监控后端

```text
backend/app/routers/strategies.py
backend/app/repositories/strategy_monitors.py
backend/app/services/strategy_monitor_scanner.py
backend/app/services/strategy_monitor_scheduler.py
backend/app/strategies/
```

### 推送后端

```text
backend/app/routers/notifications.py
backend/app/repositories/notifications.py
backend/app/services/push_service.py
backend/app/services/push_providers/
backend/app/schemas/notifications.py
```

## 8. 每次开发必须运行

Flutter 改动：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

后端改动：

```powershell
cd C:\Users\58229\Desktop\stock_web\backend
.\.venv\Scripts\python.exe -m compileall app scripts tests
.\.venv\Scripts\python.exe -m pytest
```

真机体验改动：

```powershell
cd C:\Users\58229\Desktop\stock_web
.\scripts\build_mobile_lan_debug.ps1
D:\Android\Sdk\platform-tools\adb.exe install -r mobile_app\build\app\outputs\flutter-apk\app-debug.apk
```

文档改动：

```powershell
cd C:\Users\58229\Desktop\stock_web
rg -n "\x{FFFD}" docs mobile_app\docs
```

## 9. 不要做的事

- 不要让 Flutter 直接连接 FutuOpenD、JQData 或数据库。
- 不要把回测、策略判断、推送扫描写进 Flutter 页面。
- 不要把 SQL 写回 `backend/app/database.py`。
- 不要把 K 线绘制写回 `position_detail_screen.dart`。
- 不要把完整持仓、成本、资金、策略参数放进远程推送 payload。
- 不要把推送文案写成投资建议。
- 不要基于终端里看到的乱码继续写中文文案。
- 不要裸跑 `flutter build apk --debug` 给真机联调，必须带局域网 `API_BASE_URL` 或使用 `scripts/build_mobile_lan_debug.ps1`。

