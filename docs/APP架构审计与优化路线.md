# App 架构审计与优化路线

## 0. 2026-07-09 架构审计结论

当前代码整体仍可继续迭代，但新增了一个后备功能风险点：本地已经接入 `portfolio_strategy`，相关 router、schema、service、test 仍是未跟踪文件。该功能已决定暂作为后备保留，当前不进入主线开发。

当前验证状态：

```text
Backend pytest: 155 passed
Flutter analyze: No issues found
Flutter test: 71 passed
```

当前架构风险：

1. 本地 HEAD、文档记录的云端部署基线、服务器真实部署基线可能不同，部署前必须分别确认。
2. `portfolio_strategy` 只在后端形成接口和测试，当前作为后备雏形，不推进移动端入口和部署。
3. `backend/app/services/personalized_strategies.py`、`mobile_app/lib/screens/quant_screen.dart`、`mobile_app/lib/widgets/quant/quant_personalized_strategy_panel.dart` 仍是后续体量治理重点。
4. `backend/app/db/seed.py` 的 `KNOWN_STOCK_NAMES` 仍残留 `????`，属于已知编码/历史数据修复风险。
5. 通用回测引擎目前按信号 K 线收盘附近成交；专属策略研究文档要求 T 日收盘信号、T+1 开盘成交。比较结果前必须先统一口径。

短期优化顺序：

1. 先整理 dirty worktree 和未跟踪产物。
2. 将组合建议接口保持为后备，不继续产品化。
3. 继续专属策略研究重测、模板校准和配置治理。

## 0. 2026-06-06 架构审计结论

当前代码结构整体可继续开发，没有必要在交接节点做大规模重构。真正需要控制的风险是：

1. 个股专属策略数量增多后，模板参数、回测文档和测试容易不同步。
2. 策略研究容易过拟合，必须明确训练区间和验证区间，不能只看全周期最优。
3. 后端 Futu、云端 PostgreSQL、App API 地址三者边界必须保持清楚，不能把本地环境误当生产。
4. 中文文档和中文 UI 字符串必须继续按 UTF-8 处理，避免再次出现乱码。

建议后续优化路线：

- 短期不重构主框架，只补强专属策略模板的配置化和测试。
- 中期可以把 `services/personalized_strategies.py` 中的模板配置拆成独立配置文件或数据表，但必须先建立测试保护。
- 长期再考虑 AI/大模型辅助筛选因子，但大模型只能负责生成候选和解释，真实回测必须由后端确定性代码完成。

最后更新：2026-05-26

当前 Git 基线：

```text
a92a987 fix: make kline query postgres compatible
```

本文档记录项目代码和 docs 的结构扫描结论，用于后续一步步优化项目框架结构。后续新增功能前，应先阅读：

1. `docs/APP开发强约束规范.md`
2. `docs/APP新开发者接手指南.md`
3. `docs/APP下一位开发者交接清单.md`
4. `docs/APP项目结构说明.md`
5. `docs/APP马上解决任务顺序.md`
6. `docs/APP服务器部署与Futu交接说明.md`
7. `docs/APP架构审计与优化路线.md`

## 0. 2026-05-26 云端架构新增结论

当前项目云端形态继续推进：

- App 当前仍连接 `http://119.91.47.141`。
- 域名 `devinstock.cloud`、`www.devinstock.cloud` 已解析到云服务器，服务器侧 HTTPS 已配置；App 切域名前要完成真机 HTTPS 验证。
- 云端 PostgreSQL 是事实数据源，本地旧库只作开发/备份参考。
- FutuOpenD 已在云服务器本机运行，并必须只监听本机/内网地址。
- 最新云端量化回测 500 修复点是 PostgreSQL SQL 兼容性：K 线查询中的子查询必须带别名。

新增架构风险：

