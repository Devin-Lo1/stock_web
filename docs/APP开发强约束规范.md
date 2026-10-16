# App 开发强约束规范

## 0. 2026-07-09 新增强约束

1. 未跟踪业务代码不得默认视为主线功能。当前 `portfolio_strategy` 相关 router/schema/service/test 已决定暂作为后备保留；除非用户重新启用，否则不要继续围绕它开发移动端或部署。
2. 研究脚本和结果文件需要按用途分级处理：`scripts/research_*_tmp.*` 若用于策略回测追溯，可以暂时保留；`__pycache__` 这类解释器缓存应清理且不提交。
3. 文档必须区分“本地代码基线”和“云端已部署基线”。不能把本地 `git log -1` 直接写成云端已部署状态。
4. 新增组合建议、资产配置、策略推荐等功能时，必须保留“人工确认、不自动交易”的产品边界，不能在接口或文案中暗示自动下单。
5. 通用回测和专属策略研究的成交口径必须写清楚。若口径不同，不能直接比较收益、回撤和胜率数字。
6. 当前有效验证基线是后端 `155 passed`、Flutter analyze 无问题、Flutter test `71 passed`；历史文档里的旧测试数量只作为历史记录。

## 0. 2026-06-06 新增强约束

本项目已经进入交接阶段，后续开发者必须先遵守以下新增约束，再继续任何代码或数据操作：

1. 中文文件必须保持 UTF-8。不得用可能乱码的终端命令直接输出中文文档或中文源码正文；需要检查时使用 UTF-8 校验、结构化扫描或只输出 ASCII 摘要。
2. 不得把 API token、服务器密钥、推送凭据、Futu 账号密码写入 Git、文档或聊天记录。需要构建 App 时通过本机环境变量或 `--dart-define` 注入。
3. App 当前继续使用公网 API `http://119.91.47.141`。域名和 HTTPS 服务器侧已准备，但必须真机 HTTPS 验证稳定后才能切 App API。
4. 云端 PostgreSQL 是事实数据源，本地旧库只能用于开发验证，不能当主库回写。
5. FutuOpenD 只在云服务器本机访问，`11111` 和 `22222` 禁止开放公网。
6. 专属策略每次变更都必须同步三处：`backend/app/services/personalized_strategies.py`、`backend/tests/test_personalized_strategies.py`、`docs/us_stock_strategy_research_20260602.md`。
7. 专属策略研究回测必须使用净收益口径，计入滑点和费用；禁止未来函数。推荐口径是先用 2021-2025 寻找候选，再用 2026YTD 做验证，最终再输出全周期和年度分段结果。
8. 若下一步要重新测算原有专属策略，先只做研究结果，不直接写入 App；等用户确认 Top1/Top3 后再修改模板。

最后更新：2026-05-26

本文档是本项目后续开发的强制规范，合并自：

- `docs/中文编码与乱码防护强制规范.md`
- `docs/main_dart_安全拆分方案.md`
- `docs/lib_architecture.md`

所有新接手的开发者或 AI 必须先阅读并遵守本文档。若本文档与临时便利做法冲突，优先遵守本文档。

## 1. 总原则

- 本项目是金融工具，优先保证数据清晰、可读、稳定、可维护。
- `mobile_app/lib/main.dart` 必须保持薄入口，不允许重新变成大文件。
- 新功能必须沿现有模块边界开发：model、service、repository、screen、widget、utils 分工明确。
- 后端、富途、聚宽、回测等复杂业务逻辑不得写进 Flutter 页面。
- 涉及中文内容时，编码安全优先级高于开发速度。
- 每次代码改动后必须运行格式化、静态检查和测试。

## 2. 中文编码强约束

### 2.1 必须做到

- 所有源码、Markdown、JSON、YAML、配置文件中的中文内容必须使用 UTF-8 保存。
- 新增或修改中文 UI 文案、中文注释、中文 Markdown 时，必须确认文件仍为 UTF-8。
- 发现乱码时，不得继续基于乱码文本扩写，必须先确认原意，再替换为正确中文。
- 新增文档优先新建 UTF-8 文件。
- 小范围中文修改优先使用 `apply_patch`。

### 2.2 禁止操作

