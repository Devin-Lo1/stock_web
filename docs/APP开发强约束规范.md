# App 开发强约束规范

最后更新：2026-05-13

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

### 4.3 页面与业务分离

- 页面只组合组件和状态。
- API 调用放 `services/`。
- 本地/远程数据协调放 `repositories/`。
- 数据结构放 `models/`。
- 纯展示组件放 `widgets/`。
- 格式化、主题、搜索辅助函数放 `utils/`。

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
- 编辑持仓后必须保留在详情页，并局部刷新数据。
- 删除持仓后返回列表，因为该持仓已不存在。

### 5.4 颜色规则

按港股/国内用户习惯：

```text
红色 = 上涨/盈利
绿色 = 下跌/亏损
灰色 = 辅助信息
```

### 5.5 日间/夜间模式

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
- 每次重新插拔手机、重启 ADB、重启电脑后，若使用 USB reverse，必须重新检查端口转发。

真机 USB 调试推荐：

```powershell
D:\Android\Sdk\platform-tools\adb.exe -s PQY0221B24008957 reverse tcp:8000 tcp:8000
D:\Android\Sdk\platform-tools\adb.exe reverse --list
```

如果不用 USB reverse，应使用局域网 IP 构建：

```powershell
D:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://电脑局域网IP:8000
```

当前局域网调试示例：

```powershell
D:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://192.168.1.4:8000
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
D:\flutter\bin\flutter.bat build apk --debug
D:\Android\Sdk\platform-tools\adb.exe -s PQY0221B24008957 install -r build\app\outputs\flutter-apk\app-debug.apk
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
