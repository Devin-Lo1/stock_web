# App 架构审计与优化路线

最后更新：2026-05-20

当前 Git 基线：

```text
b4a17f7 chore: detect LAN API address for debug APK
```

本文档记录 2026-05-20 对项目代码和 docs 的完整扫描结论，用于后续一步步优化项目框架结构。后续新增功能前，应先阅读：

1. `docs/APP开发强约束规范.md`
2. `docs/APP架构审计与优化路线.md`
3. `docs/APP项目结构说明.md`
4. `docs/APP马上解决任务顺序.md`

## 1. 本次验证状态

本次只做审计和验证，未在审计阶段改动代码。

已验证：

```powershell
cd C:\Users\58229\Desktop\stock_web\backend
.\.venv\Scripts\python.exe -m compileall app scripts tests
.\.venv\Scripts\python.exe -m pytest

cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

结果：

- 后端编译通过。
- 后端测试 31 passed。
- Flutter analyze 通过，无静态问题。
- Flutter test 15 passed。
- 当前工作区干净。

已知警告：

- `backend/app/main.py` 使用 `@app.on_event("startup")`，FastAPI 已提示该写法过期，后续应迁移到 lifespan。

## 2. 当前代码结构结论

整体结论：项目主框架可以继续接手开发，后端和 Flutter 已经具备基本分层，但几个中心文件已经开始变大，后续必须按领域逐步拆分。

### 后端现状

当前后端主线是：

```text
routers -> services / repositories -> db / strategies / futu
```

合理点：

- API 已拆到 `backend/app/routers/`。
- 数据库兼容门面保留在 `backend/app/database.py`。
- 具体读写基本放在 `backend/app/repositories/`。
- 策略已拆到 `backend/app/strategies/`。
- 回测引擎已放到 `backend/app/backtest/`。
- 信号事件、设备注册、推送记录已经落库。

主要结构问题：

1. `backend/app/services/futu_client.py`
   - 当前 `SH.`、`SZ.` 没有正确识别为 A 股/CNY。
   - 后续支持 A 股场内 ETF/LOF 前必须先修。

2. `backend/app/services/signal_scanner.py`
   - 扫描策略和参数目前硬编码在 `_scan_configs()`。
   - 后续应迁移为数据库配置或服务端配置模型。

3. `backend/app/db/init.py`
   - 当前同时承担建表、补字段和类迁移职责。
   - 功能继续增加后，应引入版本化迁移方案，避免初始化文件越来越重。

4. `backend/app/repositories/notifications.py`
   - 目前同时处理 `signal_events`、`notification_devices`、`push_records`。
   - 后续信号中心和推送继续扩展时，应按领域拆成多个 repository。

5. `backend/app/db/seed.py`
   - `KNOWN_STOCK_NAMES` 中仍有 `????`，说明历史乱码修复映射本身不可靠。
   - 应作为单独编码修复任务处理。

6. `strategy_parameters`、`strategy_signals`
   - 表已经存在，但当前主线更多使用 `strategy_definitions`、`backtest_runs`、`signal_events`。
   - 后续要么正式接入，要么标注为预留/遗留，避免开发者误用。

### Flutter 现状

当前 Flutter 主线是：

```text
models -> services -> repositories -> screens -> widgets
```

合理点：

- `main.dart` 已保持薄入口。
- API 调用集中在 `services/`。
- 本地/远程协调集中在 `repositories/`。
- K 线和量化结果组件已经拆到 `widgets/chart/`、`widgets/backtest/`、`widgets/quant/`。
- 信号页已完成分类入口。

主要结构问题：

1. `mobile_app/lib/screens/app_shell.dart`
   - 同时管理持仓、行情、信号、通知、底部导航和后端状态。
   - 后续应拆出 positions controller、signals controller、notifications controller。

2. `mobile_app/lib/screens/quant_screen.dart`
   - 同时包含策略加载、历史回测、股票搜索、参数校验、回测执行和结果定位。
   - 后续应拆出量化状态控制器和参数构建/校验工具。

3. `mobile_app/lib/models/trade_signal.dart`
   - 当前模型直接依赖 Flutter `Color`、`IconData`。
   - 这会让数据模型和 UI 展示耦合，后续应拆成纯数据模型加 UI 映射。

4. `mobile_app/lib/screens/signals_screen.dart`
   - 第一版分类页可用，但分类详情页和分类卡片都在同一文件。
   - 后续信号中心继续扩展时，应移动到 `widgets/signal/` 和独立 screen。

5. `mobile_app/lib/sheets/add_position_sheet.dart`
   - 添加持仓弹窗仍然偏大。
   - 股票搜索、行情只读卡片、输入控件可继续拆分。

6. `mobile_app/lib_backup/`
   - 仍保留两份旧 `main.dart` 大备份。
   - 不参与编译，但会干扰接手者理解，后续应归档说明或移出 app 源码目录。

## 3. docs 现状结论

docs 当前最大问题不是内容少，而是历史记录太多、入口失效、多个文档同时写“下一步”。

发现的问题：

1. `docs/README.md`
   - 原本指向的 `项目开发计划与技术方案整合.md`、`项目记忆与交接.md` 等文件当前不存在。
   - 必须改成当前真实文档入口。

2. `docs/APP马上解决任务顺序.md`
   - 当前 Git 基线仍写旧提交 `8b77fa4`。
   - 文中多处“马上下一步”已经是历史记录，需要把当前下一步前置说明清楚。

3. `docs/APP总体开发规划.md`
   - 仍存在固定局域网 IP `192.168.1.4`。
   - 应改成“电脑当前局域网 IP”，默认使用 `scripts/build_mobile_lan_debug.ps1` 自动探测。

4. `docs/APP项目结构说明.md`
   - 部分文件名已过期，例如 `signal_scan_service.py`，实际为 `signal_scanner.py`。
   - 部分规划文件如 `strategy_api_service.dart`、`strategy_lab_screen.dart` 当前不存在。

5. `docs/APP后续开发方案.md`
   - 内容很完整，但偏历史流水账。
   - 后续应保留背景记录，把当前优先级汇总到本文件和 `APP马上解决任务顺序.md`。

## 4. 后续优化路线

### 阶段 0：文档校准

目标：让后续接手者能一眼判断当前状态、下一步和禁止事项。

任务：

1. 更新 `docs/README.md`，改成当前真实阅读顺序。
2. 更新 `docs/APP马上解决任务顺序.md` 的 Git 基线和当前下一步。
3. 更新 `docs/APP总体开发规划.md` 中硬编码局域网 IP。
4. 更新 `docs/APP项目结构说明.md` 中过期文件名和当前结构问题。
5. 保留旧历史记录，但在顶部说明“以本审计路线为当前优先级”。

验收：

- 新接手者不需要猜哪个文档最新。
- 不再把 `192.168.1.4` 当作固定可用后端地址。
- 不再引用当前不存在的主入口文档作为首读文档。

### 阶段 1：信号模型和 UI 解耦

目标：让信号数据模型保持纯数据，信号分类、颜色、图标放到 UI 层。

建议顺序：

1. 新增 `mobile_app/lib/widgets/signal/signal_category.dart`。
2. 把 `SignalCategory` 的标题、图标、颜色等展示逻辑从 `models/trade_signal.dart` 移出。
3. 后续逐步移出 `TradeSignal.color`，由 UI 根据 level 和 signal type 推导。
4. 补充信号模型解析测试。

验收：

- `models/trade_signal.dart` 不再依赖 Flutter `IconData` 等 UI 类型。
- 信号页视觉不变。
- Flutter analyze/test 通过。

### 阶段 2：Futu 市场和币种映射修正

目标：为后续 A 股场内 ETF/LOF 打基础。

建议顺序：

1. 修正 `backend/app/services/futu_client.py`：
   - `US.` -> `US` / `USD`
   - `HK.` -> `HK` / `HKD`
   - `SH.`、`SZ.` -> `SH`、`SZ` / `CNY`
2. `stock_search.py` 复用 Futu host/port 常量，不再重复写死。
3. 补充后端单元测试。

验收：

- `SH.510300`、`SZ.159919` 不再被写成 HK/HKD。
- 后端 compileall/pytest 通过。

### 阶段 3：信号扫描配置化

目标：减少 `signal_scanner.py` 硬编码，为后续启停策略、推送候选、阈值配置做准备。

建议顺序：

1. 定义扫描配置模型。
2. 第一阶段可以先从服务端常量表抽离到单独模块。
3. 第二阶段再接数据库配置。
4. `signal_events` 继续结构化字段，减少重要信息只藏在 payload 中。

2026-05-20 第一阶段进展：

- 已新增 `backend/app/services/signal_scan_config.py`。
- `signal_scanner.py` 不再直接维护默认扫描策略列表，只读取 `list_signal_scan_configs()`。
- 默认扫描配置仍保持原行为：`price_break_ma` MA5/10/20、MA Cross 5/20、RSI 14/30/70、MACD 12/26/9。
- 已补测试证明 MA Cross 可通过替换配置使用短 3、长 7，不需要改扫描主流程。

2026-05-20 第二阶段进展：

- 已新增 `signal_scan_configs` 数据表，并在默认初始化时 seed 默认扫描配置。
- 已新增 `backend/app/repositories/signal_scan_configs.py`，扫描配置读写进入 repository。
- 已新增扫描配置 API：
  - `GET /api/v1/signals/configs`
  - `POST /api/v1/signals/configs`
  - `PUT /api/v1/signals/configs/{config_id}`
  - `POST /api/v1/signals/configs/reset-defaults`
- `signal_scanner.py` 现在优先读取数据库配置；测试库无配置时仍 fallback 到默认配置，保证测试和空库可用。
- 已补测试覆盖默认配置、持久化配置、MA Cross 3/7、自定义配置创建、启停和重置默认配置。
- 下一步前端可以基于这些接口做设置页，不需要再改扫描主流程。

验收：

- 新增策略时不需要改扫描器主体流程。
- App 能按策略、级别、来源筛选。

### 阶段 4：AppShell 拆控制器

2026-05-21 筛选分类进展：

- 后端 `GET /api/v1/signals/events` 已支持 `source_category`、`strategy_code`、`signal_type`、`level`、`push_candidate`、`read_status`、`code`、`limit` 筛选。
- 后端已新增：
  - `PUT /api/v1/signals/events/{event_id}/read`
  - `PUT /api/v1/signals/events/{event_id}/ignore`
- `read_status` 已支持 `unread`、`read`、`ignored`。
- App 信号分类页点击分类后，已可按分类调用后端筛选接口。
- App 分类详情页已支持按股票、策略、信号类型二次筛选。
- App 信号页已新增信号设置入口，可切换扫描配置的 `enabled` 和 `push_candidate`。
- 后端扫描器生成信号时已遵守扫描配置的 `push_candidate`，关闭后仍可落库展示，但不会进入推送候选。
- 当前分类映射：
  - 重要信号：`level=important`
  - 量化策略：`source_category=strategy`
  - 风控提醒：`source_category=risk`
  - 系统通知：`source_category=system`
  - 已忽略：`read_status=ignored`

目标：降低入口状态复杂度。

建议拆分：

- positions controller：持仓加载、刷新、增删改。
- signals controller：后端信号加载、扫描、本地兜底。
- notification controller：本地通知、设备注册、测试通知。

验收：

- `app_shell.dart` 主要负责页面编排和导航。
- 各 controller 可单独测试。

### 阶段 5：QuantScreen 拆控制器和校验工具

目标：量化页继续扩展策略时不会变成单文件瓶颈。

建议拆分：

- 参数构建和校验工具。
- 历史回测列表 controller。
- 股票搜索 controller。
- 回测执行 controller。

验收：

- 新增策略参数时只改参数定义和后端策略，不需要大改页面。
- 回测历史、搜索、执行状态互不干扰。

### 阶段 6：数据库迁移机制

目标：避免 `db/init.py` 继续承担所有 schema 演进。

建议：

1. 短期保留 `_ensure_column`，但新增表/字段必须记录迁移意图。
2. 中期引入轻量 migration 脚本或迁移表。
3. 长期再考虑 Alembic。

验收：

- 表结构演进可追踪。
- 测试库和开发库都能稳定初始化。

## 5. 当前立即执行顺序

本次文档保存后，马上开始阶段 1 的第一步：

```text
信号模型和 UI 解耦
```

第一轮只做低风险拆分：

- 新增信号分类 UI helper。
- 从 `TradeSignal` 模型中移出分类标题、颜色、图标展示逻辑。
- 保持当前信号页视觉和行为不变。

完成后必须运行：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```
