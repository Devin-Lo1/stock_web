# App 服务器部署与 Futu 交接说明

最后更新：2026-05-26

本文记录最近一次从局域网调试切到云服务器后的交接状态。若本文与早期“局域网真机调试”说明冲突，以本文为准。

## 1. 当前服务器基线

- 云服务器：腾讯云轻量应用服务器，广州，Ubuntu 22.04.5 LTS。
- 当前 App 使用的公网 API：`http://119.91.47.141`
- 域名：`devinstock.cloud`、`www.devinstock.cloud`
- HTTPS：服务器侧已配置 Let's Encrypt，证书到期日为 `2026-08-24`
- 健康检查：`http://119.91.47.141/health`
- 服务器项目目录：`/home/ubuntu/stock_web`
- 代码仓库：`git@gitee.com:luo-dewen/stock_web.git`
- 运行链路：Nginx 80 -> FastAPI `127.0.0.1:8000` -> PostgreSQL。
- 后端 systemd 服务：`stock-web-backend`
- Nginx 配置：`/etc/nginx/sites-available/stock-web`
- 数据库：PostgreSQL，本机 `127.0.0.1:5432`，库名 `stock_web`，用户 `stock_web`。
- 数据库密码只允许放在服务器 `.env` 中，禁止写入文档、代码和 Git。
- 公网 API token 只允许放在服务器 `.env` 的 `API_ACCESS_TOKEN` 中，禁止写入文档、代码和 Git。
- 2026-05-25 18:31 已以本地 PostgreSQL 为准完成本地到云服务器迁移。迁移后云端 `stock_web` 包含本地持仓、基金、回测、策略监控、通知和推送记录数据；迁移前云端旧库保留为 `stock_web_before_migration_20260525_183135`。
- 备份脚本：
  - `scripts/backup_postgres.sh`
  - `scripts/install_postgres_backup_timer.sh`
  - 备份目录：`/home/ubuntu/stock_web_backups`

数据库迁移验证：

- 迁移前云端备份：`/home/ubuntu/stock_web_backups/stock_web_20260525_182811.dump`
- 迁移后云端备份：`/home/ubuntu/stock_web_backups/stock_web_20260525_183210.dump`
- 2026-05-26 美股持仓替换前备份：`/home/ubuntu/stock_web_backups/stock_web_20260526_165323.dump`
- 2026-05-26 港股持仓替换前备份：`/home/ubuntu/stock_web_backups/stock_web_20260526_172741.dump`
- 迁移后关键表数量：`positions=6`、`fund_positions=1`、`fund_trades=3`、`klines=10367`、`strategy_monitors=1`、`signal_events=36`、`backtest_runs=4`、`notification_devices=11`、`push_records=92`
- 迁移后 API 验证：`/health=200`、无 token `/api/v1/positions=401`、带 token `/api/v1/positions` 返回 6 条、带 token `/api/v1/funds/positions` 返回 1 条。

本地最近功能基线：

```text
4ddbc3f fix: prevent quant parameter overflow
a92a987 fix: make kline query postgres compatible
2f6c48f feat: mark estimated fund day profit
c4611e2 fix: value fund holdings by official nav
```

## 2. 当前 App 连接方式

当前真机 APK 已改为连接云服务器，而不是电脑局域网 IP。

重新构建 APK 时必须显式指定服务器地址：

```powershell
cd C:\Users\58229\Desktop\stock_web
$key=Join-Path $env:USERPROFILE '.ssh\id_ed25519_gitee_stock_web'
$token=ssh -i $key -o BatchMode=yes ubuntu@119.91.47.141 'set -a; . /home/ubuntu/stock_web/backend/.env >/dev/null 2>&1; printf %s "$API_ACCESS_TOKEN"'
.\scripts\build_mobile_lan_debug.ps1 -ApiBaseUrl 'http://119.91.47.141' -ApiAccessToken $token
adb install -r mobile_app\build\app\outputs\flutter-apk\app-debug.apk
```

如果后续改回局域网调试，再明确传局域网地址。不要裸跑 `flutter build apk --debug`，否则真机可能回退到 `127.0.0.1:8000` 或缺少 API token。

