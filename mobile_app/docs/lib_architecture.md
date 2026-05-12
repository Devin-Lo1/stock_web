# mobile_app/lib 架构说明

本文档用于交接 Flutter App 当前 `lib` 目录结构，方便新的 AI 或开发者继续开发。当前 App 已从单文件 `main.dart` 拆分为入口、页面、模型、服务、数据、弹窗、通用组件和工具函数几个层次。后续开发请优先沿用现有模块边界，不要再把大量业务代码塞回 `main.dart`。

## 当前开发状态

App 当前处于静态页面和本地模拟数据阶段，已具备：

- 首页：资产概览、港股/美股切换、持仓追踪、最新信号。
- 持仓页：按市场筛选持仓，支持添加、编辑、删除、进入详情。
- 持仓详情页：展示价格、模拟图表、当日收益、持有收益、成本、昨收，编辑后留在详情页。
- 信号页：展示本地策略信号。
- 设置页：策略阈值设置、显示设置、后端/推送/富途接入占位。
- 我的页：账户信息、会员、消息提醒、显示设置、盈亏分析、策略实盘、反馈、关于我们。
- 日间/夜间模式：日间为白底、黑字、浅蓝卡片；夜间为深色背景。

当前数据仍来自本地 `samplePositions`，信号由本地 `buildSignals` 根据持仓和阈值生成。富途 API、后端 API、持久化、真实 K 线数据尚未接入。

## 顶层结构

```text
lib/
  main.dart
  data/
  models/
  screens/
  services/
  sheets/
  utils/
  widgets/
```

## 入口与全局壳

### `main.dart`

职责：

- Flutter App 入口：`main()`
- 根组件：`StockSignalApp`
- 管理全局显示模式：`DisplayMode.dark` / `DisplayMode.light`
- 创建 `MaterialApp`
- 传入 `AppShell`

注意：

- `main.dart` 现在应保持很薄。
- 不要在这里新增页面 UI 或业务逻辑。
- 如果要新增底部 Tab、全局状态、全局导航，优先改 `screens/app_shell.dart`。

### `screens/app_shell.dart`

职责：

- App 主框架。
- 管理底部导航当前索引：`_selectedIndex`
- 管理当前市场筛选：`MarketFilter.hk` / `MarketFilter.us`
- 管理本地持仓列表：`_positions`
- 管理策略阈值：`_settings`
- 根据当前市场过滤持仓。
- 调用 `buildSignals(visible, _settings)` 生成信号。
- 负责添加、编辑、删除持仓弹窗调度。
- 负责进入账户页。

当前底部导航有 4 个页面：

- 首页：`DashboardScreen`
- 持仓：`PositionsScreen`
- 信号：`SignalsScreen`
- 设置：`SettingsScreen`

后续建议：

- 接入后端或本地存储后，可把 `_positions` 和 `_settings` 迁移到独立状态管理层。
- 接入富途行情后，`AppShell` 不应直接处理 API 细节，应新增 service/repository 层。

## 数据模型

### `models/app_enums.dart`

定义全局枚举：

- `MarketFilter { hk, us }`：港股/美股筛选。
- `DisplayMode { dark, light }`：夜间/日间模式。

后续如加入 A 股、基金、加密货币，可以扩展 `MarketFilter`，但要同步更新市场切换组件和持仓识别逻辑。

### `models/stock_position.dart`

核心持仓模型：`StockPosition`

字段：

- `name`：股票名称。
- `code`：股票代码，例如 `HK.00700`、`US.AAPL`。
- `quantity`：数量。
- `costPrice`：成本价。
- `currentPrice`：现价。
- `previousClose`：昨收。
- `changeRate`：涨跌幅。
- `signal`：当前本地展示信号文案。

计算属性：

- `market`：根据代码前缀判断港股或美股。
- `costValue`：持仓成本。
- `marketValue`：当前市值。
- `profit`：持有收益金额。
- `dailyProfit`：当日收益金额。
- `dailyProfitRate`：当日收益率。
- `profitRate`：持有收益率。
- `price` / `shortPrice` / `change` / `pnl`：展示用格式化字段。

