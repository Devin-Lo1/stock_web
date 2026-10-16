# App 新开发者接手指南

## 0. 2026-07-09 当前接手快照

当前本地仓库已完成一轮代码、文档和测试核对。本节优先于后续历史交接段落。

当前本地代码基线：

```text
fbc5ad1 fix: reprice fund trades when confirmed nav arrives
```

当前验证结果：

```text
Backend pytest: 155 passed
Flutter analyze: No issues found
Flutter test: 71 passed
```

当前必须先处理的接手事项：

1. 先运行 `git status --short --branch`，确认当前工作区仍有未提交修改和未跟踪文件。
2. `backend/app/routers/portfolio_strategy.py`、`backend/app/schemas/portfolio_strategy.py`、`backend/app/services/us_portfolio_strategy.py`、`backend/tests/test_us_portfolio_strategy.py` 已决定暂作为后备功能保留；当前不要继续做移动端入口或部署推进。
3. 确认 `scripts/research_*_tmp.*` 研究脚本和结果哪些需要保留用于策略研究追溯，哪些只是临时产物。
4. 不要把本地 HEAD 直接等同云端部署基线；云端仍需单独登录服务器确认 `git rev-parse --short HEAD`。

当前后端入口 `backend/app/main.py` 已挂载：

```text
health, positions, quotes, klines, notifications, signals, stocks, futu,
strategies, backtests, personalized_strategies, portfolio_strategy, funds
```

其中 `portfolio_strategy` 是本地新增的美股组合建议接口：`GET /api/v1/portfolio-strategy/us?cash=...`。它根据现有美股持仓和手工输入现金计算组合权重、风险指标和人工确认建议；当前作为后备雏形，不接移动端完整入口。

下一步开发顺序：

1. 先把文档、未跟踪代码和研究临时产物整理成可接手基线。
2. 将组合建议功能保持为后备，不继续完善；后续用户重新启用时再补齐移动端入口和部署验证。
3. 继续 `docs/us_stock_strategy_research_20260602.md` 所述的专属策略重测和模板校准。

## 0. 2026-06-06 最新交接快照

当前项目已经完成后端、移动端和文档的交接前全量梳理。代码层面重点如下：

- 后端入口是 `backend/app/main.py`，FastAPI 挂载 `health`、`positions`、`quotes`、`klines`、`notifications`、`signals`、`stocks`、`futu`、`strategies`、`backtests`、`personalized_strategies`、`funds` 等路由。
- 后端结构是 router 编排请求、service 放业务、repository/db 负责持久化，schema 统一前后端 JSON 合约。
- 移动端入口是 `mobile_app/lib/main.dart` 和 `mobile_app/lib/screens/app_shell.dart`。`AppShell` 组装各 repository/service，再分发到首页、持仓、量化、信号、设置、基金等页面。
- 量化页已经拆成五个入口：个股专属策略、策略及参数设置、历史回测、批量回测、价值区回归。
- 个股专属策略在后端 `backend/app/services/personalized_strategies.py` 维护模板和扫描逻辑，在移动端 `mobile_app/lib/widgets/quant/quant_personalized_strategy_panel.dart` 展示稳健/进取双模板、筛选和集体扫描。
- 当前已部署代码基线是 `82527d6 feat: update qqq personalized strategies`。若本交接文档后续另有提交，以新的提交为文档基线。

下一位开发者接手后第一件事不是改 App，而是重测并校准当前 App 已有个股专属策略。参考 `docs/us_stock_strategy_research_20260602.md` 的现有模板记录和回测口径，先做研究输出，再由用户决定是否写入 App。

最后更新：2026-05-26

当前代码功能基线：

```text
a92a987 fix: make kline query postgres compatible
```

本文档给新开发者使用。目标是：读完 `docs/` 后能知道当前项目做到哪、不能做什么、下一步从哪里开始。

## 0. 2026-05-26 最新交接快照