## 3. 当前 FutuOpenD 状态

2026-05-25 已在云服务器本机部署命令行 FutuOpenD，并使用富途账号 ID 登录成功。

当前状态：

- systemd 服务：`futu-opend`
- OpenD 安装目录：`/opt/futu-opend`
- 本机配置文件：`/etc/futu-opend/FutuOpenD.xml`
- API 监听：`127.0.0.1:11111`
- telnet 运维口：`127.0.0.1:22222`
- 后端 `.env`：`FUTU_HOST=127.0.0.1`、`FUTU_PORT=11111`、`FUTU_CONNECT_TIMEOUT_SECONDS=2`
- 已验证：`http://119.91.47.141/api/v1/futu/health` 返回 `status=ok`、`program_status_type=READY`
- 已验证：`/api/v1/futu/quote?code=HK.00700` 可返回真实行情

安全边界：

- FutuOpenD 的 `11111` 和 `22222` 端口只允许监听 `127.0.0.1`。
- UFW 应只开放必要端口，例如 `22/tcp`、`80/tcp`、`443/tcp`；不得开放 `11111`、`22222`、`5432` 到公网。
- 不要把 `/etc/futu-opend/FutuOpenD.xml` 提交到 Git；该文件包含本机登录配置。
- 不要把富途账号密码、`.env`、数据库密码或 SSH 私钥写入文档、聊天记录和 Git。

若 App 后续再次显示 Futu 不可用，优先检查：

```bash
systemctl status futu-opend --no-pager
sudo ss -ltnp | grep -E ':(11111|22222)'
curl -sS http://127.0.0.1:8000/api/v1/futu/health
curl -sS http://119.91.47.141/api/v1/futu/health
```

## 4. Futu 维护方案

当前采用方案：

1. 保持 Flutter 只连接 FastAPI，不直接连接 FutuOpenD。
2. 在 `.env` 中配置：

```env
FUTU_HOST=127.0.0.1
FUTU_PORT=11111
FUTU_CONNECT_TIMEOUT_SECONDS=2
```

3. FutuOpenD 放云服务器本机，并由 `futu-opend` systemd 服务托管。
4. 不要把 `11111` 端口直接暴露到公网。
5. Nginx、云防火墙和 UFW 只开放必要端口：当前建议 `22`、`80`、`443`。

### 4.1 云服务器本机 FutuOpenD 安装步骤

如需重装或迁移，可重新使用安装脚本。FutuOpenD 必须只监听本机地址：

```text
127.0.0.1:11111
```

执行顺序：

```bash
cd /home/ubuntu/stock_web
git pull --ff-only
bash scripts/deploy_backend.sh
```

从富途官方 OpenAPI 文档下载 Ubuntu 命令行 OpenD 压缩包，上传到服务器，例如：

```bash
/tmp/FutuOpenD_Ubuntu.tar.gz
```

安装 systemd 服务：

```bash
cd /home/ubuntu/stock_web
FUTU_OPEND_ARCHIVE=/tmp/FutuOpenD_Ubuntu.tar.gz bash scripts/install_futu_opend_ubuntu.sh
```

安装脚本会：

- 将 OpenD 文件放到 `/opt/futu-opend`。
- 将本机配置文件放到 `/etc/futu-opend/FutuOpenD.xml`。
- 创建 `futu-opend` systemd 服务。
- 让 OpenD API 口只监听 `127.0.0.1:11111`，运维命令口只监听 `127.0.0.1:22222`。
- 确保后端 `.env` 中有 `FUTU_HOST=127.0.0.1`、`FUTU_PORT=11111`、`FUTU_CONNECT_TIMEOUT_SECONDS=2`。

随后在服务器本机编辑：

```bash
sudo nano /etc/futu-opend/FutuOpenD.xml
```

只在该服务器本地配置富途登录账号和 `login_pwd_md5` 或 `login_pwd`。不要把该文件提交到 Git，不要把账号密码写入文档或聊天记录。

也可以使用仓库脚本交互配置。脚本会隐藏读取明文密码，在服务器本机计算 MD5，并只写入 `login_pwd_md5`：