默认禁止以下操作，除非明确声明编码并已验证结果：

- 使用 PowerShell `Set-Content`、`Out-File`、`>`、`>>` 重写包含中文的文件。
- 使用脚本整文件读写中文 Dart、Markdown、JSON 文件。
- 使用未声明编码的 Python、Node、PowerShell 脚本批量替换中文。
- 在已经乱码的文件中复制乱码字符串作为新 UI 文案。
- 通过终端看到乱码后，把该乱码内容写回源码。
- 为了“快速替换”整文件重写包含中文的源码或文档。

### 2.3 终端查看中文限制

- 不允许使用 `Get-Content`、`type`、`cat`、`rg` 等命令在终端直接打印包含中文的文件正文。
- 若必须查看中文文档或中文源代码，应优先使用 IDE、`apply_patch` 局部上下文，或使用 Unicode 转义方式读取。
- 终端里看到的异常中文或乱码只能作为风险信号，不能作为可写回代码或文档的可信内容。

### 2.4 乱码识别

看到以下形态，通常说明中文已被错误编码破坏。为避免本文档自身触发扫描误报，下方仅描述特征，不直接写入真实乱码样例：

```text
replacement character：Unicode U+FFFD
UTF-8/GBK 互相误解后的中文乱码：常见为多个异常汉字连续出现
UTF-8 字节被当作 Latin-1/Windows-1252 后的乱码：常见为拉丁扩展字符连续出现
中文文本中夹杂无意义问号：通常表示写入或转码阶段已经丢字节
```

这不是 Flutter 渲染问题，而是源文件或数据已经被错误编码污染。

### 2.5 乱码修复流程

1. 定位乱码所在文件和行号。
2. 判断原文含义，必要时结合上下文或询问项目负责人。
3. 使用 UTF-8 中文替换乱码文本。
4. 只修改必要行，避免整文件重写。
5. 修改后运行格式化、静态检查、测试。
6. 若是 UI 文案，需真机或截图验证显示效果。

### 2.6 当前特别注意

- 后端历史持仓名称中存在中文乱码，属于后端数据或存储历史问题，应单独修复。
- 不要在普通功能开发中顺手大范围修复乱码。
- 如果需要修复旧文档乱码，应作为单独任务处理。

## 3. 拆分代码强约束

### 3.1 `main.dart` 约束

`mobile_app/lib/main.dart` 只允许保留：

- `main()`
- `StockSignalApp`
- 全局 `MaterialApp`
- 全局显示模式状态

禁止在 `main.dart` 中新增：

- 页面 UI。
- 持仓业务逻辑。
- 行情 API 调用。
- 策略或回测逻辑。
- 富途或聚宽相关逻辑。

### 3.2 拆分方式

- 每次只拆一个明确模块。
- 不做大规模一次性搬迁。
- 不在拆分时顺手改 UI 视觉。
- 不在拆分时顺手改业务行为。
- 每一步通过 format / analyze / test 后再继续下一步。
- 优先使用普通 `import`，不使用 `part / part of`。
- 跨文件使用的组件必须公开命名，不要依赖私有 `_ClassName` 跨文件。

### 3.3 推荐拆分方向

当前基础拆分已完成，后续不要为了拆分而拆分，应按业务增长拆：

- 行情和 K 线：`models/quote_snapshot.dart`、`models/candle.dart`、`services/quote_api_service.dart`、`widgets/chart/`
- 持仓仓储：`repositories/position_repository.dart`
- 设置增长：`widgets/settings/`、`screens/futu_settings_screen.dart`
- 账户增长：`widgets/account/`、`screens/profile_screen.dart`
- 策略量化：`services/strategy_api_service.dart`、`repositories/backtest_repository.dart`、`screens/strategy_lab_screen.dart`

### 3.4 当前仍建议继续拆的文件

- `mobile_app/lib/screens/position_detail_screen.dart`
  - 仍然较大，后续优先拆交互 K 线、K 线 painter、横屏图表、选中 K 线信息面板、MA 计算工具。
- `mobile_app/lib/sheets/add_position_sheet.dart`
  - 已抽出搜索数据和搜索工具，但 UI 子组件仍可继续拆。
