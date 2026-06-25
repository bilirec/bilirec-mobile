# bilirec-mobile

Flutter Android 客户端，在手机上以前台服务方式运行 Bilirec 录制后端（内嵌 `libbilirec.so`）。

## 快速开始

1. 从 [Releases](https://github.com/bilirec/bilirec-mobile/releases) 下载并安装 APK。
2. 打开 App，完成电池优化与通知权限授权后，点击「启动」。
3. 点击「打开录制管理程序」，在 Web 界面完成 B 站扫码登录即可使用。

## 文档

完整使用说明、设置项说明与开发参考见官方文档站：

- [Android App 使用指南](https://www.bilirec.org/zh-cn/guides/android/)
- [bilirec-mobile 开发参考](https://www.bilirec.org/zh-cn/development/mobile/)
- [Android 库接口](https://www.bilirec.org/zh-cn/guides/android-library/)

## 本地开发

```bash
flutter pub get
flutter run
```

需要 Flutter 与 Android 开发环境，Dart SDK `>=3.4.0 <4.0.0`。
