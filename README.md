# 漫读 · 漫画小说资源管理

单人自用的漫画 + 小说阅读与管理应用。无服务端，App 经 SigV4 直连私有 S3 兼容桶（OSS / COS / R2 / MinIO），本地 SQLite 优先检索与阅读。

**本仓库仅供个人学习与技术研究使用。** 上游参考仓库的许可边界见文末「上游致谢 / 参考仓库」章节。

- 设计文档：[docs/design.md](docs/design.md)
- Flutter 工程：[app/](app/)

## 如何启动应用（Windows 桌面版）

方式一（直接跑已构建的程序）：

```
D:\Code\mandu_reader\app\build\windows\x64\runner\Debug\mandu_reader.exe
```

双击即可。这是日常使用的入口。

方式二（开发模式，改代码热重载）：

```bash
export PATH="/d/Code/opt/flutter/bin:$PATH"
export FLUTTER_STORAGE_BASE_URL="https://mirrors.cloud.tencent.com/flutter"
cd /d/Code/mandu_reader/app
flutter run -d windows
```

改了代码重新出包（方式一的 exe）：

```bash
cd /d/Code/mandu_reader/app && flutter build windows --debug
```

## 安装到手机（Android）

USB 连上真机（需开开发者选项+USB 调试），构建后安装（`-r` 为覆盖安装，PIN 与桶配置保留）：

```bash
cd /d/Code/mandu_reader/app && flutter build apk --debug
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
FFMPEG（默认从 PATH 找）
SCHEDULE_AT（默认 02:00）：每日定时，进程睡到点干活；当天已过点排到明天
INTERVAL_MINUTES（设置后退回轮询模式，每 N 分钟一轮）
ONESHOT=1（只跑一轮即退，适合 cron/手动测试）
```

调度说明：**默认每天 02:00（服务器本地时）跑一轮**——进程常驻，跑完睡到下一个 02:00，无需 cron/timer；被 kill 后 `Restart=always` 拉起会重算等待。启动时立即先跑一轮（方便验证），此后按点执行。

Linux 服务器用 systemd 常驻（推荐 NAS/常开机器；VPS 注意出入桶流量费）：

```ini
[Unit]
Description=mandu compress worker
After=network-online.target

[Service]
EnvironmentFile=/etc/mandu/worker.env    # 环境变量写这里，chmod 600
ExecStart=/opt/mandu/compress_worker
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Windows 则配任务计划程序「登录时启动」即可（不用设每日触发——进程自己等到 2 点），或手动 `ONESHOT=1` 跑。Worker 选目标靠索引行的 `compressed` 标记，首次运行会把全 AVIF 的历史作品补标并跳过。

## 本机工具链状态

| 工具 | 状态 |
|---|---|
| Flutter SDK | `D:/Code/opt/flutter`（stable 3.47.5） |
| Visual Studio Build Tools 2022 | ✅ 已装（含 v143 MFC/ATL；14.44 的 atls.lib 借自 14.42，见 AGENTS.md） |
| Android SDK | ✅ 已装（`%LOCALAPPDATA%\Android\Sdk`，android-36 / build-tools 36）；`flutter build apk --debug` 已验证，Redmi K60 Pro 真机 USB 调试已验证（`adb install -r` + `adb logcat`） |
| JM 下载 | ✅ Dart 原生实现（`app/lib/features/jm/`），不再需要 Python/jmcomic |
| ffmpeg | 本机装在 `C:\Users\akxls\Documents\ffmpeg\...`；路径填在 设置页「ffmpeg 路径」（AVIF 压缩/下载后转码用，仅桌面端生效） |

本机网络对国际出口限速，已配镜像：Gradle 走阿里源（`~/.gradle/init.d/cn-mirrors.gradle` + 工程 gradle 文件）、Flutter 引擎走腾讯镜像（`FLUTTER_STORAGE_BASE_URL`，已 setx 为用户环境变量）、sqlite3 钩子下载走 gh-proxy（pubspec 里配置）。Flutter SDK 升级后需重改 `packages/flutter_tools/gradle/settings.gradle.kts` 加镜像（详见 AGENTS.md）。

## 验证清单（任何改动后）

```bash
export PATH="/d/Code/opt/flutter/bin:$PATH"

cd /d/Code/mandu_reader/app
dart format --output=none --set-exit-if-changed .
flutter analyze      # 零告警
flutter test         # 全绿
```

（根目录 2026-10-04 起为纯 ASCII `D:\Code\mandu_reader`，由 `comics&book` 改名。历史上路径中的 `&` 会撑爆 Flutter 原生资产钩子拼出的 cmd 命令行（在 `&` 处截断，真实路径必败），靠 `subst Z:` 映射规避——改名后该 workaround 已退役，直接从真实路径跑。）

`flutter test/run/build` 也直接从真实路径跑——新路径纯 ASCII 无 `&`，cmd 截断问题不复存在。

## 常用命令

```bash
export PATH="/d/Code/opt/flutter/bin:$PATH"   # 每个新 shell 都需要
cd /d/Code/mandu_reader/app
dart run build_runner build --delete-conflicting-outputs   # drift 代码生成
```

## 上游致谢 / 参考仓库

| 功能 | 参考仓库 | 关系与许可说明 |
|---|---|---|
| JM 漫画下载 | [hect0x7/JMComic-Crawler-Python](https://github.com/hect0x7/JMComic-Crawler-Python) | 移动端 API 协议、加解密、图片条带还原逻辑的移植蓝本（原 Python 库 `jmcomic`；本工程为其纯 Dart 重写，见 `app/lib/features/jm/`）。**该仓库未标注开源许可证**（原 README 声明仅供学习研究），此处仅作实现出处说明，相关权利义务由使用者自负。 |
| 小说书源引擎 | [pcdd/sonovel](https://github.com/pcdd/sonovel) | 25 个书源规则数据派生自其 `bundle/rules/*.json`（AGPL-3.0）；署名与逐源对照见 [app/assets/rules/NOTICE.md](app/assets/rules/NOTICE.md)，App 设置页含致谢行。引擎本身为独立 Dart 实现。 |

## 路线图

见设计文档 §11。当前进度：**M1 桶链路 ✅ · 书架（筛选/翻页/封面/标签） ✅ · JM 下载+AVIF 管线 ✅ · M3 漫画完整 ✅（双页对开/漫画书签 UI）· M4 小说完整 ✅（护眼自定义+定时切换+图片背景/字体导入+_fonts/ 桶同步/书内搜索）· 进度与书签事件同步（多端合并+日志折叠） ✅ · 批量上传与任务队列（漫画/小说） ✅ · 压缩人工审阅 ✅**。

当前进度追加（2026-10-04 打磨）：**M5 书源引擎 ✅（巡检放行：8 源启用 / 17 禁用带因）**——so-novel 25 源规则数据（AGPL 致谢见 assets/rules/NOTICE.md）+ Dart 重写引擎（`@js:`→`@op:` 算子、迷你 CSS/XPath、staging 幂等补章、meta.json 追更回溯）+ 书架「找书」页签 + `/sources` 源管理 + `dart run tool/source_doctor.dart` 巡检。

M6 已收尾（源追更经决策不做、清本地入口确认已有、`_novel_cache` 失效落地）。**M7 已收尾（2026-10-04）：FTS 查询接通 + 语法糖、启动缓存修剪（图片 LRU/`_novel_cache` 上限/审阅残留清扫）、启动清扫去重、封面解码降内存、Android/Windows release 出包验证**。release 包用 debug 签名（个人自用合规；要分发需自备 keystore 替换 `android/app/build.gradle.kts` 的 signingConfig）。
