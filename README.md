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

## 安装到手机（Android）

USB 连上真机（需开开发者选项+USB 调试），构建后安装（`-r` 为覆盖安装，PIN 与桶配置保留）：

```bash
cd /z/app && flutter build apk --debug
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb" install -r app/build/app/outputs/flutter-apk/app-debug.apk
```

调试日志：`adb logcat | grep flutter`。真机已验证：Redmi K60 Pro（Android 14）。

## 压缩 Worker（可选，独立部署）

桶里未压成 AVIF 的漫画页面由常驻 Worker 自动兜底——手机/PC 传完原图即可关掉 App，压缩在服务端完成，与 Flutter 端生命周期无关。纯 Dart 单二进制（复用 `pkgs/mandu_core`，无 Flutter、无 build hooks），宿主只需装 ffmpeg。

构建（dart2native 不跨平台，在目标机器上编译）：

```bash
cd tools/compress_worker
dart pub get
dart compile exe bin/compress_worker.dart -o compress_worker   # 产物约 7MB
```

环境变量（前四个必填）：

```
BUCKET_ENDPOINT   BUCKET_NAME   BUCKET_AK   BUCKET_SK
BUCKET_REGION（可空）  BUCKET_PORT（可空）  BUCKET_SSL（默认 true）
FFMPEG（默认从 PATH 找）  INTERVAL_MINUTES（默认 10）  ONESHOT=1（只跑一轮即退）
```

Linux 服务器用 systemd 常驻（推荐 NAS/常开机器；VPS 注意出入桶流量费）：

```ini
[Unit]
Description=mindu compress worker
After=network-online.target

[Service]
EnvironmentFile=/etc/mindu/worker.env    # 环境变量写这里，chmod 600
ExecStart=/opt/mindu/compress_worker
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Windows 则配任务计划程序（登录时启动）或手动 `ONESHOT=1` 跑。Worker 选目标靠索引行的 `compressed` 标记，首次运行会把全 AVIF 的历史作品补标并跳过。

## 本机工具链状态

| 工具 | 状态 |
|---|---|
| Flutter SDK | `D:/Code/opt/flutter`（stable 3.47.5） |
| Visual Studio Build Tools 2022 | ✅ 已装（含 v143 MFC/ATL；14.44 的 atls.lib 借自 14.42，见 AGENTS.md） |
| Android SDK | ✅ 已装（`%LOCALAPPDATA%\Android\Sdk`，android-36 / build-tools 36）；`flutter build apk --debug` 已验证，Redmi K60 Pro 真机 USB 调试已验证（`adb install -r` + `adb logcat`） |
| JM 下载 | ✅ Dart 原生实现（`app/lib/features/jm/`），不再需要 Python/jmcomic |
| ffmpeg | 本机装在 `C:\Users\akxls\Documents\ffmpeg\...`；路径填在 设置页「ffmpeg 路径」（AVIF 压缩/下载后转码用，仅桌面端生效） |

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
flutter test         # 全绿（115 个用例）
```

`flutter analyze` 从 D: 路径跑没有问题，只有 test/run/build 涉及钩子构建。

## 常用命令

```bash
export PATH="/d/Code/opt/flutter/bin:$PATH"   # 每个新 shell 都需要
cd /z/app                                      # 测试/构建经 Z:
dart run build_runner build --delete-conflicting-outputs   # drift 代码生成
```

## 路线图

见设计文档 §11。当前进度：**M1 桶链路 ✅ · 书架（筛选/翻页/封面/标签） ✅ · JM 下载+AVIF 管线 ✅ · 阅读器（漫画双模式+小说分页/进度自动保存/书签） ✅ · 进度与书签事件同步（多端合并+日志折叠） ✅ · 批量上传与任务队列（漫画/小说） ✅ · 压缩人工审阅 ✅**。

后续：M3 剩余（双页对开/漫画书签 UI）→ M4 剩余（护眼自定义/定时切换/字体导入/书内搜索）→ M5 书源引擎 → M6 追更（增量更新/`_novel_cache` 失效）→ M7 打磨（FTS 上线/图片 LRU/打包）。