后续富途 API 接入建议：

- 持仓输入字段仍保留 `quantity`、`costPrice`。
- 实时行情字段如 `currentPrice`、`previousClose`、`changeRate` 应由行情服务更新。
- 如果需要区分币种，建议新增 `currency` 字段，而不是只靠代码前缀推断。

### `models/strategy_settings.dart`

策略阈值模型：`StrategySettings`

字段：

- `takeProfitPercent`：止盈观察阈值，默认 `5`。
- `stopLossPercent`：止损观察阈值，默认 `-5`。
- `dailySurgePercent`：上涨异动阈值，默认 `5`。
- `dailyDropPercent`：下跌异动阈值，默认 `-5`。

当前设置页允许用户修改这些值，留空时使用默认值。

### `models/trade_signal.dart`

信号展示模型：`TradeSignal`

字段：

- `type`：信号类型，如止盈观察、止损观察、上涨异动。
- `stock`：股票名称和代码。
- `time`：当前显示为收益率说明。
- `level`：信号等级。
- `color`：展示颜色。

当前只是 UI 展示模型，不包含完整策略计算上下文。

## 本地数据与服务

### `data/sample_positions.dart`

本地样例持仓数据。

当前包含：

- 腾讯控股 `HK.00700`
- 中国平安 `HK.02318`
- 小米集团-W `HK.01810`
- Apple `US.AAPL`

后续接入后端或本地数据库后，这个文件只应作为开发 fallback 或测试数据。

### `services/local_signal_service.dart`

本地信号生成服务：`buildSignals`

输入：

- 当前可见持仓列表。
- 策略阈值 `StrategySettings`。

输出：

- `List<TradeSignal>`

当前规则：

- 持有收益率 >= 止盈阈值：生成止盈观察。
- 持有收益率 <= 止损阈值：生成止损观察。
- 当日收益率 >= 上涨异动阈值：生成上涨异动。
- 当日收益率 <= 下跌异动阈值：生成下跌异动。

后续建议：

- 如果策略规则变多，可拆成 `signal_rules/` 或 `strategy_engine/`。
- 富途实时行情接入后，信号服务应接收更新后的 `StockPosition` 或行情快照。

## 页面模块

### `screens/dashboard_screen.dart`

首页。

职责：

- 顶部账户头像入口。
- 资产概览。
- 港股/美股切换。
- 添加持仓按钮。
- 持仓追踪列表。
- 最新信号列表。
- 点击持仓进入 `PositionDetailScreen`。

内部私有组件：

- `_Header`
- `_AssetOverview`
- `_MetricCard`

注意：

- 首页卡片已经按小卡片样式压缩过，适合后续 20+ 持仓展示。
- 如果要改首页持仓行样式，优先改 `widgets/position/position_tile.dart`，而不是在首页重复写。

### `screens/positions_screen.dart`

持仓页。

职责：

- 展示持仓标题、数量、总盈亏。
- 港股/美股切换。
- 添加持仓按钮。
- 持仓列表。
- 点击持仓进入详情页。

与首页的区别：

- 首页偏概览。
- 持仓页偏完整列表。

后续如果要加入排序、搜索、分组，优先在这里开发。

### `screens/position_detail_screen.dart`

持仓详情页。

职责：

- 展示当前股票名称、代码、价格、涨跌。
- 展示昨收、最高、最低等报价区。
- 展示图表 Tab：分时、五日、日K、周K、月K。
- 当前图表为 `_KLinePreview` 模拟绘制。
- 展示信号标签、数量、现价。
- 展示当日收益、持有收益、成本价、昨收。
- 支持编辑持仓。
- 支持删除持仓。

重要行为：

- 点击详情页编辑持仓后，不返回总持仓页。
- `PositionDetailScreen` 内部维护 `_position`，编辑成功后局部刷新详情页。

后续富途 K 线接入建议：