当前最新事实：

- App 当前仍使用云服务器公网 IP：`http://119.91.47.141`。
- 域名 `devinstock.cloud`、`www.devinstock.cloud` 已解析到 `119.91.47.141`，服务器侧 HTTPS 已配置；App 暂不切域名，等真机 HTTPS 验证通过后再改 `API_BASE_URL`。
- 云端 PostgreSQL 是当前事实数据源；不要再把本地旧库当主库。
- FutuOpenD 已在云服务器本机运行，`11111` API 端口和 `22222` telnet 运维口必须只允许本机/内网访问，禁止暴露公网。
- `/api/v1/*` 已启用 `API_ACCESS_TOKEN` 简单保护；`/`、`/health` 公开。
- 最新云端量化回测 500 已修复：根因是 PostgreSQL 要求 K 线查询里的子查询必须有别名，修复提交为 `a92a987`。
- 基金模块最近连续修复了交易记录、持仓修正日期、业绩走势/我的收益分离、估算收益“估”标识、下一次策略参考净值/日期显示。用户已明确基金历史以新建导入记录为准，旧历史不要恢复。

下一位开发者优先做：

1. 复测云端量化回测和回测历史详情，确认买卖操作与买卖 K 线图可显示。
2. 复测基金交易记录、持仓修正、策略参考净值/日期、估算收益“估”标识。
3. 完成域名 HTTPS 真机验证，稳定后再切 App API 地址。
4. 如果要增强 ATR “仅止损”，新增明确的“初始持仓止损”模式，不要改变旧策略默认语义。

## 0. 2026-05-25 云服务器与 Futu 交接增量

新增必读文档：

```text
docs/APP服务器部署与Futu交接说明.md
```

最近项目发生了部署形态变化：App 已从局域网后端切到腾讯云轻量服务器公网后端，当前公网 API 为 `http://119.91.47.141`，服务器路径为 `/home/ubuntu/stock_web`，后端由 Nginx 反代到 FastAPI，数据库为服务器本机 PostgreSQL。

2026-05-25 已在云服务器本机部署并登录命令行 FutuOpenD，服务名为 `futu-opend`，只监听 `127.0.0.1:11111` 和本机运维口 `127.0.0.1:22222`。后端通过 `FUTU_HOST=127.0.0.1`、`FUTU_PORT=11111` 访问 FutuOpenD；公网 `/api/v1/futu/health` 已验证返回 `status=ok`、`program_status_type=READY`。若后续 App 再次显示 Futu 不可用，优先检查 `futu-opend` 是否运行、富途账号是否仍登录、以及 `11111` 是否仍只在本机监听。

2026-05-25 18:31 已以本地 PostgreSQL 为准完成本地到云服务器迁移。迁移后云端 `stock_web` 已包含本地基金、回测、通知和策略监控数据；迁移前云端旧库保留为 `stock_web_before_migration_20260525_183135`。

下一位开发者优先做：

1. 按 `docs/APP服务器部署与Futu交接说明.md` 检查服务器 systemd、Nginx、PostgreSQL、备份和防火墙。
2. 确认 `futu-opend`、`stock-web-backend`、`nginx`、`postgresql` 均为 active。
3. 继续保持 FutuOpenD 的 `11111` 和 `22222` 只监听 `127.0.0.1`，禁止暴露公网。
4. 公网 API 已启用 `API_ACCESS_TOKEN` 简单访问保护；域名和服务器侧 HTTPS 已初配，后续继续补真机 HTTPS 验证、登录态和限流。

注意：本文后面保留了局域网真机调试历史说明；现在若面向云服务器真机包，必须用 `API_BASE_URL=http://119.91.47.141` 并注入 `API_ACCESS_TOKEN` 重新构建 APK。

## 0. 最新交接快照

当前最新完成内容：

