# Flutter安卓环境准备

## 目标

在本机准备 Flutter 安卓开发环境，确保可以运行：

```powershell
flutter doctor
flutter create mobile_app
flutter run
```

## 1. 安装 Flutter SDK

推荐安装到：

```text
C:\src\flutter
```

安装步骤：

```text
1. 下载 Flutter Windows SDK
2. 解压到 C:\src\flutter
3. 将 C:\src\flutter\bin 加入系统 PATH
4. 重新打开 PowerShell
5. 执行 flutter --version
```

验证命令：

```powershell
flutter --version
```

## 2. 安装 Android Studio

需要安装：

```text
1. Android Studio
2. Android SDK
3. Android SDK Platform
4. Android SDK Command-line Tools
5. Android Emulator，可选
```

如果使用安卓真机，可以暂时不配置模拟器。

## 3. 检查环境

执行：

```powershell
flutter doctor
```

至少需要通过：

```text
Flutter
Android toolchain
Connected device 或 Android emulator
```

如果提示 Android licenses 未接受，执行：

```powershell
flutter doctor --android-licenses
```

一路输入：

```text
y
```

## 4. 创建本项目 Flutter App

回到项目根目录：

```powershell
cd C:\Users\58229\Desktop\stock_web
```

当前 `mobile_app` 目录只有 README。创建 Flutter 工程时，如果 Flutter 提示目录已存在，可以先让 Codex 帮你处理，或手动删除该 README 后执行：

```powershell
flutter create mobile_app
```

进入目录：

```powershell
cd mobile_app
```

运行：

```powershell
flutter run
```

## 5. 第一阶段只验证安卓

本项目第一周只要求：

```text
1. 安卓模拟器或安卓真机能运行 Flutter 默认 Demo
2. App 能访问本机 FastAPI 后端
3. 后续再接 Firebase 推送
```

如果使用安卓真机访问本机后端，后端地址不能写 `127.0.0.1`，需要写电脑局域网 IP，例如：

```text
http://192.168.x.x:8000
```

如果使用 Android 模拟器访问电脑本机后端，通常使用：

```text
http://10.0.2.2:8000
```

