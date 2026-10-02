# 漫读 · 漫画小说资源管理

单人自用的漫画 + 小说阅读与管理应用。无服务端，App 经 SigV4 直连私有 S3 兼容桶（OSS / COS / R2 / MinIO），本地 SQLite 优先检索与阅读。

- 设计文档：[docs/design.md](docs/design.md)
- Flutter 工程：[app/](app/)

## 如何启动应用（Windows 桌面版）

方式一（直接跑已构建的程序）：

```
D:\Code\comics&book\app\build\windows\x64\runner\Debug\mandu_reader.exe
```

双击即可。这是日常使用的入口。

方式二（开发模式，改代码热重载）：

```bash
subst Z: "D:\Code\comics&book"                  # 每个新登录会话执行一次
export PATH="/d/Code/opt/flutter/bin:$PATH"
export FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"
cd /z/app
flutter run -d windows
```

改了代码重新出包（方式一的 exe）：

```bash
cd /z/app && flutter build windows --debug
```

## 本机工具链状态

| 工具 | 状态 |
|---|---|
| Flutter SDK | `D:/Code/opt/flutter`（stable 3.47.5） |
| Visual Studio Build Tools 2022 | ✅ 已装（含 v143 MFC/ATL；14.44 的 atls.lib 借自 14.42，见 AGENTS.md） |
| Android SDK | ✅ 已装（`%LOCALAPPDATA%\Android\Sdk`，android-36 / build-tools 36；`flutter build apk --debug` 已验证） |
| JM 下载 | ✅ Dart 原生实现（`app/lib/features/jm/`），不再需要 Python/jmcomic |
| ffmpeg | `C:\Users\akxls\Documents\ffmpeg\...\ffmpeg.exe`（AVIF 压缩/显示用） |

本机网络对国际出口限速，已配镜像：Gradle 走阿里源（`~/.gradle/init.d/cn-mirrors.gradle` + 工程 gradle 文件）、Flutter 引擎走腾讯镜像（`FLUTTER_STORAGE_BASE_URL`，已 setx 为用户环境变量）、sqlite3 钩子下载走 gh-proxy（pubspec 里配置）。Flutter SDK 升级后需重改 `packages/flutter_tools/gradle/settings.gradle.kts` 加镜像（详见 AGENTS.md）。

## ⚠️ 目录名含 `&`，test/run 必须经 Z: 盘符跑

仓库路径 `D:\Code\comics&book` 中的 `&` 会撑爆 Flutter 原生资产钩子拼出的
cmd 命令行（`dart compile kernel --packages=D:\Code\comics&book\...` 在 `&` 处截断）。
**从真实路径直接跑 `flutter test` / `flutter run` 必然失败**。解决：用 subst 映射后从 Z: 跑。

```bash
subst Z: "D:\Code\comics&book"     # 每个新登录会话执行一次
export PATH="/d/Code/opt/flutter/bin:$PATH"

cd /z/app
dart format --output=none --set-exit-if-changed .
flutter analyze      # 零告警
flutter test         # 全绿（42 个用例）
```

`flutter analyze` 从 D: 路径跑没有问题，只有 test/run/build 涉及钩子构建。

## 常用命令

```bash
export PATH="/d/Code/opt/flutter/bin:$PATH"   # 每个新 shell 都需要
cd /z/app                                      # 测试/构建经 Z:
dart run build_runner build --delete-conflicting-outputs   # drift 代码生成
```

## 路线图

见设计文档 §11。当前进度：**M1 桶链路 ✅ · 书架（筛选/翻页/封面） ✅ · JM 下载+AVIF 管线 ✅ · 阅读器骨架 ✅**（翻页模式/快捷跳转/自动翻页滚动）。

后续：M3 漫画完整（双页/书签/进度）→ M4 小说完整（主题/字体/书内搜索）→ M5 书源引擎 → M6 追更与归档 → M7 打磨。