1. HTTPS 服务器侧可用不等于 App 真机链路可用，还要验证证书链、Android 网络安全配置和 token 注入。
2. 数据库层改动必须在 PostgreSQL 上验证，不能只按 SQLite 习惯写 SQL。
3. 量化历史详情依赖 K 线缓存查询，任何 K 线 repository 改动都要回归回测历史详情和买卖点图。
4. 基金业绩走势和我的收益是两套曲线，不能在架构上混用同一份现金流计算。

## 0. 2026-05-25 云端架构新增结论

当前项目已经从纯局域网调试进入云服务器部署阶段：

- App -> 腾讯云公网 API -> Nginx -> FastAPI -> PostgreSQL。
- 场外基金 provider 独立于 Futu，可以在云端继续工作。
- FutuOpenD 仍是股票行情链路的外部依赖。2026-05-25 已在云服务器本机部署 `futu-opend`，只监听 `127.0.0.1:11111` 和 `127.0.0.1:22222`，公网 `/api/v1/futu/health` 已验证 `status=ok`、`program_status_type=READY`。若该服务停止，股票实时行情、K 线刷新、股票搜索、资金流向和依赖新行情的策略扫描会不可用。
- 后端已支持通过 `FUTU_HOST`、`FUTU_PORT`、`FUTU_CONNECT_TIMEOUT_SECONDS` 配置 FutuOpenD 地址。

新增架构风险：

1. 公网 API 已启用 `API_ACCESS_TOKEN` 简单 token 保护，但还不是完整登录态；后续要补账号体系、限流和更细权限。
2. 服务器侧 HTTPS 已配置，但 App 暂未切换；切换前必须完成真机验证。
3. FutuOpenD 不应直接暴露公网，若放在家用电脑，应通过 Tailscale/WireGuard/SSH 隧道让云服务器访问。
4. 数据库密码曾在调试聊天中出现，生产使用前建议轮换。

详细部署交接见 `docs/APP服务器部署与Futu交接说明.md`。

## 1. 本次验证状态

2026-05-24 当前状态：股票持仓详情、交易历史、单股收益曲线、策略监控、历史信号、推送记录、多因子和组合因子已形成完整闭环；场外基金管理已新增搜索添加、估算/正式净值、基金交易、阈值提醒、多个提醒时间 scheduler、基金详情页 50 日净值趋势和买卖点标记。下一步先真机检查基金主页面和基金详情页，再验证基金提醒 scheduler 到点扫描、写入 `signal_events` 和后续推送候选。

最近相关验证：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

结果：

- Flutter analyze 通过，无静态问题。
- Flutter test 56 passed。
- `fund_api_service_test` 7 passed。
- 后端 pytest 88 passed。
- 云端 debug APK 已打包并安装成功，历史局域网包只作旧调试记录。
- 当前工作区在文档更新前干净。

已知警告：

- `backend/app/main.py` 已从 `@app.on_event` 迁移到 lifespan，原 FastAPI 过期警告已处理。
- 基金模块引入第三方基金数据源，后续若出现刷新慢，应优先做缓存 TTL、重试、超时和降级提示，而不是把等待时间堆到 Flutter 页面。

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

7. 基金数据源与 scheduler
   - 基金 provider 依赖第三方基金接口，稳定性和速度不应按 Futu 同等假设。
   - `fund_alert_scheduler.py` 当前是轻量后端任务，适合本地和单实例使用；生产化前应迁移到独立 worker 或持久化调度。
   - 基金提醒已经写入 `signal_events`，但后续仍需验证推送记录页和信号页对 `source_category=fund` 的展示是否足够清晰。

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
   - 当前承担信号列表、分类入口、信号设置入口、策略监控入口、推送记录入口。
   - 后续信号中心继续扩展时，应移动到 `widgets/signal/` 和独立 screen。

5. `mobile_app/lib/screens/strategy_monitor_screen.dart`
   - 第一版策略监控入口已经可用，但创建表单、scheduler 面板和监控列表都在同一文件。
   - 如果继续增加“从回测保存为监控”“按股票筛选监控”“监控详情页”，应拆到 `widgets/strategy_monitor/` 或独立子页面。