```bash
cd /home/ubuntu/stock_web
bash scripts/configure_futu_opend_login.sh
```

启动并验证：

```bash
sudo systemctl enable --now futu-opend
sudo systemctl status futu-opend --no-pager
sudo ss -ltnp | grep -E ':(11111|22222)'
sudo systemctl restart stock-web-backend
curl -sS http://127.0.0.1:8000/api/v1/futu/health
curl -sS http://119.91.47.141/api/v1/futu/health
```

`ss` 结果必须确认 FutuOpenD 只监听 `127.0.0.1:11111` 和 `127.0.0.1:22222`，不能出现 `0.0.0.0:11111`、`0.0.0.0:22222` 或公网网卡地址监听。若出现公网监听，立即停止服务并修正配置：

```bash
sudo systemctl stop futu-opend
sudo nano /etc/futu-opend/FutuOpenD.xml
```

可额外加 UFW 兜底：

```bash
sudo ufw deny 11111/tcp
sudo ufw status verbose
```

## 5. 本地到服务器发布流程

本地开发完成后：

```powershell
cd C:\Users\58229\Desktop\stock_web
git status --short
git add .
git commit -m "message"
git push origin master
```

服务器更新：

```bash
cd /home/ubuntu/stock_web
git pull
bash scripts/deploy_backend.sh
curl -sS http://127.0.0.1/health
curl -sS http://119.91.47.141/health
```

如果变更了数据库结构，先确认迁移或初始化逻辑，再重启服务。

### 5.1 公网 API 访问保护

后端支持通过服务器 `.env` 中的 `API_ACCESS_TOKEN` 启用简单 token 保护：

```env
API_ACCESS_TOKEN=change-me
```

启用后：

- `/` 和 `/health` 保持公开，用于 Nginx、部署脚本和基础监控。
- `/api/v1/*` 必须携带 `Authorization: Bearer <token>` 或 `X-API-Token: <token>`。
- Flutter App 通过 `--dart-define=API_ACCESS_TOKEN=...` 注入 token，由 `ApiClient` 统一添加请求头。
- 不要把真实 token 写入 Git、文档、聊天记录或脚本默认值。

服务器检查示例：

```bash
curl -sS http://119.91.47.141/health
curl -sS http://119.91.47.141/api/v1/futu/health
curl -sS -H "Authorization: Bearer $API_ACCESS_TOKEN" http://119.91.47.141/api/v1/futu/health
```

App 云端 debug 包构建示例：

```powershell
.\scripts\build_mobile_lan_debug.ps1 -ApiBaseUrl http://119.91.47.141 -ApiAccessToken $env:STOCK_WEB_API_TOKEN
```

### 5.2 域名与 HTTPS 当前状态

当前域名状态：

- `devinstock.cloud` A 记录指向 `119.91.47.141`。
- `www.devinstock.cloud` A 记录指向 `119.91.47.141`。
- Nginx 已配置域名站点。
- Let's Encrypt 证书已签发，当前到期日为 `2026-08-24`。
- App 暂时仍使用 `http://119.91.47.141`，等真机和普通外网验证 HTTPS 后再切换。

验证命令：

```bash
curl -i http://119.91.47.141/health
curl -i https://devinstock.cloud/health
sudo nginx -t
systemctl status certbot.timer --no-pager
```

带 token 的业务接口验证不要把 token 写入共享文档，可在服务器上临时读取 `.env` 后执行。

### 5.3 2026-05-26 云端回测修复记录

云端量化回测出现 `Internal Server Error` 时，根因不是 PostgreSQL 服务不可用，也不是回测引擎整体坏掉，而是 K 线查询在 PostgreSQL 下使用了未命名子查询。PostgreSQL 要求 `FROM (...) AS alias`。

已修复文件：

```text
backend/app/repositories/market_data.py
```

接手后继续复测：

- 启动回测不再 500。
- 回测历史点击可以打开。
- 历史详情里的买卖操作和对应 K 线图可以正常加载。
- 若某策略没有交易，先判断是否是策略语义导致。

### 5.4 2026-05-26 数据导入与回归验证记录