- 持仓详情页已完成顶部行情信息、K 线/收益左右切换、资金流向卡片、交易历史、单股监控与信号整合；删除类操作已有确认提示。
- 量化页已新增 5 个常用策略因子和组合因子，历史回测筛选区域改为固定高度滚动显示，避免列表撑爆页面。
- 策略监控已支持港股/美股候选、组合因子参数选择、监控卡片回看编辑、扫描日志最多保留最新 10 条并滚动展示。
- 设置页新增 `数据说明`，说明行情、收益、资金流、策略回测、推送和使用注意。
- 设置 -> 手机推送新增 `真实推送通道` 状态卡，后端提供 Huawei Push Kit / FCM 配置诊断接口，能显示缺失环境变量和校验模式。
- 策略监控 scheduler 状态已增强：显示启用监控数、待扫描数、下次运行时间；若有启用监控但 scheduler 未启动，会直接提示启动。
- 场外基金管理已完成第一版可用闭环：搜索添加基金、基金持仓汇总、估算净值/正式净值切换、当日收益、持有收益、基金交易记录、当前持仓修正、基金详情页业绩走势、沪深300对比、成本价均线、区间切换、净值列表和买卖点标记。新增“修改持仓 -> 修正当前持仓”，可按其他平台显示的持有金额和持有收益反推份额与成本净值，并可指定上次操作时间；后端用修正记录替换旧的错误导入交易，策略提醒基准按修正记录的确认净值/时间计算。基金详情业绩走势展示基金自身长期净值收益，不是用户买入后的持仓收益；长期净值优先来自天天基金 `pingzhongdata` 的 `Data_netWorthTrend`，并合并最新净值表。业绩走势按所选区间固定横轴窗口；当持仓均价明显脱离当前净值区间时，图表成本线会优先按区间内交易记录推导，避免异常或未进入净值区间的交易压扁曲线。沪深300基准优先使用 Eastmoney，云服务器访问失败时回退到本机 FutuOpenD 的 `SH.000300` 日K。基金加仓/减仓现金流不得被当成收益，后端已有回归测试覆盖当前净值加减仓时总收益不被现金流扭曲。
- 基金阈值提醒已支持用户自定义涨跌阈值、买入金额、卖出比例和多个提醒时间；后端基金提醒 scheduler 到点自动刷新、判断策略并写入信号事件。
- 基金主页已新增策略提醒状态、扫描结果时间、触发数量、下次扫描时间和手动扫描入口；场外基金数据源使用独立基金 provider，不依赖 Futu 行情接口。

最近一次完整验证：

```text
Backend compileall: Success
Backend pytest: 101 passed
Flutter analyze: No issues found
Flutter test: 60 passed
Flutter fund_api_service_test: 10 passed
LAN debug APK build: Success
debug APK install: Success
```

历史记录：当时真机 APK 使用局域网后端。当前交接以云服务器包为准，不再使用这个地址作为默认值。

```text
http://192.168.1.4:8000
```

下一位开发者优先做：

1. 真机检查基金主页面、基金详情页、添加场外基金、交易记录、阈值提醒设置、多个提醒时间设置和手动扫描。
2. 启动后端并观察基金提醒 scheduler：确认到点扫描会刷新基金数据、写入 `signal_events`，App 基金页能显示最近扫描时间和触发数量。
3. 核对基金估算净值和正式净值口径：盘中优先用估算涨跌辅助判断，正式净值更新后以正式净值和正式日涨跌为准。
4. 若要启用真实华为推送，在后端配置：
   - `HUAWEI_PUSH_APP_ID`
   - `HUAWEI_PUSH_CLIENT_ID`
   - `HUAWEI_PUSH_CLIENT_SECRET`
   - 可选 `HUAWEI_PUSH_VALIDATE_ONLY=true`
5. 后续按顺序做：基金真机 UI 微调 -> 基金数据源缓存/降级 -> 基金提醒推送联调 -> 基金交易编辑/删除 -> 组合资产总览。

