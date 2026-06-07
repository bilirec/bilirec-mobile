# bilirec-mobile

`bilirec-mobile` 是一个 Flutter Android 客户端，用于以前台服务方式托管 Bilirec 原生核心（`libbilirec.so`），并提供启动/停止、状态监控、输出路径配置以及基于 FFmpeg 的自动转档功能。

## 给非技术用户的使用方法

如果你只想直接使用，不关心开发环境，可以按下面三步操作：

1. 下载并安装 APK 到 Android 手机。
2. 打开应用，点击主界面的“启动”按钮，等待状态显示服务已运行。
3. 点击“打开录制应用程序”按钮，进入录制管理页面开始使用。

> 提示：首次使用时，系统可能会要求通知权限或电池优化相关授权，请按提示允许，否则后台服务可能无法稳定运行。

## 项目定位

- 主要目标：在 Android 上尽量稳定地保持 Bilirec 后台服务运行。
- 技术方案：Flutter UI + `flutter_foreground_task` 前台服务 + Dart FFI 调用原生动态库 + FFmpeg 视频转档。
- 当前平台：仅支持 Android（代码中已显式限制）。

## 主要功能

- 一键启动/停止 Bilirec 系统服务。
- 前台通知常驻，支持通知栏直接停止服务。
- 启动后周期性心跳检查本地后端（`http://127.0.0.1:8080/`）。
- 检查录制状态（`/record/list`），并在通知中显示“录制中”。
- 检测服务被系统中断时，发出高优先级本地提醒。
- 设置并持久化录制输出路径。
- **自动转档支持**：录制完成后自动转换为 MP4（通过 FFmpeg）。
  - 可配置转档策略：是否删除原始文件、是否在录制时允许背景转档。
  - 负载保护：支持限制“最高录制路数”以自动暂停背景转换，优先确保录制流畅。
- **诊断功能**：支持导出合并后的 `bootstrap.log` 启动日志以便排错。
- 可选启用 SSE 推送（替代 WebPush / FCM），由前台服务接收并转成本地通知。
- 内置中文繁体 / 简体切换（`zh_Hant` / `zh_Hans`）。

## 代码实现速览

### 1) 服务生命周期（`lib/main.dart`）

- `BilirecTaskHandler` 运行在前台任务隔离区，负责：
  - 调用 `BilirecService.start(...)` 启动原生核心。
  - 周期性发送心跳并检查后端可用性。
  - 更新通知内容（运行状态、CPU/RAM、录制状态）。
  - 在销毁时调用 `BilirecService.stop()`。
- UI 侧通过 `FlutterForegroundTask.addTaskDataCallback(...)` 接收任务事件并更新状态。

### 2) 原生核心与 FFmpeg 桥接（`lib/bilirec_service.dart`）

- 通过 FFI 加载 `libbilirec.so`（Android）。
- 原生核心 `libbilirec.so` 现在依赖于 FFmpeg (通过 `ffmpeg-kit-min` 集成)。
- 绑定原生符号：
  - `Start(char* configJson)`
  - `Stop()`
- 使用 JSON 传递启动参数：`basePath` + `env`（例如 `OUTPUT_DIR`、`CONVERT_TO_MP4`、`FFMPEG_ALLOW_DURING_RECORDING` 等）。
- 启用 SSE 推送时，启动会生成随机 token，通过 `env.NOTIFY_SSE_TOKEN` 传给核心，并连接 `GET /sse?token=...` 监听事件。

### 3) 资源监控与日志管理

- RAM：优先读取 `/proc/self/status` 的 `RssAnon`，失败时回退 `ProcessInfo.currentRss`。
- CPU：通过 `/proc/self/stat` 计算进程 CPU 近似占用。
- **日志合并**：在 `SettingsDrawerSheet` 中实现了将 `lumberjack` 轮转产生的多个 `bootstrap*.log` 分片合并导出的功能。

### 4) Android 清单与权限（`android/app/src/main/AndroidManifest.xml`）

已声明关键权限与前台服务配置，包括：

- `INTERNET`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_SPECIAL_USE`
- `POST_NOTIFICATIONS`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

并注册了 `flutter_foreground_task` 的 `ForegroundService`。

## 本地运行

### 前置条件

- 已安装 Flutter 与 Android 开发环境。
- Dart SDK 约束见 `pubspec.yaml`：`>=3.4.0 <4.0.0`。
- 设备建议使用真机（需要验证前台服务、电池优化行为与 FFmpeg 转档性能）。

### 启动项目

```powershell
flutter pub get
flutter run
```

## 原生库说明

项目已包含以下从 [bilirec](https://github.com/eric2788/bilirec) 取得的 ABI 的动态库：

- `android/app/src/main/jniLibs/arm64-v8a/libbilirec.so`
- `android/app/src/main/jniLibs/x86_64/libbilirec.so`

注意：`libbilirec.so` 现在依赖于 FFmpeg 库，项目通过 `ffmpeg-kit-min` 依赖项提供运行时支持。

如需替换核心版本，请保持文件名为 `libbilirec.so` 并放入对应 ABI 目录。

## 已知行为与注意事项

- 应用仅支持 Android；在非 Android 平台会提示不支持。
- 转档功能（FFmpeg）会显著增加耗电与发热，建议在连接电源时使用，或根据硬件配置调整录制路数限制。
- 首次启动服务时若通知权限未授予，将无法继续启动。
- 若系统仍强制中断后台服务，应用会通过本地通知提示用户重新启动并检查省电设置。

## 目录参考

- `lib/main.dart`：主 UI、前台服务控制、状态流转。
- `lib/bilirec_service.dart`：FFI 封装与原生启动参数（含 FFmpeg 配置）。
- `lib/app/widgets/settings_card.dart`：设置界面，包括转档策略与日志导出逻辑。
- `lib/resource_monitor.dart`：CPU/RAM 读取与计算。
- `lib/l10n/app_localizations.dart`：简繁中文文案。
- `android/app/src/main/AndroidManifest.xml`：权限与服务声明。
- `android/app/build.gradle.kts`：包含 `ffmpeg-kit-min` 依赖配置。
