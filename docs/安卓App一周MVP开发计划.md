# 安卓App一周MVP开发计划

## 1. 项目目标

基于现有《智能量化交易APP技术方案文档》，第一阶段优先开发安卓手机App，并打通最关键的业务闭环：

```text
后端24小时运行 -> 获取富途行情 -> 计算持仓盈亏 -> 生成策略信号 -> 推送到安卓手机 -> App展示持仓和信号
```

第一周目标不是完成完整量化交易系统，而是做出一个可以在安卓手机上运行、能接收消息、能查看基础数据的MVP版本。

## 2. 第一周MVP功能范围

必须完成：

```text
1. 安卓App基础框架
2. 登录或本地用户标识，可先极简
3. 手动录入持仓
4. 查看持仓列表
5. 查看实时行情和盈亏
6. 查看交易信号列表
7. 后端获取富途行情
8. 后端生成简单策略信号
9. 后端向安卓手机发送推送通知
```

暂时不做：

```text
1. 自动交易
2. iOS版本
3. 复杂用户权限系统
4. 多用户商业化运营
5. 复杂策略市场
6. 完整回测系统
7. 高级图表分析
8. 订单同步工银智投
```

## 3. 最优技术栈

### 3.1 安卓App

推荐：

```text
Flutter + Dart
```

核心依赖：

```text
flutter
provider 或 riverpod
dio
firebase_messaging
flutter_local_notifications
shared_preferences
flutter_secure_storage
fl_chart
intl
```

第一周建议：

```text
状态管理：Provider
网络请求：Dio
推送：Firebase Cloud Messaging
本地通知展示：flutter_local_notifications
本地存储：shared_preferences + flutter_secure_storage
图表：第一周可选，优先做数字和列表
```

选择Flutter的原因：

```text
1. 后续可以扩展到iOS
2. UI开发速度快
3. Hot Reload可以边看效果边改页面
4. 适合金融类App的复杂列表、卡片、图表
5. 推送、网络请求、本地存储生态成熟
```

### 3.2 后端

推荐：

```text
Python 3.11+
FastAPI
SQLAlchemy 或 SQLModel
PostgreSQL
APScheduler
futu-api
Firebase Admin SDK
Docker Compose
```

第一周建议先不用Celery：

```text
APScheduler足够完成定时获取行情、计算信号、发送推送。
Celery可以等任务复杂后再引入。
```

第一周Redis可选：

```text
如果开发时间紧，可以先不用Redis。
行情缓存先放内存或数据库。
后续需要更高并发和缓存时再加入Redis。
```

### 3.3 数据库

推荐：

```text
PostgreSQL
```

理由：

```text
1. 和后续正式服务端一致
2. 支持结构化持仓、信号、通知记录
3. 迁移到云服务器方便
4. 比SQLite更接近最终架构
```

本地开发建议：

```text
Docker Compose启动PostgreSQL
```

### 3.4 行情数据

使用：

```text
FutuOpenD + futu-api
```

必须优先验证：

```text
1. FutuOpenD是否能正常启动
2. 后端是否能连接FutuOpenD
3. 是否能获取港股实时行情
4. 是否能获取K线数据
5. 是否具备对应市场行情权限
6. 是否能稳定订阅或定时拉取行情
```

### 3.5 手机推送

安卓第一阶段推荐：

```text
Firebase Cloud Messaging
```

原因：

```text
1. Flutter支持成熟
2. 安卓推送接入相对直接
3. 后端可以通过Firebase Admin SDK发送消息
4. 适合验证“后端触发 -> 手机收到通知”的核心链路
```

注意：

```text
在国内安卓机型上，FCM可能受系统和网络环境影响。
第一周建议先用可访问FCM的测试环境或模拟器验证。
后续如果面向国内用户，可能需要接入厂商推送，例如华为、小米、OPPO、vivo。
```

## 4. 系统架构

第一周MVP架构：

```text
Flutter安卓App
  |
  | HTTPS
  v
FastAPI后端
  |
  | futu-api
  v
FutuOpenD
  |
  v
富途行情数据

FastAPI后端
  |
  | Firebase Admin SDK
  v
Firebase Cloud Messaging
  |
  v
安卓手机通知
```

后端负责：

```text
1. 持仓API
2. 行情获取
3. 盈亏计算
4. 策略信号计算
5. 推送通知
6. 数据库存储
```

App负责：

```text
1. 持仓录入
2. 持仓展示
3. 盈亏展示
4. 信号展示
5. 接收推送
6. 基础设置
```

## 5. 当前需要完成的预备工作