本轮以用户最新券商截图为准重建股票持仓，云端 PostgreSQL 仍是事实数据源，本地旧库不要当主库。

已完成：

- 美股持仓替换为 `US.AMUU`、`US.GGLL`、`US.LINT`、`US.MUU`、`US.NVDA`、`US.TQQQ`，旧美股持仓已移除。
- 港股持仓替换为 `HK.01398`、`HK.02318`、`HK.09988`、`HK.25956`、`HK.26393`、`HK.26739`、`HK.26987`、`HK.28607`，旧港股持仓已移除。
- Futu 行情和持仓快照已刷新；港股总市值 `HK$ 66,414`、持仓盈亏 `HK$ -1,864` 已与截图口径核对。
- 基金模块已复测：基金列表、基金详情、交易记录、持仓修正、收益曲线、策略参考净值/日期当前无阻塞问题。
- 量化模块已复测：云端回测不再 500，历史详情可返回买卖操作、收益曲线和对应 K 线数据。
- 真机 UI 修复：`4ddbc3f` 已修复回测历史参数区在小屏/大字体下的底部溢出。
- 美股扩展行情可行性：云端 FutuOpenD 实测 `get_market_snapshot` 对 `US.NVDA`、`US.AMUU` 返回 `pre_*`、`after_*`、`overnight_*` 字段，可用于盘前、盘后和夜盘行情展示。

注意：

- `HK.28607` 等认股证的当日盈亏可能与券商截图存在口径差异，当前后端按 `持仓数量 * (现价 - 昨收)` 计算；券商可能按当日买入、交易费用和账户实时口径计算。
- 后续接入 AI、大图标替换、美股盘前盘后行情时，仍必须保持 Flutter 只访问 FastAPI，不直接连接 FutuOpenD 或第三方模型服务。

## 6. 服务器待确认事项

下一位开发者接手后优先确认：

1. `stock-web-backend` 是否开机自启并正常运行。
2. Nginx 是否仍能访问 `http://119.91.47.141/health`。
3. PostgreSQL 备份 timer 是否安装并生成备份。
4. UFW 和腾讯云防火墙是否只开放必要端口。
5. 服务器 `.env` 是否只存在服务器本地，且没有进入 Git。
6. `futu-opend` 是否 active，且 `11111`、`22222` 是否只监听 `127.0.0.1`。
7. 数据库密码是否需要轮换；此前调试中密码曾在聊天中出现，生产使用前建议重置。
8. 如用户反馈“数据变了”，先确认后端仍连接云端 `stock_web`，并核对是否误连旧库 `stock_web_before_migration_20260525_183135` 或本地开发库。

检查命令：

```bash
systemctl status stock-web-backend --no-pager
systemctl status futu-opend --no-pager
systemctl status nginx --no-pager
systemctl status postgresql --no-pager
systemctl list-timers | grep stock-web
ls -lh /home/ubuntu/stock_web_backups
sudo ufw status verbose
sudo ss -ltnp | grep -E ':(80|8000|11111|22222|5432)'
```

## 7. 下一步开发顺序

1. 先实现 App 大模型 AI 后端网关，采用后端代理和服务端密钥管理，Flutter 不直连模型厂商。
2. 替换 App 图标，优先用统一源图生成 Android 多尺寸 launcher icon。
3. 实现美股盘前盘后行情展示，优先做后端缓存轮询，后续再评估实时推送通道。
4. 备案和真机 HTTPS 验证完成后，再把 App API 从 `http://119.91.47.141` 切到 `https://devinstock.cloud`。
5. 后续补用户登录鉴权、限流、日志告警和备份恢复演练。

## 8. 交接提醒

- 不要把 `.env`、数据库密码、SSH 私钥提交到仓库。
- 不要在服务器上手改业务代码后忘记同步回 Git；长期维护以本地开发 -> Git -> 服务器 pull/deploy 为准。
- 每次改后端后至少跑 `python -m compileall app` 和相关 pytest。
- 每次改 Flutter 后至少跑 `flutter analyze` 和相关测试。
- 需要真机验证时再截图观察；用户平时会自己检查界面。
