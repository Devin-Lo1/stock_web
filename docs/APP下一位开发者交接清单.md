最后更新：2026-05-26

# APP 下一位开发者交接清单

这份文档是新的开发者接手时的第一张作战图。先读 `docs/README.md`、`docs/APP开发强约束规范.md`、`docs/APP新开发者接手指南.md`，再按本文检查环境。

## 1. 当前一句话状态

App 已迁到腾讯云公网后端，云端 PostgreSQL 是事实数据源，FutuOpenD 已在云服务器本机接入，公网 API 已加 token，域名 HTTPS 已在服务器侧初配但 App 暂未切换域名。

## 2. 当前基线

- 最新提交：`4ddbc3f fix: prevent quant parameter overflow`
- 仓库：`git@gitee.com:luo-dewen/stock_web.git`
- 本地路径：`C:\Users\58229\Desktop\stock_web`
- 服务器路径：`/home/ubuntu/stock_web`
- 当前 App API：`http://119.91.47.141`
- 域名：`devinstock.cloud`、`www.devinstock.cloud`
- 后端服务：`stock-web-backend`
- 行情服务：`futu-opend`
- 数据库：云端 PostgreSQL
- 服务器链路：`Nginx -> FastAPI -> PostgreSQL`

## 2.1 2026-05-26 最新数据和验证状态

- 美股持仓已按用户截图替换，当前云端保留 `US.AMUU`、`US.GGLL`、`US.LINT`、`US.MUU`、`US.NVDA`、`US.TQQQ`；导入前备份为 `/home/ubuntu/stock_web_backups/stock_web_20260526_165323.dump`。
- 港股持仓已按用户截图替换为 8 个标的；导入前备份为 `/home/ubuntu/stock_web_backups/stock_web_20260526_172741.dump`。当前港股总市值 `HK$ 66,414`、持仓盈亏 `HK$ -1,864` 已按截图口径核对。
- FutuOpenD 已在云服务器本机刷新美股和港股行情快照；`11111`、`22222` 仍禁止暴露公网。
- 基金模块已复测：基金列表、基金详情、交易记录、持仓修正、收益曲线、策略参考净值/日期当前无阻塞问题。
- 量化模块已复测：云端回测不再 500，历史详情可返回买卖操作、收益曲线和对应 K 线数据。
- 当前新增评估结论：App 可通过后端代理接入大模型 AI 渠道；Android 图标当前使用 `@mipmap/ic_launcher`，可替换；Futu `get_market_snapshot` 已确认可返回美股盘前、盘后和夜盘字段。

## 3. 接手后先执行

本地：

```powershell
cd C:\Users\58229\Desktop\stock_web
git status --short
git rev-parse --short HEAD
```

服务器：

```bash
cd /home/ubuntu/stock_web
git status --short
git rev-parse --short HEAD
systemctl status stock-web-backend --no-pager
systemctl status nginx --no-pager
systemctl status postgresql --no-pager
systemctl status futu-opend --no-pager
sudo ss -ltnp | grep -E ':(80|443|8000|11111|22222|5432)\b'
```

预期：

- 后端、Nginx、PostgreSQL、FutuOpenD 都应 active。
- 80/443 可公网访问。
- 8000 应只在本机或 Nginx 后面使用。
- 11111/22222/5432 不应暴露公网。

## 4. 关键安全要求

- 不要提交 `.env`、数据库密码、SSH 私钥、Futu 账号密码、API token。
- 不要把 API token 写进文档、聊天、脚本默认值或 Git 历史。
- FutuOpenD 的 11111 API 端口和 22222 telnet 端口禁止直接暴露公网。
- 服务器业务代码只能通过 Git 更新。
- 云端 PostgreSQL 是当前真实数据源，不要再把本地旧库当主库。

## 5. App 构建

当前 App 仍使用 HTTP IP。构建时从服务器临时读取 token 注入：

```powershell
cd C:\Users\58229\Desktop\stock_web
$key=Join-Path $env:USERPROFILE '.ssh\id_ed25519_gitee_stock_web'
$token=ssh -i $key -o BatchMode=yes ubuntu@119.91.47.141 'set -a; . /home/ubuntu/stock_web/backend/.env >/dev/null 2>&1; printf %s "$API_ACCESS_TOKEN"'
.\scripts\build_mobile_lan_debug.ps1 -ApiBaseUrl 'http://119.91.47.141' -ApiAccessToken $token
```

域名 HTTPS 验证完成后，才把 `ApiBaseUrl` 改为 `https://devinstock.cloud`。

## 6. 当前重点验证

量化：

- 已云端复测 `HK.09988`、`HK.01398` 从 `2025/01/01` 到 `2026/05/26` 回测完成，历史详情能返回买卖操作和 K 线数据。
- 后续如继续验证 `HK.02628`，重点确认详情页真机展示效果，不再把 500 当成当前阻塞。
- ATR “仅止损”如果从空仓开始没有交易，先判断策略语义，不要直接改成隐式持仓。

基金：

- 已复测基金列表、基金详情、交易记录、持仓修正、收益曲线、策略参考净值/日期。
- 继续遵守原语义：基金业绩走势是基金自身净值曲线，我的收益页才展示用户持仓收益曲线。
- 加仓、减仓、修正持仓只能影响用户持仓、收益、策略参考点，不能影响基金自身净值走势。
- 当日收益如果是估算值，界面用小圆圈“估”标记；正式净值更新后去掉。

## 7. 最近修复点

- `9d11684`：接入美股盘前、盘后、夜盘扩展行情字段，并在 App 持仓列表按时段显示小字。
- `4ddbc3f`：修复回测历史参数区在真机小屏/大字体下的底部溢出。
- `a92a987`：修复云端量化 K 线查询在 PostgreSQL 下缺少子查询别名导致的 500。
- `2f6c48f`：基金当日估算收益增加小圆圈“估”标识。
- `c4611e2`：基金持仓按正式净值估值，避免加减仓污染基金自身收益走势。
- `06a0e04`：基金下一参考日期显示完整。
- `7b56dd2`：基金业绩走势加载完整历史，不只显示最近几条。

## 8. 下一步建议

1. 先做 App 的大模型 AI 后端网关，密钥只能放服务端 `.env`，Flutter 不直连模型厂商。
2. App 图标已按用户提供原图替换，后续如再换图，沿用统一源图生成 Android 各尺寸图标的方式。
3. 继续真机验证美股收盘后和盘前的小字显示效果。
4. 备案和真机 HTTPS 验证完成后，再把 App API 从 `http://119.91.47.141` 切到 `https://devinstock.cloud`。
5. 后续补用户登录鉴权、限流、日志告警和备份恢复演练。