### 5.1 Flutter安卓开发环境

需要安装：

```text
Flutter SDK
Android Studio
Android SDK
Android模拟器，或安卓真机
VS Code Flutter插件，或Android Studio Flutter插件
Git
```

检查命令：

```powershell
flutter doctor
```

第一周至少要保证：

```text
1. Flutter可运行
2. Android toolchain正常
3. 能启动模拟器或连接真机
4. 能运行Flutter默认Demo
```

### 5.2 Firebase推送准备

需要准备：

```text
1. Firebase项目
2. Android应用包名
3. google-services.json
4. Firebase Cloud Messaging开启
5. 后端Firebase Admin SDK凭据
```

第一阶段验证目标：

```text
后端发送一条测试消息，安卓手机能收到通知。
```

### 5.3 富途API准备

需要准备：

```text
1. 富途账号
2. FutuOpenD
3. futu-api Python SDK
4. 港股行情权限
```

需要先验证：

```text
1. 获取HK.02318实时行情
2. 获取HK.00700实时行情
3. 获取日K数据
4. 测试行情订阅或定时拉取
```

如果富途API没有先跑通，不建议直接开始写复杂App页面。

### 5.4 后端开发环境

需要安装：

```text
Python 3.11+
Docker Desktop
PostgreSQL客户端，可选DBeaver
VS Code或PyCharm
```

建议依赖：

```text
fastapi
uvicorn
sqlalchemy
psycopg
pydantic
python-dotenv
apscheduler
futu-api
firebase-admin
```

### 5.5 股票代码格式

统一使用富途格式：

```text
HK.02318
HK.00700
US.AAPL
```

不要混用：

```text
02318.HK
00700.HK
```

### 5.6 涨跌颜色规则

建议按港股/国内用户习惯：

```text
红色 = 上涨/盈利
绿色 = 下跌/亏损
灰色 = 持平/无数据
```

## 6. 推荐项目目录

建议结构：

```text
stock_web/
  docs/
  backend/
    app/
      main.py
      config.py
      database.py
      models.py
      schemas.py
      api/
        positions.py
        quotes.py
        signals.py
        notifications.py
      services/
        futu_service.py
        position_service.py
        strategy_service.py
        push_service.py
      tasks/
        scheduler.py
    tests/
    requirements.txt
    Dockerfile
    docker-compose.yml
    .env.example
  mobile_app/
    lib/
      main.dart
      config/
      models/
      services/
      providers/
      screens/
      widgets/
      utils/
    pubspec.yaml
  完整技术方案文档.md
  安卓App一周MVP开发计划.md
```

## 7. MVP数据库设计

### 7.1 users表

第一周可以极简：

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    device_token TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 7.2 positions表

```sql
CREATE TABLE positions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    stock_code VARCHAR(20) NOT NULL,
    stock_name VARCHAR(100),
    quantity NUMERIC(18, 4) NOT NULL,
    cost_price NUMERIC(18, 4) NOT NULL,
    buy_date DATE,
    platform VARCHAR(100) DEFAULT '工银智投',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 7.3 signals表

```sql
CREATE TABLE signals (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    stock_code VARCHAR(20) NOT NULL,
    signal_type VARCHAR(50) NOT NULL,
    signal_text TEXT,
    price NUMERIC(18, 4),
    strength VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    notified BOOLEAN DEFAULT FALSE
);
```

### 7.4 notifications表

```sql
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    signal_id INTEGER REFERENCES signals(id),
    sent_at TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

## 8. 7天开发计划

### 第1天：环境和富途行情验证

目标：

```text
1. 创建backend项目
2. 创建mobile_app Flutter项目
3. 跑通Flutter安卓Demo
4. 启动FutuOpenD
5. 后端连接futu-api
6. 获取HK.02318或HK.00700实时行情
7. 获取K线数据
```

验收标准：

```text
后端命令行能打印股票代码、现价、涨跌幅、行情时间。
Flutter Demo能在安卓模拟器或真机运行。
```

### 第2天：后端基础API和数据库

目标：

```text
1. FastAPI项目启动
2. PostgreSQL启动
3. 建立users、positions、signals、notifications表
4. 实现持仓增删改查API
5. 实现行情查询API
```

验收标准：

```text
通过Swagger或Postman可以添加持仓、查询持仓、查询行情。
```

### 第3天：Flutter基础页面

目标：

```text
1. App基础导航
2. 首页仪表盘
3. 持仓列表页
4. 添加持仓页
5. 信号列表页
6. 接入Dio请求后端API
```

页面建议：