- `mobile_app/lib/screens/positions_screen.dart`
  - 当前较小，暂时不需要拆。

## 4. 架构边界强约束

### 4.1 Flutter 端职责

Flutter App 负责：

- 页面展示。
- 用户输入。
- 状态切换。
- 调用后端 REST/WebSocket。
- 展示持仓、行情、信号、回测结果。
- 基础本地缓存和离线 fallback。

Flutter App 不负责：

- 直接连接 FutuOpenD。
- 直接接聚宽/JQData SDK。
- 执行复杂回测计算。
- 计算完整多因子模型。
- 承担 24 小时行情监听。
- 保存敏感后端配置。

### 4.2 后端职责

FastAPI 后端负责：

- 持仓 CRUD。
- 行情获取、缓存、刷新。
- 富途 API/FutuOpenD 连接。
- 策略信号计算。
- 回测引擎。
- 多因子研究数据接入。
- 推送触发。
- 数据持久化。

### 4.2.1 持仓收益权威口径

- 持仓管理相关的市值、成本、当日盈亏、持仓盈亏、总收益、仓位占比必须以后端 `position_snapshots` 计算结果为权威来源。
- Flutter 只允许做格式化、颜色、布局、筛选和交互，不允许在页面层重新计算上述核心收益指标。
- 后端快照不可用时，App 可以保留本地缓存保证页面不崩溃，但核心收益指标必须显示为“未同步”或空值，不得静默用前端公式伪装成实时数据。
- 新增或修改持仓收益口径时，必须同步补充后端测试，至少覆盖建仓、加仓、减仓、清仓、当日盈亏、持仓盈亏、总收益和仓位占比。
- 加仓、减仓、清仓必须写入后端 `position_trades`，由后端更新持仓数量、真实平均成本、券商式摊薄成本和已实现盈亏；Flutter 不得自行修改这些口径。

### 4.3 页面与业务分离

- 页面只组合组件和状态。
- API 调用放 `services/`。
- 本地/远程数据协调放 `repositories/`。
- 数据结构放 `models/`。
- 纯展示组件放 `widgets/`。
- 格式化、主题、搜索辅助函数放 `utils/`。

### 4.4 后端数据库层强约束

当前 `backend/app/database.py` 已拆成兼容门面。后续严禁继续把具体 SQL、表初始化、seed、row 转换逻辑写回 `database.py`。

必须遵守：

- 业务数据库读写放 `backend/app/repositories/`。
- 持仓读写放 `backend/app/repositories/positions.py`。
- 行情和 K 线读写放 `backend/app/repositories/market_data.py`。
- 策略定义读写放 `backend/app/repositories/strategies.py`。
- 回测运行和回测结果读写放 `backend/app/repositories/backtests.py`。
- 数据库连接、SQLite/PostgreSQL 占位符兼容、字段补齐工具放 `backend/app/db/core.py`。
- 建表和初始化流程放 `backend/app/db/init.py`。
- 默认 seed 和历史乱码名称修复放 `backend/app/db/seed.py`。
- row/model/JSON/时间转换放 `backend/app/db/converters.py`。

当前 `backend/app/database.py` 只允许做旧调用兼容导出。新增后端业务代码应逐步直接引用对应 repository，不要继续扩大兼容门面。

## 5. UI 与交互强约束

### 5.1 金融工具风格

本项目不是营销页，UI 应优先：

- 信息密度。
- 清晰数字。
- 可快速扫描。
- 少装饰。
- 稳定布局。
- 长期使用舒适。

禁止把首页、持仓页做成大而空的宣传式页面。

### 5.2 持仓列表

- 持仓列表必须紧凑，适合 20+ 持仓。
- 列表只展示核心信息。
- 详细信息进入详情页展示。
- 首页和持仓页列表样式优先改 `widgets/position/position_tile.dart`。

### 5.3 详情页

- 详情页展示完整行情、K 线、收益、成本和操作。
- 详情页的交易历史、收益曲线和核心收益指标必须来自后端，不允许只做前端展示数据。
- 编辑持仓后必须保留在详情页，并局部刷新数据。
- 删除持仓后返回列表，因为该持仓已不存在。

### 5.4 颜色规则