注意：本文顶部“最新交接快照”优先于后面历史章节。后面章节保留开发脉络，但若出现“下一步”冲突，以本节为准。

## 1. 必读顺序

新开发者开始写代码前，按下面顺序阅读：

1. `docs/APP开发强约束规范.md`
2. `docs/APP新开发者接手指南.md`
3. `docs/APP下一位开发者交接清单.md`
4. `docs/APP项目结构说明.md`
5. `docs/APP马上解决任务顺序.md`
6. `docs/APP架构审计与优化路线.md`
7. `docs/APP后续开发方案.md`
8. `docs/APP总体开发规划.md`

如果这些文档出现冲突，优先级为：

```text
APP开发强约束规范
-> APP新开发者接手指南
-> APP下一位开发者交接清单
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
  - 持仓交易历史接口。
  - 单只持仓收益快照历史接口。
- 场外基金后端已完成：
  - `fund_positions`、`fund_trades`、`fund_navs`、`fund_alert_scheduler` 表。
  - 基金搜索、基金净值、基金持仓、基金交易、基金阈值提醒和基金提醒调度接口。
  - 独立基金数据源 provider，当前用于场外基金估算净值和正式净值，不依赖 Futu。
  - 基金提醒 scanner 会把触发结果写入 `signal_events`，后续推送只消费已落库事件。
  - FastAPI lifespan 会启动/停止基金提醒 scheduler。

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
- 持仓列表已改为券商式横向表格：
  - 左侧固定股票名称、代码、市场标签。
  - 右侧横向滑动查看可卖/持有、现价/成本、今日盈亏、持仓盈亏、市值和持仓占比。
  - 核心收益指标以后端快照为权威来源。
- 持仓详情页已接入：
  - 后端持仓收益快照。
  - 单股收益曲线。
  - 建仓、加仓、减仓、清仓交易历史。
  - 加仓、减仓、清仓记录入口。
- 基金模块已接入：
  - `fund_models.dart`、`fund_api_service.dart`、`fund_repository.dart`。
  - `funds_screen.dart`：基金主页面、账户汇总、基金列表、添加基金、交易记录、阈值提醒、scheduler 状态和手动扫描。
  - `fund_detail_screen.dart`：基金详情页、业绩走势、沪深300对比、成本价均线、区间横轴窗口、近 30/50 条净值列表、买卖点标记、收益和策略信息。
  - 盘中估算涨跌可用于收盘前操作提醒；正式净值更新后自动以正式净值路径展示。

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
Flutter test: 56 passed
Flutter fund_api_service_test: 7 passed
Backend pytest: 88 passed
```

最近一次真机安装：

```powershell
cd C:\Users\58229\Desktop\stock_web
.\scripts\build_mobile_lan_debug.ps1 -ApiBaseUrl http://192.168.1.4:8000
D:\Android\Sdk\platform-tools\adb.exe install -r -d mobile_app\build\app\outputs\flutter-apk\app-debug.apk
```

安装结果：

```text
Success
```

历史记录：本次 APK 当时使用局域网地址：

```text
http://192.168.1.4:8000
```

注意：这个 IP 只是历史局域网调试示例。当前云端调试包应使用 `http://119.91.47.141` 并注入 API token。

## 5. 下一位开发者马上要做

先做真机检查和小修，不要马上继续大改页面。2026-05-24 起，第一优先级是基金模块真机验收；下面股票/策略监控链路已基本跑通，作为回归检查保留。

按顺序验证：

1. 打开 App，确认首页、持仓、基金、信号页能正常连接后端。
2. 进入基金入口，检查基金主页：
   - 账户资产、当日收益、持有收益是否紧凑显示。
   - 基金列表是否显示前台估算/正式净值口径。
   - 策略提醒卡是否能显示最近扫描时间、触发数量和下次扫描。
   - 多个提醒时间设置是否可保存。
   - 手动扫描是否会更新扫描结果。