```text
首页：总资产、总盈亏、今日盈亏、最新信号
持仓页：股票名称、代码、数量、成本价、现价、盈亏
信号页：信号类型、股票、价格、时间、状态
设置页：后端地址、推送状态、行情状态
```

验收标准：

```text
安卓App可以从后端读取并展示持仓列表。
```

### 第4天：策略信号

目标：

```text
1. 后端获取历史K线
2. 计算MA5和MA20
3. 生成BUY_WATCH和SELL_WATCH信号
4. 保存信号记录
5. App展示信号列表
```

第一周策略：

```text
MA5上穿MA20：BUY_WATCH
MA5下穿MA20：SELL_WATCH
盈利超过指定比例：TAKE_PROFIT
亏损超过指定比例：STOP_LOSS
```

验收标准：

```text
后端能为持仓股票生成信号，App能看到信号。
```

### 第5天：Firebase推送

目标：

```text
1. Flutter接入firebase_messaging
2. 获取安卓设备token
3. 将device_token上传后端
4. 后端接入Firebase Admin SDK
5. 后端发送测试推送
6. App前台/后台接收通知
```

验收标准：

```text
后端触发测试接口后，安卓手机可以收到通知。
```

### 第6天：自动任务和完整闭环

目标：

```text
1. 使用APScheduler定时获取行情
2. 定时计算策略信号
3. 新信号自动发送推送
4. 避免同一信号重复通知
5. App刷新后展示最新信号
```

建议频率：

```text
行情刷新：5-15秒，MVP可放宽
策略计算：1-5分钟
信号推送：只推送新信号
```

验收标准：

```text
持仓股票触发新信号后，后端自动保存信号并推送到安卓手机。
```

### 第7天：联调、优化和部署准备

目标：

```text
1. 修复App页面显示问题
2. 优化涨跌颜色和数字格式
3. 增加加载、空数据、错误状态
4. 整理.env.example
5. 整理README
6. 后端准备Docker Compose
7. 完成一次完整端到端测试
```

验收标准：

```text
从录入持仓到接收信号推送，完整流程可以跑通。
```

## 9. App界面建议

### 9.1 首页

内容：

```text
总资产
总盈亏
今日盈亏
持仓数量
最新信号
行情连接状态
```

设计原则：

```text
1. 数字清晰
2. 红绿颜色统一
3. 不要做复杂装饰
4. 优先可读性
```

### 9.2 持仓页

每条持仓展示：

```text
股票名
股票代码
数量
成本价
现价
盈亏金额
盈亏比例
最新信号
```

### 9.3 添加持仓页

字段：

```text
股票代码
股票名称
数量
成本价
买入日期
平台
```

### 9.4 信号页

展示：

```text
信号类型
股票代码
触发价格
信号说明
触发时间
是否已通知
```

### 9.5 设置页

展示：

```text
后端API地址
推送Token状态
富途行情状态
版本号
免责声明
```

## 10. 风险和处理建议

### 10.1 FCM国内可用性

风险：

```text
部分国内安卓设备可能无法稳定接收FCM。
```

处理：

```text
第一周先验证技术闭环。
后续如面向国内用户，再接入厂商推送。
```

### 10.2 富途行情权限

风险：

```text
没有对应行情权限时，实时数据可能不可用或受限。
```

处理：

```text
第一天必须先验证富途API。
如果权限不足，先用延迟行情或模拟数据开发App。
```

### 10.3 手机后台运行误区

说明：

```text
安卓App不应该承担24小时行情监听和策略计算。
24小时运行应由后端服务器负责。
手机App只负责展示和接收系统推送。
```

### 10.4 一周开发范围控制

风险：

```text
同时做行情、后端、App、推送，时间很紧。
```

处理：

```text
优先完成闭环，不追求复杂页面。
先做列表和数字，图表后置。
```

## 11. 最终推荐的一周MVP组合

```text
安卓App：Flutter + Provider + Dio + firebase_messaging
后端：FastAPI + PostgreSQL + APScheduler + futu-api
推送：Firebase Cloud Messaging
部署：本地开发优先，后续Docker Compose上云
策略：MA5/MA20 + 止盈止损阈值
```

## 12. 第一周最重要的验收结果

只要第一周完成下面这条链路，项目就是成功的：

```text
在安卓App录入持仓
  -> 后端保存持仓
  -> 后端获取富途行情
  -> 后端计算盈亏和策略信号
  -> 后端发送推送
  -> 安卓手机收到通知
  -> App内可以查看信号记录
```

这个闭环跑通后，再继续开发iOS、复杂图表、多策略、云部署和长期监控。