项目统一颜色口径：

```text
绿色 = 流入/上涨
红色 = 流出/下降
灰色 = 辅助信息
```

### 5.5 量化结果展示

- 回测交易记录必须完整可查看，不允许为了节省空间只截断前几条。
- 手机端交易记录较多时，应使用固定高度滚动卡片或分页加载。
- 结果区可以控制视觉高度，但不能丢失后端返回的交易明细。
- 历史回测详情和新回测结果应遵守同一展示规则。

### 5.6 日间/夜间模式

日间模式必须：

- 白底。
- 黑字或深灰字。
- 浅蓝卡片。
- 可读性优先。

夜间模式保持深色金融风格。

新增 UI 必须优先使用：

```dart
pageBackgroundColor(context)
cardColor(context)
softCardColor(context)
borderColor(context)
primaryTextColor(context)
secondaryTextColor(context)
mutedIconColor(context)
```

不要在组件里随意写死深色背景。

## 6. API 与网络强约束

- 页面不要直接拼 URL。
- 所有 HTTP 调用必须通过 `services/api_client.dart` 或对应 service。
- 所有 API 返回应先转成 model。
- 请求必须有超时保护，避免手机端无限转圈。
- 后端不可用时应保留本地缓存或 fallback，而不是让 App 崩溃。
- 真机调试访问本机后端时必须处理地址问题。
- 每次切换后端连接方式后，必须重新构建或重新运行 App，确认 `API_BASE_URL` 已经生效。
- 公网 API 启用访问保护后，构建 App 必须同时传入 `--dart-define=API_ACCESS_TOKEN=...`；该 token 只允许保存在服务器 `.env`、本机临时 shell 变量或构建机安全变量中，不得提交 Git、写入文档或聊天记录。
- 每次重新插拔手机、重启 ADB、重启电脑后，若使用 USB reverse，必须重新检查端口转发。
- 项目当前默认采用云服务器真机调试：`http://119.91.47.141`。重新构建真机 APK 时禁止裸跑 `flutter build apk --debug`，必须运行构建脚本并显式传入 `API_BASE_URL` 和 `API_ACCESS_TOKEN`。
- 若临时构建局域网调试 APK，必须显式传入 `--dart-define=API_BASE_URL=http://电脑当前局域网IP:8000`，不要混用局域网包和云服务器包。
- 域名 `devinstock.cloud` / `www.devinstock.cloud` 已配置服务器侧 HTTPS，但 App 切换到 `https://devinstock.cloud` 前必须完成真机验证。
- 当前后端只在设置 `API_ACCESS_TOKEN` 时保护 `/api/v1/*`；`/` 和 `/health` 保持公开用于部署脚本、Nginx 和基础监控。App 端统一由 `services/api_client.dart` 添加 Bearer token，不要在页面或各 service 中手写鉴权 header。
- 公网部署后，后端健康检查正常不等于 FutuOpenD 正常。FutuOpenD 默认由后端通过 `FUTU_HOST` / `FUTU_PORT` 访问，禁止让 Flutter 直连 FutuOpenD，禁止将 FutuOpenD 端口直接暴露公网。
- 电脑切换 Wi-Fi、热点、路由器或网卡后，局域网 IP 可能变化；必须重新构建并安装 APK。`build_mobile_lan_debug.ps1` 默认会自动探测当前带默认网关的 IPv4 地址。
- 真机 APK 安装后必须到 App 设置页核对“后端 API”显示的地址；如果不是当前电脑局域网地址，本次 APK 视为构建错误，必须重新构建安装。

真机 USB 调试推荐：

```powershell
D:\Android\Sdk\platform-tools\adb.exe -s PQY0221B24008957 reverse tcp:8000 tcp:8000
D:\Android\Sdk\platform-tools\adb.exe reverse --list
```

如果不用 USB reverse，应使用局域网 IP 构建：

```powershell
D:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://电脑局域网IP:8000
```

当前局域网调试示例，IP 必须按电脑当前网络实际值替换：

```powershell
D:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://电脑当前局域网IP:8000
```

推荐使用仓库脚本，自动探测当前局域网 IP，避免漏传 `API_BASE_URL`：