- 保留页面结构。
- 替换 `_KLinePreview` 的模拟数据来源。
- 可新增行情模型，如 `Candle`、`QuoteSnapshot`、`OrderBookLevel`。
- 新增 `services/futu_quote_service.dart` 或 `repositories/quote_repository.dart` 负责拉取 K 线和实时行情。

### `screens/signals_screen.dart`

信号页。

职责：

- 展示本地策略信号列表。
- 无信号时展示空状态。

后续：

- 可加入信号筛选、已读/未读、推送记录、策略来源。

### `screens/settings_screen.dart`

设置页。

职责：

- 展示页面标题。
- 策略阈值设置面板：`StrategySettingsPanel`
- 显示设置入口。
- 后端 API 状态占位。
- 手机推送状态占位。
- 富途行情状态占位。
- 版本信息。

内部组件：

- `StrategySettingsPanel`
- `_SettingTile`
- `_StrategyInput`

后续：

- 后端 API URL 设置可以从这里扩展。
- 富途连接参数、FutuOpenD 地址、端口、市场权限状态可以从这里扩展。
- Firebase/本地通知开关也可以从这里扩展。

### `screens/display_settings_screen.dart`

显示设置页。

职责：

- 切换夜间模式。
- 切换日间模式。

当前日间模式要求：

- 白色背景。
- 黑色主文字。
- 浅蓝色卡片。

颜色实现来自 `utils/theme_helpers.dart`。

### `screens/account_screen.dart`

我的/账户页。

职责：

- 用户信息卡片。
- 开通会员卡片。
- 消息提醒设置。
- 显示设置入口。
- 盈亏分析。
- 策略实盘记录。
- 建议反馈。
- 关于我们。

后续：

- 如果增加真正个人资料、会员状态、登录系统，可以从这里扩展。

## 弹窗模块

### `sheets/add_position_sheet.dart`

添加/编辑持仓底部弹窗。

职责：

- 添加新持仓。
- 编辑已有持仓。
- 输入股票代码、名称、数量、成本价、现价、昨收。
- 保存后返回 `StockPosition`。

调用位置：

- `AppShell._addPosition`
- `AppShell._editPosition`
- 详情页编辑也是通过传入的 `onEdit` 回调触发同一个弹窗。

后续：

- 接入富途 API 后，手动输入现价和昨收可以改为自动填充。
- 可保留手动编辑作为 fallback。

## 通用组件

### `widgets/common/app_tag.dart`

小标签组件，用于展示信号、数量、状态等短文本。

### `widgets/common/page_title.dart`

页面标题组件，统一主标题和副标题样式。

### `widgets/common/section_header.dart`

分区标题组件，支持右侧操作按钮。

### `widgets/common/market_switch.dart`

港股/美股切换组件。

依赖：

- `MarketFilter`

后续如果增加市场类型，需要同步扩展这里。

### `widgets/common/empty_state.dart`

空状态组件。

包含：

- `EmptyState`：带图标、标题、说明、可选按钮。
- `ReadOnlyEmptyState`：偏只读提示的空状态。

## 持仓组件

### `widgets/position/position_tile.dart`

持仓列表行组件。

职责：

- 展示股票名称、代码、数量。
- 展示实时价格。
- 展示当日收益。
- 展示持有收益。
- 点击进入详情。

当前已针对列表密度优化，比早期大卡片更适合多持仓。

后续：

- 如果想调整首页和持仓页列表展示，应优先改这个组件。
- 如果首页和持仓页未来需要不同样式，可新增参数控制密度，而不是复制两套 UI。

### `widgets/position/compact_metric.dart`

紧凑指标展示组件。

用于持仓行内的实时、当日、持有等小指标。

## 信号组件

### `widgets/signal/signal_tile.dart`

信号列表项组件。

职责：

- 展示信号类型。
- 展示股票。
- 展示时间/说明。
- 展示等级。
- 使用信号颜色强化视觉。

## 工具函数

### `utils/formatters.dart`

