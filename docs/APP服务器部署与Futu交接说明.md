# App 服务器部署与 Futu 交接说明

最后更新：2026-05-25

本文记录最近一次从局域网调试切到云服务器后的交接状态。若本文与早期“局域网真机调试”说明冲突，以本文为准。

## 1. 当前服务器基线

- 云服务器：腾讯云轻量应用服务器，广州，Ubuntu 22.04.5 LTS。
- 公网 API：`http://119.91.47.141`
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
- 迁移后关键表数量：`positions=6`、`fund_positions=1`、`fund_trades=3`、`klines=10367`、`strategy_monitors=1`、`signal_events=36`、`backtest_runs=4`、`notification_devices=11`、`push_records=92`
- 迁移后 API 验证：`/health=200`、无 token `/api/v1/positions=401`、带 token `/api/v1/positions` 返回 6 条、带 token `/api/v1/funds/positions` 返回 1 条。

本地最近功能基线：

```text
dcdce44 feat: protect public api with token
7d1797b chore: add futu opend login config helper
518d8e2 chore: enable local futu opend telnet control
```

## 2. 当前 App 连接方式

当前真机 APK 已改为连接云服务器，而不是电脑局域网 IP。

重新构建 APK 时必须显式指定服务器地址：

```powershell
cd C:\Users\58229\Desktop\stock_web\mobile_app
D:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://119.91.47.141
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

如果后续改回局域网调试，再使用 `scripts/build_mobile_lan_debug.ps1`。不要裸跑 `flutter build apk --debug`，否则真机可能回退到 `127.0.0.1:8000`。

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
- UFW 只开放 `22/tcp` 和 `80/tcp`。
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
5. Nginx、云防火墙和 UFW 只开放必要端口：当前建议 `22`、`80`，后续上 HTTPS 后开放 `443`。

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

1. 公网 API 已加简单 token 保护，下一步购买或绑定域名后配置 HTTPS。
2. 没有 HTTPS 前不要把更敏感的功能开放给陌生网络。
3. 持续真机验证云端 App：基金主页、基金详情、基金交易记录、基金提醒 scheduler、股票持仓缓存展示。
4. 股票实时行情已恢复，继续回归股票搜索、K 线刷新、资金流向、单股策略监控和信号扫描。
5. 继续完善基金历史记录迁移：按养基宝规则核对历史买入/卖出日期、三点前后确认日、费率、份额和成本净值重建。

## 8. 交接提醒

- 不要把 `.env`、数据库密码、SSH 私钥提交到仓库。
- 不要在服务器上手改业务代码后忘记同步回 Git；长期维护以本地开发 -> Git -> 服务器 pull/deploy 为准。
- 每次改后端后至少跑 `python -m compileall app` 和相关 pytest。
- 每次改 Flutter 后至少跑 `flutter analyze` 和相关测试。
- 需要真机验证时再截图观察；用户平时会自己检查界面。