6. `mobile_app/lib/screens/funds_screen.dart`
   - 基金主页第一版已经可用，但账户汇总、列表、添加基金、交易弹窗、提醒设置、scheduler 面板都集中在一个页面。
   - 后续若继续打磨养基宝式布局，应优先拆 `widgets/fund/`，不要在 screen 内继续堆 UI 子树。

7. `mobile_app/lib/screens/fund_detail_screen.dart`
   - 基金详情页已有净值趋势、收益和提醒策略页签。
   - 后续增加关联板块、持仓行业、业绩比较基准或弹幕式走势时，应拆独立图表和信息组件。

8. `mobile_app/lib/screens/push_records_screen.dart`
   - 当前是全局推送记录列表。
   - 后续如果要从某条信号进入推送详情，应支持按 `signal_event_id` 过滤。

9. `mobile_app/lib/sheets/add_position_sheet.dart`
   - 添加持仓弹窗仍然偏大。
   - 股票搜索、行情只读卡片、输入控件可继续拆分。

10. `mobile_app/lib_backup/`
   - 仍保留两份旧 `main.dart` 大备份。
   - 不参与编译，但会干扰接手者理解，后续应归档说明或移出 app 源码目录。

## 3. docs 现状结论

docs 当前入口已经校准到 2026-05-24 的基金模块基线。后续维护重点不是补更多历史，而是保持顶部交接快照准确。

当前要求：

1. `docs/README.md`
   - 只保留当前阅读顺序和最新功能基线。
   - 不再引用不存在的旧入口文档。

2. `docs/APP新开发者接手指南.md`
   - 作为真正接手入口。
   - 顶部“最新交接快照”必须优先于后面历史章节。

3. `docs/APP马上解决任务顺序.md`
   - 顶部 2026-05-26 当前马上任务是短期权威入口。
   - 旧日期章节只作为历史背景。

4. `docs/APP项目结构说明.md`
   - 必须随新增领域模块更新 model、service、repository、screen、router、schema、repository/service 边界。
   - 基金模块已经记录，后续如果继续拆 `widgets/fund/` 也要同步。

5. `docs/APP后续开发方案.md`
   - 保留长期路线，但每次功能完成后要把当前优先级前置。
   - 不要让旧“下一步”压过最新交接快照。

## 4. 后续优化路线

### 阶段 0：文档校准

状态：已完成 2026-05-24 基线校准，后续每次重要功能完成后继续维护。

目标：让后续接手者能一眼判断当前状态、下一步和禁止事项。

任务：

1. 持续更新 `docs/README.md` 的当前真实阅读顺序和最新基线。
2. 持续更新 `docs/APP马上解决任务顺序.md` 顶部当前任务。
3. 持续更新 `docs/APP项目结构说明.md` 中新增模块文件。
4. 保留旧历史记录，但必须在顶部说明“以当前马上任务为准”。

验收：

- 新接手者不需要猜哪个文档最新。
- 不把局域网 IP 当作固定可用后端地址。
- 不引用当前不存在的主入口文档作为首读文档。

### 阶段 1：信号模型和 UI 解耦

当前基金模块优先级高于本阶段。若新开发者接手后时间有限，先完成基金真机验收、基金数据源稳定和基金提醒推送闭环，再回到信号模型解耦。

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

当前马上不继续做结构拆分，先启用并验证现有定时扫描闭环：

```text
持仓股票
-> 策略监控
-> scheduler 扫描
-> signal_events
-> push_records
-> App 展示
```

验证通过后，进入可观测性和真实推送：

```text
扫描日志与原因说明
-> 真实推送通道接入
-> 策略监控总览
-> 信号处置流
-> 交易记录增强
```

持仓详情改造时优先使用已有后端：

```text
position_trades
position_snapshots
strategy_monitors
signal_events
push_records
```

不要在 Flutter 页面里重新计算复杂历史口径。

完成后必须运行：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```