格式化工具。

函数：

- `formatHkd`：格式化金额，当前历史命名为 Hkd，但也用于泛金额展示。
- `formatCompactHkd`：紧凑金额格式。
- `currencySymbol`：根据股票代码返回货币符号，目前 `US.` 返回 `$`，其他返回 `HK$`。
- `formatPercent`：格式化百分比。
- `formatNumberInput`：格式化表单数字。

注意：

- 用户希望列表中尽量用 `$`、`¥`、`HK$` 或符号区分币种，减少占宽。
- 后续建议重构为真正的 `Currency` 模型，避免 `formatHkd` 名称和实际多币种展示不一致。

### `utils/theme_helpers.dart`

主题颜色工具。

函数：

- `isDarkMode`
- `pageBackgroundColor`
- `cardColor`
- `softCardColor`
- `borderColor`
- `primaryTextColor`
- `secondaryTextColor`
- `mutedIconColor`

日间模式当前规范：

- 页面背景：`0xFFF7FAFC`
- 卡片：浅蓝色系。
- 主文字：黑色/深灰。

夜间模式当前规范：

- 页面背景：深色。
- 卡片：深蓝黑色。
- 主文字：浅色。

后续所有新页面都应使用这里的 helper，避免再次出现日间模式白底但文字看不清的问题。

## 主要数据流

```text
main.dart
  -> StockSignalApp 管理 DisplayMode
  -> AppShell
      -> 读取 samplePositions 作为本地持仓初始值
      -> 根据 MarketFilter 过滤 visible positions
      -> buildSignals(visible, settings)
      -> 分发到 Dashboard / Positions / Signals / Settings
      -> AddPositionSheet 返回 StockPosition 后更新 _positions
      -> PositionDetailScreen 编辑后通过 onEdit 回调更新 _positions 和详情页本地状态
```

## 后续开发建议

### 1. 接入富途 API

建议新增：

```text
lib/models/quote_snapshot.dart
lib/models/candle.dart
lib/services/futu_quote_service.dart
lib/repositories/quote_repository.dart
```

不要直接在页面里写 FutuOpenD 请求逻辑。页面只接收行情数据并展示。

### 2. K 线图

当前 `PositionDetailScreen` 的 `_KLinePreview` 是模拟图表。后续可以：

- 先定义 `Candle` 模型。
- service 返回 `List<Candle>`。
- 用 Flutter `CustomPainter` 或图表库绘制。
- 保留分时、五日、日K、周K、月K Tab。

### 3. 持仓持久化

当前 `_positions` 只在内存中。后续可以：

- 先接本地存储，如 `shared_preferences` 或 sqlite。
- 再接后端 API。
- `AppShell` 中的 `_positions` 可迁移到 repository 或状态管理层。

### 4. 状态管理

当前用 `setState` 足够支撑静态阶段。后续功能增多后建议引入：

- `ChangeNotifier`
- `Riverpod`
- `Bloc`

引入前不要大改 UI，先稳定数据模型和服务层。

### 5. 编码与拆分约束

历史上曾因 PowerShell 写入未正确处理 UTF-8 导致中文乱码。后续修改务必注意：

- Dart 文件保存为 UTF-8。
- 不要用默认编码的 PowerShell 脚本批量改中文文件。
- 优先使用编辑器或安全 patch。
- 每次拆分后必须运行：

```powershell
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

### 6. 视觉约束

用户当前确认过的方向：

- 持仓列表要紧凑，适合 20+ 持仓。
- 详情页再展示完整信息和图表。
- 日间模式必须白底、黑字、浅蓝卡片。
- 修改持仓后应保留在详情页，不要退回持仓总页。
- 港股/美股切换保留。
- 首页顶部中文大标题已替换为头像入口，点击进入我的页。

## 当前验证状态

最近一次拆分后已执行并通过：

```text
dart format lib test
flutter analyze
flutter test
```

如果新接手开发，请先运行以上命令确认本地环境正常，再继续新增功能。
