# main.dart 安全拆分方案

## 2026-05-11 当前拆分状态

`main.dart` 已经完成基础拆分，目前只保留：

- `main()`
- `StockSignalApp`
- 全局 `MaterialApp`
- 日间/夜间显示模式状态

当前核心文件已拆为：

```text
mobile_app/lib/screens/app_shell.dart
mobile_app/lib/screens/dashboard_screen.dart
mobile_app/lib/screens/positions_screen.dart
mobile_app/lib/screens/position_detail_screen.dart
mobile_app/lib/screens/signals_screen.dart
mobile_app/lib/screens/settings_screen.dart
mobile_app/lib/screens/account_screen.dart
mobile_app/lib/screens/display_settings_screen.dart
mobile_app/lib/models/
mobile_app/lib/services/
mobile_app/lib/sheets/
mobile_app/lib/widgets/
mobile_app/lib/utils/
```

最近一次拆分后已通过：

```powershell
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

## 当前安全备份

当前可正常运行的单文件版本已备份到：

- `mobile_app/lib_backup/main_before_split_latest.dart`
- `mobile_app/lib_backup/main_before_split_20260511_111125.dart`

如果后续拆分失败，直接用 `main_before_split_latest.dart` 覆盖 `mobile_app/lib/main.dart`，并删除新增拆分文件即可恢复。

## 这次乱码的原因

上次拆分时使用 PowerShell `Get-Content` / `Set-Content` 直接切分 Dart 文件。Windows 控制台与文件编码处理不稳定，中文字符串在读写过程中被转码污染，导致 App 页面出现乱码。

## 新拆分原则

1. 不用 PowerShell 对源码做批量切片写入。
2. 所有新 Dart 文件优先通过 `apply_patch` 创建，保证 UTF-8 内容直接进入文件。
3. 每次只拆一个小模块，不做大规模一次性搬迁。
4. 每拆一步都运行：
   - `D:\flutter\bin\dart.bat format lib test`
   - `D:\flutter\bin\flutter.bat analyze`
   - `D:\flutter\bin\flutter.bat test`
5. 每一步通过后再继续下一步。
6. 拆分前保留 `main.dart` 单文件备份，不覆盖备份。

## 推荐拆分顺序

### 第一步：拆模型，低风险

新增：

- `lib/models/stock_position.dart`
- `lib/models/trade_signal.dart`
- `lib/models/strategy_settings.dart`
- `lib/models/app_enums.dart`

只迁移纯数据结构：

- `StockPosition`
- `TradeSignal`
- `StrategySettings`
- `MarketFilter`
- `DisplayMode`

注意：如果模型依赖格式化函数，先保留在 `main.dart`，或者把格式化函数一起移到 utils 后再引用。

### 第二步：拆工具函数和样例数据

新增：

- `lib/utils/formatters.dart`
- `lib/utils/theme_helpers.dart`
- `lib/data/sample_positions.dart`
- `lib/services/local_signal_service.dart`

迁移：

- `_formatHkd`
- `_formatCompactHkd`
- `_currencySymbol`
- `_formatPercent`
- `_profitColor`
- `_dailyProfitRate`
- `_formatNumberInput`
- `_buildSignals`
- `_samplePositions`

这一步完成后，`main.dart` 只负责 App 状态和页面组合。

### 第三步：拆通用组件

新增：

- `lib/widgets/page_title.dart`
- `lib/widgets/market_switch.dart`
- `lib/widgets/metric_card.dart`
- `lib/widgets/tag.dart`
- `lib/widgets/empty_state.dart`

只迁移无业务状态的小组件。

### 第四步：拆功能组件

新增：

- `lib/widgets/header.dart`
- `lib/widgets/asset_overview.dart`
- `lib/widgets/position_tile.dart`
- `lib/widgets/signal_tile.dart`
- `lib/widgets/strategy_settings_panel.dart`

注意 `PositionTile` 会依赖导航到详情页，所以最好在详情页拆完后再调整引用。

### 第五步：拆页面

新增：

- `lib/screens/dashboard_screen.dart`
- `lib/screens/positions_screen.dart`
- `lib/screens/signals_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/account_screen.dart`
- `lib/screens/display_settings_screen.dart`
- `lib/screens/position_detail_screen.dart`

页面拆分放在最后，避免跨文件私有类和导航依赖同时变化。

### 第六步：拆表单弹窗

新增：

- `lib/sheets/add_position_sheet.dart`

迁移添加/编辑持仓弹窗。

## 技术选择

优先使用普通 `import`，不再用 `part / part of`。

原因：

- `import` 更接近真实 Flutter 项目结构。
- 文件边界更清楚，后续接 API、状态管理、服务层更自然。
- 避免大量私有 `_ClassName` 跨文件依赖。

迁移时需要把跨文件使用的组件从 `_PrivateName` 改成公开命名，例如：

- `_PositionTile` -> `PositionTile`
- `_SignalTile` -> `SignalTile`
- `_PageTitle` -> `PageTitle`

## 后续拆分建议

基础拆分已经完成，后续不要为了“拆分”而继续机械拆文件。建议在新增真实功能时，按业务边界继续拆。

### 1. 行情与 K 线

当开始接入富途行情或后端行情 API 时，建议新增：

```text
mobile_app/lib/models/quote_snapshot.dart
mobile_app/lib/models/candle.dart
mobile_app/lib/services/quote_service.dart
mobile_app/lib/repositories/quote_repository.dart
mobile_app/lib/widgets/chart/kline_chart.dart
```

约束：

- `PositionDetailScreen` 只负责展示行情和图表。
- 富途 API 逻辑不要写进 Flutter 页面。
- 真实 K 线数据先进入 model/service/repository，再传给图表组件。

### 2. 后端 API

当 Flutter 开始接后端时，建议新增：

```text
mobile_app/lib/services/api_client.dart
mobile_app/lib/services/position_api_service.dart
mobile_app/lib/services/settings_api_service.dart
mobile_app/lib/repositories/position_repository.dart
mobile_app/lib/repositories/settings_repository.dart
```

约束：

- 页面不直接拼 URL。
- API 返回数据先转成 model。
- 保留 `sample_positions.dart` 作为开发 fallback。

### 3. 状态管理

当前 `AppShell` 用 `setState` 管理持仓、市场筛选和策略设置。后续功能变多后，可按顺序迁移：

```text
mobile_app/lib/state/position_controller.dart
mobile_app/lib/state/settings_controller.dart
mobile_app/lib/state/quote_controller.dart
```

推荐顺序：

1. 先抽 repository。
2. 再抽 controller。
3. 最后决定是否引入 Provider / Riverpod / Bloc。

不要在同一轮里同时改 UI、API、状态管理和目录结构。

### 4. 设置页继续拆

如果设置页继续增长，可以拆：

```text
mobile_app/lib/widgets/settings/strategy_settings_panel.dart
mobile_app/lib/widgets/settings/settings_tile.dart
mobile_app/lib/screens/futu_settings_screen.dart
mobile_app/lib/screens/notification_settings_screen.dart
```

### 5. 账户页继续拆

如果我的页增加登录、会员、反馈等真实流程，可以拆：

```text
mobile_app/lib/widgets/account/account_header.dart
mobile_app/lib/widgets/account/membership_banner.dart
mobile_app/lib/widgets/account/account_menu_tile.dart
mobile_app/lib/screens/profile_screen.dart
mobile_app/lib/screens/feedback_screen.dart
mobile_app/lib/screens/about_screen.dart
```

### 6. 测试补充

后续每新增一个核心业务模块，至少补一个轻量测试。优先覆盖：

- 当日收益计算。
- 持有收益计算。
- 止盈/止损/异动信号生成。
- 编辑持仓后详情页不退出。
- 日间模式文字可见。

## 后续拆分硬约束

- 每次只拆一个明确模块。
- 每拆一步立即跑 format / analyze / test。
- 不要用默认编码 PowerShell 写入含中文文件。
- 不要在拆分时顺手改 UI 视觉。
- 不要删除安全备份。
- 不要把已拆出的模块再合回 `main.dart`。
- 如果出现乱码，优先用备份恢复，不要继续在乱码文件上修补。

## 回滚办法

如果任一步出现乱码或编译失败且短时间不好修：

1. 删除新建的拆分目录或文件。
2. 用 `mobile_app/lib_backup/main_before_split_latest.dart` 覆盖 `mobile_app/lib/main.dart`。
3. 运行 `dart format`、`flutter analyze`、`flutter test`。
4. 回到上一个稳定点。