3. 点击一只基金进入详情页：
   - 顶部是否保持深色风格，不再出现蓝色头部。
   - 净值趋势是否加载最近 50 天。
   - 买入/卖出点位是否标在趋势图上。
   - 收益和提醒策略页签是否可切换。
4. 进入持仓页，点击任意股票持仓，检查详情页：
   - 后端收益指标是否有值。
   - 单股收益曲线是否显示；快照不足时是否显示“收益快照不足”。
   - 交易历史是否显示建仓、加仓、减仓、清仓记录。
   - 加仓、减仓、清仓弹窗是否能打开。
   - 提交交易后列表和详情页是否刷新。
5. 若基金或持仓详情页存在 UI 截断、数据未刷新或后端错误，先修这些问题。
6. 进入信号页，确认三个入口可打开：
   - 信号设置。
   - 策略监控。
   - 推送记录。
7. 进入策略监控，选择一只持仓股票，创建一个监控：
   - 策略先选 `price_break_ma` 或 `ma_cross`。
   - 周期先用 `日K`。
   - 扫描间隔先用 `15`。
   - 冷却时间先用 `120`。
   - 启用打开。
   - 推送打开。
8. 在策略监控页顶部启动 scheduler。
9. 等待或手动触发扫描后检查：
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

验证通过后，再进入单股详情页的策略监控、历史信号和推送记录整合。

## 6. 当前持仓详情页状态和下一个开发主题

当前已经完成：

```text
券商式持仓页
-> 持仓详情页后端收益快照
-> 单股收益曲线
-> 交易历史
-> 加仓/减仓/清仓入口
```

下一步建议开始：

```text
单股策略监控整合
-> 单股历史信号整合
-> 单股推送记录整合
-> 持仓详情页 UI 细节打磨
```

### 持仓页当前状态

- 第一列固定股票名称、代码、市场、币种。
- 右侧指标列横向滑动。
- 初始展示：可卖/持有、现价/成本、今日盈亏。
- 右滑展示：持仓盈亏、市值、持仓占比。
- 支持市场切换：港股、美股、沪深股。
- 订单、历史切换和排序暂未完成。

### 持仓详情页当前状态

- 已展示当前持仓收益，核心收益来自后端快照。
- 已展示单股收益曲线。
- 已展示建仓、加仓、减仓、清仓历史。
- 已提供加仓、减仓、清仓记录入口。
- 待完成：展示该股票已绑定策略监控。
- 待完成：展示该股票历史信号。
- 待完成：展示该股票相关推送记录。

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

### 持仓生命周期前端

```text
mobile_app/lib/models/position_trade.dart
mobile_app/lib/models/position_snapshot.dart
mobile_app/lib/services/position_api_service.dart
mobile_app/lib/repositories/position_repository.dart
mobile_app/lib/screens/position_detail_screen.dart
mobile_app/lib/sheets/position_trade_sheet.dart
mobile_app/lib/widgets/position/position_profit_curve.dart
mobile_app/lib/widgets/position/position_trade_history.dart
mobile_app/test/position_api_service_test.dart
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
$key=Join-Path $env:USERPROFILE '.ssh\id_ed25519_gitee_stock_web'
$token=ssh -i $key -o BatchMode=yes ubuntu@119.91.47.141 'set -a; . /home/ubuntu/stock_web/backend/.env >/dev/null 2>&1; printf %s "$API_ACCESS_TOKEN"'
.\scripts\build_mobile_lan_debug.ps1 -ApiBaseUrl 'http://119.91.47.141' -ApiAccessToken $token
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
- 不要裸跑 `flutter build apk --debug` 给真机联调，必须显式传入当前 API 地址和 `API_ACCESS_TOKEN`。云端包当前使用 `http://119.91.47.141`，域名 HTTPS 验证完成后再切换。