```powershell
.\scripts\build_mobile_lan_debug.ps1
```

公网 API 已启用 token 时，可使用脚本参数传入，不要把 token 写死进脚本：

```powershell
.\scripts\build_mobile_lan_debug.ps1 -ApiBaseUrl http://119.91.47.141 -ApiAccessToken $env:STOCK_WEB_API_TOKEN
```

切换为局域网后，为确认没有继续依赖 USB reverse，应清空转发：

```powershell
D:\Android\Sdk\platform-tools\adb.exe reverse --remove-all
D:\Android\Sdk\platform-tools\adb.exe reverse --list
```

远程服务器方式必须使用服务器域名或公网 IP，不允许继续写本机 `127.0.0.1`：

```powershell
D:\flutter\bin\flutter.bat build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

## 7. 富途、聚宽、策略与回测约束

### 7.1 富途

- 富途 API 由后端接入。
- Flutter 不直接连接 FutuOpenD。
- 富途适合提供实时行情、行情快照、K 线、换手、PE、成交额、权证字段。
- 富途可用于 A 股交易所行情，包括 A 股股票、指数、场内 ETF/LOF 等以 `SH.`、`SZ.` 标识的证券；不得把这些和场外开放式基金混为同一类资产。
- 场外开放式基金的每日净值、累计净值、估算净值和申购赎回状态不依赖 Futu 行情接口，必须走独立基金 provider 和基金净值数据源。
- 现有 `futu_client.py` 若支持 A 股场内基金/ETF，必须先修正市场和币种映射：`SH.`、`SZ.` 应识别为 A 股/CNY，不得继续按非 US 默认写成 HK/HKD。

### 7.2 聚宽/JQData

可以参考或接入：

- 聚宽 API 文档：https://cdn.joinquant.com/help/img/JoinQuantAPI.pdf
- JQData SDK：https://github.com/JoinQuant/jqdatasdk

但聚宽/JQData 应主要作为数据源或研究辅助，不应替代本项目自己的策略逻辑和回测引擎。

### 7.3 策略逻辑

以下内容必须由我们自己的策略模块控制：

- 什么时候买。
- 什么时候卖。
- 手续费。
- 滑点。
- 仓位管理。
- 止盈止损。
- 最大回撤控制。
- 调仓周期。
- 信号去重。
- 组合约束。

### 7.4 回测

- 回测在后端跑。
- App 只负责配置和展示结果。
- 回测结果必须记录参数、日期区间、手续费、滑点、数据来源和生成时间。
- 回测结果不得包装为投资建议。
- 量化页默认结束日期不得硬编码为某个历史日期，必须默认使用当前日期或后端可识别的最新交易日期。
- 回测和实时策略扫描不得只判断 K 线数量是否足够，还必须判断缓存数据是否覆盖到请求的结束日期；缓存过旧时必须先尝试刷新。
- 涉及 K 线、回测历史详情或买卖点图的 SQL 改动必须在 PostgreSQL 上验证；PostgreSQL 子查询必须带别名，例如 `FROM (...) AS alias`。
- 详情页 K 线、量化页买卖点图、后端策略信号扫描必须尽量使用同一份最新 K 线缓存，避免详情页已更新而量化信号仍滞后数日。
- 量化页买卖点 K 线可以使用回测专用图表组件，但图中指标必须跟当前策略参数一致，不得硬编码为 MA5/MA20；例如 MA Cross 参数是 5/10 时，图表也必须显示 MA5/MA10。
- 详情页“收盘价跌破某条均线”和 MA Cross “短均线下穿长均线”属于不同触发条件。若需要按价格跌破 MA 触发信号，必须新增独立策略或独立条件，不得混同为双均线死叉。
- 下一步新增 `price_break_ma` 时，必须作为独立策略实现，不能修改 `ma_cross` 的金叉/死叉定义；回测、实时扫描、信号文案和推送候选都要使用同一套触发语义。
- `price_break_ma` 信号必须展示收盘价、目标 MA 值、均线周期、触发方向（跌破/站回）和触发日期，文案必须保持“观察信号”语气。

### 7.5 推送提醒

- 重要信号推送必须以后端信号事件为准，不能只依赖 Flutter 页面当前内存状态。
- 信号必须先落库，再推送；推送失败不能导致信号历史丢失。
- App 只负责通知权限、设备 token、提醒设置、本地展示和点击跳转，不在页面里实现后端推送扫描。
- 服务端必须记录推送通道、目标设备、请求状态、失败原因和重试次数。
- 同一股票同一信号必须按去重 key 和时间窗口去重，避免行情波动造成通知刷屏。
- 推送文案不得写成投资建议，只能表达“触发观察信号”。
- 推送 payload 不放完整持仓、成本、资金等敏感信息；详细内容由 App 打开后通过接口读取。
- 国内 Android 设备不能假设 FCM 必然稳定，推送通道必须预留厂商推送扩展。
- `push_candidate=false` 的信号不得进入远程推送分发；`push_candidate=true` 的信号也必须按设备开关、重要通知开关和同一信号同一设备去重后再发送。
- 同一条 `signal_events` 对同一台设备不得重复发送；重复调度应复用已有 `push_records`。

### 7.6 策略信号中心

- 信号页不能只展示一堆不可解释的提示，必须让用户知道信号来自哪个策略、为什么触发、当前值是多少、阈值是多少。
- 信号必须按来源分类：持仓风控信号、量化策略信号、系统通知信号。
- 持仓风控信号包括止盈观察、止损观察、当日上涨异动、当日下跌异动。
- 量化策略信号包括 MA Cross、RSI、MACD、BOLL、成交量动量等后端策略扫描结果。
- 系统通知信号包括后端连接、数据刷新、推送通道、任务执行等运行状态，不应和交易观察信号混在一起作为同等优先级展示。
- 每条策略信号至少应包含：股票代码、股票名称、信号来源、策略 code、策略名称、触发条件、当前值、阈值、级别、触发时间、去重 key、是否需要推送。
- 信号文案必须使用“观察”“触发条件”“策略提示”等中性表达，不得写成买入、卖出或收益承诺。
- 弱信号默认只在 App 内展示，不应直接推送；强信号和多策略共振信号才进入推送候选。
- 同一股票同一策略同一方向的信号必须按时间窗口去重，避免行情反复穿越阈值导致刷屏。
- 用户必须能控制每类策略是否启用、是否进入推送、阈值参数是多少。
- 回测策略和实时扫描策略必须共用后端策略规则或同源参数定义，避免“回测看到一种策略、信号页又是另一种策略”。
- 信号页应支持筛选：全部、持仓风控、量化策略、重要、已忽略。
- 新增策略时必须同步定义：回测参数、实时触发条件、信号解释文案、默认级别、默认是否推送。
- 信号扫描第一阶段先做手动触发接口，不急于定时任务；手动扫描稳定后再加后台定时扫描。
- 信号扫描必须在后端完成，扫描股票池第一阶段优先使用当前持仓和关注列表，后续再扩展到场内 ETF/基金观察池。
- 扫描结果必须先落库到 `signal_events`，再由 App 拉取展示；推送只消费已落库信号，不直接消费页面内存信号。

### 7.7 后台策略监控

- 后台策略监控必须复用 `backend/app/services/strategy_monitor_scanner.py` 和 `backend/app/strategies/` 下的策略语义，不得另写一套买卖判断。
- scheduler 只能负责调度、状态记录和启动停止，不得承担数据库 SQL、策略计算或推送分发。
- 本地开发默认不自动启动 scheduler，必须通过 `STRATEGY_MONITOR_SCHEDULER_ENABLED` 明确打开，避免开发调试时反复写入信号。
- scheduler 扫描结果必须先落库到 `signal_events`，推送服务只能消费已落库信号。
- 多进程或多实例部署前必须迁移到独立 worker、APScheduler 持久化任务或 Celery，避免多个 API 进程重复扫描同一批监控。

### 7.8 场外基金管理与提醒

- 场外基金是独立资产域，不得混进股票持仓表和 Futu 行情刷新链路。
- 基金净值以正式净值为权威；盘中估算净值只能用于收盘前辅助判断和提醒，文案必须明确是“估算”或“观察提醒”。
- 正式净值更新后，基金当日收益、日涨跌和持有收益应自动切换为正式净值口径。
- 基金交易记录必须落后端表，基金份额、成本净值、持有收益和下一次提醒基准不得只在 Flutter 页面内更新。
- 基金加仓、减仓、修正持仓属于现金流和账本事件，不能被当成基金自身收益；业绩走势必须只由基金净值序列和基准指数决定。后端收益计算必须区分 `holding_profit` 与 `realized_profit`，当前净值加减仓不得凭空改变 `total_profit`。
- 基金策略提醒基准必须来自后端最新交易记录的确认净值/确认时间；Flutter 只能提交用户选择的原平台操作时间和三点前后状态，不得在页面内自行决定最终策略基准。
- 基金提醒阈值必须由用户配置；默认值可以提供，但不能把 3%、5%、8% 写死为唯一规则。
- 基金提醒 scheduler 支持多个提醒时间，配置和最近扫描状态必须后端持久化，不能依赖页面计时器。
- 基金提醒扫描必须先写入 `signal_events`，推送只消费已落库信号。
- 基金数据源较慢或失败时，App 应展示缓存时间、失败原因或降级提示，不得长时间空白等待。
- 删除基金持仓、交易记录、提醒记录等会影响用户资产理解的操作必须有确认提示。

## 8. 验证强约束

### 8.1 Flutter 每次代码修改后必须运行

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\dart.bat format lib test
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

如果改动涉及 APK 或真机体验，还必须运行：

```powershell
cd C:\Users\58229\Desktop\stock_web
$key=Join-Path $env:USERPROFILE '.ssh\id_ed25519_gitee_stock_web'
$token=ssh -i $key -o BatchMode=yes ubuntu@119.91.47.141 'set -a; . /home/ubuntu/stock_web/backend/.env >/dev/null 2>&1; printf %s "$API_ACCESS_TOKEN"'
.\scripts\build_mobile_lan_debug.ps1 -ApiBaseUrl 'http://119.91.47.141' -ApiAccessToken $token
D:\Android\Sdk\platform-tools\adb.exe -s PQY0221B24008957 install -r mobile_app\build\app\outputs\flutter-apk\app-debug.apk
```

### 8.2 后端每次代码修改后必须运行

当前后端测试体系还不完整，最低要求：

```powershell
cd C:\Users\58229\Desktop\stock_web\backend
python -m compileall app
```

如果后续新增测试，应运行：

```powershell
python -m pytest
```

当前后端已经新增 PostgreSQL 数据库测试。每次修改 `backend/app/database.py`、数据库表结构、迁移脚本或后端持仓/行情/K 线读写逻辑后，必须运行：

```powershell
cd C:\Users\58229\Desktop\stock_web\backend
.venv\Scripts\python.exe -m compileall app scripts tests
.venv\Scripts\python.exe -m pytest
```

测试必须使用独立测试库 `stock_web_test`，不得在真实开发库 `stock_web` 上执行会清空表的自动化测试。

如果后端服务需要真机联调，应确认：

```powershell
curl http://127.0.0.1:8000/health
```

### 8.3 文档修改后必须检查

```powershell
# 扫描 Unicode replacement character
rg -n "\x{FFFD}" docs mobile_app\docs
```

如果怀疑存在 UTF-8/GBK 互转污染，要结合具体异常字符补充一次定向扫描；不要把定向扫描中的异常字符长期写回规范文档，避免规范文档自身成为误报来源。

## 9. Git 与工作区约束

- 不要回滚用户已有改动。
- 不要使用 `git reset --hard`。
- 不要使用 `git checkout --` 覆盖用户文件。
- 如遇 dirty worktree，先辨认是否与当前任务相关。
- 如需删除或大范围移动文件，先确认目标路径和影响范围。

## 10. 交接要求

每次完成阶段性开发后，应在最终说明中包含：

- 改了哪些文件。
- 为什么这样拆分或设计。
- 运行了哪些验证命令。
- 是否有未完成事项。
- 是否需要用户真机检查。

如果新增了架构、流程、约束或下一步任务，应同步更新：

- `docs/APP开发强约束规范.md`
- `docs/APP总体开发规划.md`
- `docs/APP后续开发方案.md`
- `docs/APP项目结构说明.md`
