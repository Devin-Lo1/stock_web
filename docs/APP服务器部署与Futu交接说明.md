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
- 备份脚本：
  - `scripts/backup_postgres.sh`
  - `scripts/install_postgres_backup_timer.sh`
  - 备份目录：`/home/ubuntu/stock_web_backups`

本地最近功能基线：

```text
2f0e13d chore: add server database backup scripts
2de2e0b chore: add backend deploy helper
255e127 feat: rebuild fund holdings from trade history
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

## 3. 为什么 App 显示 Futu 接口不可用

这是当前云端部署后的预期问题，不代表后端整体挂了。

原因：

- App 已连接云服务器。
- 后端 Futu 客户端默认连接 `FUTU_HOST=127.0.0.1`、`FUTU_PORT=11111`。
- 这表示云服务器会连接“云服务器本机”的 FutuOpenD。
- 当前云服务器没有运行 FutuOpenD，也没有配置可达的远程 FutuOpenD，所以 `/api/v1/futu/*`、股票实时行情刷新、K 线刷新、股票搜索和依赖新行情的策略扫描会提示 Futu 不可用。

不受影响的部分：

- `/health`
- PostgreSQL
- 持仓和基金数据库读写
- 场外基金数据源、基金净值、基金估算、基金提醒
- 已缓存行情的只读展示

## 4. Futu 后续方案

短期可接受方案：

- 云服务器先用于基金、数据库、App 远程访问和后端联调。
- 股票实时行情相关能力显示 Futu 不可用或使用缓存。

推荐方案：

1. 保持 Flutter 只连接 FastAPI，不直接连接 FutuOpenD。
2. 在 `.env` 中配置：

```env
FUTU_HOST=127.0.0.1
FUTU_PORT=11111
FUTU_CONNECT_TIMEOUT_SECONDS=2
```

3. 决定 FutuOpenD 放在哪里：
   - 放云服务器本机：需要确认 FutuOpenD 对当前系统的支持、登录方式和长期运行稳定性。
   - 放家里 Windows 电脑：用 Tailscale/WireGuard/SSH 隧道让云服务器访问它。
   - 独立行情节点：后续把 Futu 数据采集从 API 服务拆出去。
4. 不要把 `11111` 端口直接暴露到公网。
5. Nginx、云防火墙和 UFW 只开放必要端口：当前建议 `22`、`80`，后续上 HTTPS 后开放 `443`。

### 4.1 云服务器本机 FutuOpenD 安装步骤

当前优先方案是先尝试在云服务器本机运行命令行 FutuOpenD，并只监听本机地址：

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

## 6. 服务器待确认事项

下一位开发者接手后优先确认：

1. `stock-web-backend` 是否开机自启并正常运行。
2. Nginx 是否仍能访问 `http://119.91.47.141/health`。
3. PostgreSQL 备份 timer 是否安装并生成备份。
4. UFW 和腾讯云防火墙是否只开放必要端口。
5. 服务器 `.env` 是否只存在服务器本地，且没有进入 Git。
6. 数据库密码是否需要轮换；此前调试中密码曾在聊天中出现，生产使用前建议重置。

检查命令：

```bash
systemctl status stock-web-backend --no-pager
systemctl status nginx --no-pager
systemctl status postgresql --no-pager
systemctl list-timers | grep stock-web
ls -lh /home/ubuntu/stock_web_backups
sudo ufw status verbose
```

## 7. 下一步开发顺序

1. 先确认服务器基础链路：`health`、PostgreSQL、Nginx、systemd、备份、UFW。
2. 处理 FutuOpenD 远程方案：本机安装、隧道访问或独立行情节点三选一。
3. 增加后端访问保护：至少先加简单 token 或登录态，避免公网 API 被随便调用。
4. 购买或绑定域名后配置 HTTPS；没有 HTTPS 前不要把敏感功能开放给陌生网络。
5. 真机验证云端 App：基金主页、基金详情、基金交易记录、基金提醒 scheduler、股票持仓缓存展示。
6. 股票实时行情恢复后，再验证股票搜索、K 线刷新、资金流向、单股策略监控和信号扫描。
7. 继续完善基金历史记录迁移：按养基宝规则核对历史买入/卖出日期、三点前后确认日、费率、份额和成本净值重建。

## 8. 交接提醒

- 不要把 `.env`、数据库密码、SSH 私钥提交到仓库。
- 不要在服务器上手改业务代码后忘记同步回 Git；长期维护以本地开发 -> Git -> 服务器 pull/deploy 为准。
- 每次改后端后至少跑 `python -m compileall app` 和相关 pytest。
- 每次改 Flutter 后至少跑 `flutter analyze` 和相关测试。
- 需要真机验证时再截图观察；用户平时会自己检查界面。
